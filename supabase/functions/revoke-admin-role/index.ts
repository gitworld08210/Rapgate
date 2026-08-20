import { adminClient, FunctionError, invoke, body, requireAdmin, requiredString } from "../_shared/common.ts";

Deno.serve((req) => invoke("revoke-admin-role", req, async (request) => {
  const { user: actor } = await requireAdmin(request);
  const targetUid = requiredString((await body(request)).targetUid, "targetUid");
  if (targetUid === actor.id) throw new FunctionError(412, "You cannot revoke your own admin access.");
  const { data: target } = await adminClient.auth.admin.getUserById(targetUid);
  if (!target.user) throw new FunctionError(404, "Target user not found.");
  const { error } = await adminClient.rpc("revoke_admin_role_atomic", { p_actor_uid: actor.id, p_target_uid: targetUid });
  if (error) throw new FunctionError(500, "Could not revoke admin access.");
  try { await adminClient.auth.admin.updateUserById(targetUid, { app_metadata: { ...(target.user.app_metadata ?? {}), admin: false } }); } catch (error) { console.warn("Could not clear app_metadata admin marker", error); }
  try { await adminClient.auth.admin.signOut(targetUid, "global"); } catch (error) { console.warn("Could not revoke existing sessions", error); }
  return { revoked: true };
}));
