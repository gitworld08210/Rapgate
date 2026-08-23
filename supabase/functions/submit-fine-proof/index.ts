import { adminClient, FunctionError, invoke, body, requireUser, requiredString, optionalString, isOwnedStoragePath } from "../_shared/common.ts";

Deno.serve((req) => invoke("submit-fine-proof", req, async (request) => {
  const { user } = await requireUser(request);
  const input = await body(request);
  const fineId = requiredString(input.fineId, "fineId");
  const rawUtr = optionalString(input.upiUtr, 24);
  const upiUtr = rawUtr ? rawUtr.toUpperCase() : null;
  const candidatePath = optionalString(input.screenshotPath ?? input.screenshotUrl, 512);
  if (!upiUtr && !candidatePath) throw new FunctionError(400, "Provide a UTR number or a payment screenshot.");
  if (upiUtr && !/^[A-Z0-9]{8,24}$/.test(upiUtr)) throw new FunctionError(400, "That UTR doesn't look valid. Check your payment app.");
  if (candidatePath && !isOwnedStoragePath(candidatePath, user.id)) throw new FunctionError(400, "Use a fine-proofs storage path owned by your account.");
  if (candidatePath && !candidatePath.startsWith(`${user.id}/fine_proofs/${fineId}.`)) throw new FunctionError(400, "Fine proof must use the fine-specific storage path.");
  const { data: fine, error: readError } = await adminClient.from("fines").select("id, status").eq("id", fineId).eq("user_id", user.id).maybeSingle();
  if (readError || !fine) throw new FunctionError(404, "That fine no longer exists.");
  if (fine.status === "approved") throw new FunctionError(412, "This fine is already paid.");
  if (fine.status === "submitted") throw new FunctionError(412, "Your proof is already awaiting review.");
  if (candidatePath) {
    const directory = `${user.id}/fine_proofs`;
    const { data: objects, error: storageError } = await adminClient.storage.from("fine-proofs").list(directory, { limit: 100, search: fineId });
    const fileName = candidatePath.slice(directory.length + 1);
    if (storageError || !(objects ?? []).some((object) => object.name === fileName)) throw new FunctionError(400, "Upload the fine proof to the private fine-proofs bucket first.");
  }
  const { data: updated, error } = await adminClient.from("fines").update({ status: "submitted", upi_utr: upiUtr, screenshot_path: candidatePath, submitted_at: new Date().toISOString(), review_note: null, reviewed_at: null, reviewed_by: null }).eq("id", fineId).eq("user_id", user.id).in("status", ["pending", "rejected"]).select("id").single();
  if (error || !updated) {
    if (error?.code === "23505") throw new FunctionError(409, "That UTR has already been submitted for another fine.");
    if (error?.code === "PGRST116") throw new FunctionError(409, "Your proof was submitted by another request. Refresh the fine.");
    throw new FunctionError(500, "Could not submit payment proof.");
  }
  return { submitted: true };
}));
