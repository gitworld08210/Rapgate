import { adminClient, FunctionError, invoke, requireUser } from "../_shared/common.ts";

Deno.serve((req) => invoke("claim-admin-role", req, async (request) => {
  const { user } = await requireUser(request);
  const email = user.email?.toLowerCase();
  const allowlist = (Deno.env.get("ADMIN_EMAILS") ?? "").split(",").map((item) => item.trim().toLowerCase()).filter(Boolean);
  if (!email || !allowlist.includes(email)) return { granted: false, reason: "not_allowlisted" };
  if (!user.email_confirmed_at) throw new FunctionError(412, "Verify your email address before enabling admin access.");
  const { data: result, error } = await adminClient.rpc("grant_admin_role_atomic", { p_user_id: user.id, p_email: email });
  if (error) throw new FunctionError(500, "Could not grant admin access.");
  const alreadyGranted = Boolean(Array.isArray(result) ? result[0]?.already_granted : result?.already_granted);
  try { await adminClient.auth.admin.updateUserById(user.id, { app_metadata: { ...(user.app_metadata ?? {}), admin: true } }); } catch (error) { console.warn("Could not refresh app_metadata admin marker", error); }
  return { granted: true, alreadyGranted };
}));
