import { adminClient, invoke, requireUser, body, requiredString, FunctionError } from "../_shared/common.ts";

Deno.serve((req) => invoke("join-group", req, async (request) => {
  const { user } = await requireUser(request);
  const payload = await body(request);
  const inviteCode = requiredString(payload.invite_code, "Invite code").toUpperCase();

  // Find group by invite code
  const { data: group, error: groupError } = await adminClient
    .from("groups")
    .select("id, name, invite_code, max_members, created_by, created_at")
    .eq("invite_code", inviteCode)
    .maybeSingle();

  if (groupError || !group) {
    throw new FunctionError(404, "No group found with that invite code.");
  }

  // Check if user is already a member
  const { data: existing } = await adminClient
    .from("group_members")
    .select("id")
    .eq("group_id", group.id)
    .eq("user_id", user.id)
    .maybeSingle();

  if (existing) {
    throw new FunctionError(400, "You are already a member of this group.");
  }

  // Check that user has not joined too many groups (max 5 per user)
  const { count: userGroupCount } = await adminClient
    .from("group_members")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id);

  if ((userGroupCount ?? 0) >= 5) {
    throw new FunctionError(400, "You can join a maximum of 5 groups.");
  }

  // Check member count (soft check before insert; the DB trigger enforces atomically)
  const { count } = await adminClient
    .from("group_members")
    .select("id", { count: "exact", head: true })
    .eq("group_id", group.id);

  if ((count ?? 0) >= group.max_members) {
    throw new FunctionError(400, "This group is full (max " + group.max_members + " members).");
  }

  // Insert new member (DB trigger enforce_group_max_members prevents TOCTOU race)
  const { error: insertError } = await adminClient
    .from("group_members")
    .insert({
      group_id: group.id,
      user_id: user.id,
    });

  if (insertError) {
    // Handle the trigger-raised exception for max members exceeded
    if (insertError.message?.includes("maximum member limit")) {
      throw new FunctionError(400, "This group is full (max " + group.max_members + " members).");
    }
    throw new FunctionError(500, "Failed to join group.");
  }

  return {
    id: group.id,
    name: group.name,
    invite_code: group.invite_code,
    max_members: group.max_members,
    created_by: group.created_by,
    created_at: group.created_at,
    member_count: (count ?? 0) + 1,
  };
}));
