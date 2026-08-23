import { adminClient, FunctionError, invoke, body, requireAdmin, requiredString, optionalString, hoursFromNow } from "../_shared/common.ts";
import { recordAndSendNotification } from "../_shared/notifications.ts";

Deno.serve((req) => invoke("review-fine", req, async (request) => {
  const { user: actor } = await requireAdmin(request);
  const input = await body(request);
  const targetUid = requiredString(input.targetUid, "targetUid");
  const fineId = requiredString(input.fineId, "fineId");
  const approve = input.approve === true;
  const note = optionalString(input.note, 500);
  if (!approve && !note) throw new FunctionError(400, "A reason is required when rejecting.");
  const unlockUntil = approve ? hoursFromNow(24) : null;
  const { data: result, error: reviewError } = await adminClient.rpc("review_fine_atomic", { p_fine_id: fineId, p_target_uid: targetUid, p_actor_uid: actor.id, p_approve: approve, p_note: note, p_unlock_until: unlockUntil });
  if (reviewError) {
    if (reviewError.message.includes("fine_not_found")) throw new FunctionError(404, "That fine no longer exists.");
    if (reviewError.message.includes("fine_not_submitted")) throw new FunctionError(412, "Only submitted fines can be reviewed.");
    throw new FunctionError(500, "Could not review this fine.");
  }
  const reviewed = Array.isArray(result) ? result[0] : result;
  if (!reviewed?.reviewed) throw new FunctionError(500, "Could not review this fine.");
  await recordAndSendNotification(targetUid, "fine_reviewed", { approved: approve, note, channel: "fines" });
  return { reviewed: true, approved: approve, unlockUntil };
}));
