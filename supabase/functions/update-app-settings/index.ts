import { adminClient, body, FunctionError, invoke, requireAdmin } from "../_shared/common.ts";

Deno.serve((req) => invoke("update-app-settings", req, async (request) => {
  const { user: actor } = await requireAdmin(request);
  const input = await body(request);

  // Build the update payload from optional fields
  const updates: Record<string, unknown> = {};

  if (input.upiId !== undefined) {
    if (typeof input.upiId !== "string" || !input.upiId.includes("@")) {
      throw new FunctionError(400, "upiId must be a string containing '@'.");
    }
    updates.upi_id = input.upiId.trim();
  }

  if (input.upiPayeeName !== undefined) {
    if (typeof input.upiPayeeName !== "string" || input.upiPayeeName.trim().length === 0) {
      throw new FunctionError(400, "upiPayeeName must be a non-empty string.");
    }
    updates.upi_payee_name = input.upiPayeeName.trim();
  }

  if (input.fineAmountPaise !== undefined) {
    const amount = Number(input.fineAmountPaise);
    if (!Number.isFinite(amount) || amount <= 0 || !Number.isInteger(amount)) {
      throw new FunctionError(400, "fineAmountPaise must be a positive integer.");
    }
    updates.fine_amount_paise = amount;
  }

  if (Object.keys(updates).length === 0) {
    throw new FunctionError(400, "At least one field (upiId, upiPayeeName, fineAmountPaise) must be provided.");
  }

  // Always record who made the change
  updates.updated_by = actor.id;

  const { data, error } = await adminClient
    .from("app_settings")
    .update(updates)
    .eq("id", 1)
    .select()
    .single();

  if (error) throw new FunctionError(500, "Could not update app settings.");

  return data;
}));
