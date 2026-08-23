import { adminClient, FunctionError, invoke, body, requireUser, requiredString, hoursFromNow } from "../_shared/common.ts";
import { advanceVerification, evaluate, initialState, normaliseBatch, summarise, PUSHUP, computeUnlockHours, type SessionVerifyState } from "../_shared/pushup.ts";

Deno.serve((req) => invoke("submit-pushup-frame-batch", req, async (request) => {
  const { user } = await requireUser(request);
  const input = await body(request);
  const sessionId = requiredString(input.sessionId, "sessionId");
  let samples;
  try { samples = normaliseBatch(input.poseLandmarkBatch); } catch (error) { throw new FunctionError(400, error instanceof Error ? error.message : "Invalid frame batch."); }
  const meta = input.frameMeta && typeof input.frameMeta === "object" && !Array.isArray(input.frameMeta) ? input.frameMeta as Record<string, unknown> : {};
  const { data: session, error: readError } = await adminClient.from("pushup_sessions").select("id, status, required_reps, rep_count, verify_state, version").eq("id", sessionId).eq("user_id", user.id).maybeSingle();
  if (readError || !session) throw new FunctionError(404, "Session not found.");
  if (session.status === "verified") return { currentValidatedReps: session.rep_count, sessionComplete: true };
  const prior = (session.verify_state && typeof session.verify_state === "object" ? session.verify_state : initialState()) as SessionVerifyState;
  const state = advanceVerification(prior, samples);
  const verdict = evaluate(state, meta);
  const complete = state.reps >= Number(session.required_reps) && verdict.ok;
  const unlockHours = complete ? computeUnlockHours(state.reps, Number(session.required_reps)) : 0;
  const unlockUntil = complete ? hoursFromNow(unlockHours) : null;
  const { data: result, error } = await adminClient.rpc("apply_pushup_batch_with_streak", { p_session_id: session.id, p_user_id: user.id, p_version: session.version, p_state: state, p_verdict: verdict, p_complete: complete, p_rep_count: state.reps, p_summary: summarise(state), p_unlock_until: unlockUntil });
  if (error) throw new FunctionError(500, "Could not save verification progress.");
  const row = Array.isArray(result) ? result[0] : result;
  if (row?.conflict) throw new FunctionError(409, "This batch raced another upload. Retry the latest batch.");
  return { currentValidatedReps: Number(row?.current_validated_reps ?? state.reps), sessionComplete: Boolean(row?.session_complete ?? complete), ...(verdict.ok ? {} : { rejectionReason: verdict.reason }) };
}));
