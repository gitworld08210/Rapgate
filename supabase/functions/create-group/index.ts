import { adminClient, invoke, requireUser, body, requiredString, FunctionError } from "../_shared/common.ts";

Deno.serve((req) => invoke("create-group", req, async (request) => {
  const { user } = await requireUser(request);
  const payload = await body(request);
  const name = requiredString(payload.name, "Group name");

  if (name.length > 50) {
    throw new FunctionError(400, "Group name must be 50 characters or less.");
  }

  // Generate a unique 6-char alphanumeric invite code
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // No I/O/0/1 to avoid confusion
  let inviteCode = "";
  let attempts = 0;
  while (attempts < 100) {
    inviteCode = "";
    for (let i = 0; i < 6; i++) {
      inviteCode += chars[Math.floor(Math.random() * chars.length)];
    }
    // Check uniqueness
    const { data: existing } = await adminClient
      .from("groups")
      .select("id")
      .eq("invite_code", inviteCode)
      .maybeSingle();
    if (!existing) break;
    attempts++;
  }

  // Create the group
  const { data: group, error: groupError } = await adminClient
    .from("groups")
    .insert({
      name,
      created_by: user.id,
      invite_code: inviteCode,
      max_members: 10,
    })
    .select()
    .single();

  if (groupError || !group) {
    throw new FunctionError(500, "Failed to create group.");
  }

  // Add creator as first member
  const { error: memberError } = await adminClient
    .from("group_members")
    .insert({
      group_id: group.id,
      user_id: user.id,
    });

  if (memberError) {
    // Rollback: delete the group
    await adminClient.from("groups").delete().eq("id", group.id);
    throw new FunctionError(500, "Failed to join group as creator.");
  }

  return {
    id: group.id,
    name: group.name,
    invite_code: group.invite_code,
    max_members: group.max_members,
    created_by: group.created_by,
    created_at: group.created_at,
    member_count: 1,
  };
}));
