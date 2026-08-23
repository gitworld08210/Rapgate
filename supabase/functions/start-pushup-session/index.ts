import { adminClient, FunctionError, invoke, requireUser } from "../_shared/common.ts";
import { computeTarget } from "../_shared/pushup.ts";

Deno.serve((req) => invoke("start-pushup-session", req, async (request) => {
  const { user } = await requireUser(request);
  const { data: streak } = await adminClient.from("streaks").select("current_pushup_streak").eq("user_id", user.id).maybeSingle();
  const requiredReps = computeTarget(Number(streak?.current_pushup_streak ?? 0));
  const { data, error } = await adminClient.from("pushup_sessions").insert({ user_id: user.id, required_reps: requiredReps }).select("id, required_reps").single();
  if (error || !data) throw new FunctionError(500, "Could not start a push-up session.");
  return { sessionId: data.id, requiredReps: data.required_reps };
}));
