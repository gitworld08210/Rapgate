import { adminClient, invoke, requireUser, body, requiredString, FunctionError } from "../_shared/common.ts";

Deno.serve((req) => invoke("get-group-leaderboard", req, async (request) => {
  const { user } = await requireUser(request);
  const payload = await body(request);
  const groupId = requiredString(payload.group_id, "Group ID");

  // Verify user is a member of this group
  const { data: membership } = await adminClient
    .from("group_members")
    .select("id")
    .eq("group_id", groupId)
    .eq("user_id", user.id)
    .maybeSingle();

  if (!membership) {
    throw new FunctionError(403, "You are not a member of this group.");
  }

  // Get group info
  const { data: group, error: groupError } = await adminClient
    .from("groups")
    .select("id, name, invite_code, max_members, created_by, created_at")
    .eq("id", groupId)
    .single();

  if (groupError || !group) {
    throw new FunctionError(404, "Group not found.");
  }

  // Get all members with user names
  const { data: members } = await adminClient
    .from("group_members")
    .select("user_id, users(name)")
    .eq("group_id", groupId);

  // Calculate current week date range (Monday to Sunday)
  const now = new Date();
  const dayOfWeek = now.getDay(); // 0=Sun, 1=Mon, ...
  const mondayOffset = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
  const weekStart = new Date(now);
  weekStart.setDate(now.getDate() + mondayOffset);
  weekStart.setHours(0, 0, 0, 0);

  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekStart.getDate() + 6);
  weekEnd.setHours(23, 59, 59, 999);

  const startDate = weekStart.toISOString().split("T")[0];
  const endDate = weekEnd.toISOString().split("T")[0];
  const today = now.toISOString().split("T")[0];

  // Get scores for the current week
  const { data: scores } = await adminClient
    .from("group_daily_scores")
    .select("user_id, score_date, food_logged, pushups_done, protein_hit, total_points")
    .eq("group_id", groupId)
    .gte("score_date", startDate)
    .lte("score_date", endDate);

  // Build leaderboard per member
  const memberList = (members ?? []).map((m: Record<string, unknown>) => {
    const userId = m.user_id as string;
    const userObj = m.users as Record<string, unknown> | null;
    const userName = (userObj?.name as string) ?? "Unknown";

    // Today's score
    const todayScore = (scores ?? []).find(
      (s: Record<string, unknown>) => s.user_id === userId && s.score_date === today
    );

    // Weekly total
    const weeklyTotal = (scores ?? [])
      .filter((s: Record<string, unknown>) => s.user_id === userId)
      .reduce((sum: number, s: Record<string, unknown>) => sum + ((s.total_points as number) ?? 0), 0);

    return {
      user_id: userId,
      user_name: userName,
      food_logged: todayScore ? (todayScore as Record<string, unknown>).food_logged : false,
      pushups_done: todayScore ? (todayScore as Record<string, unknown>).pushups_done : false,
      protein_hit: todayScore ? (todayScore as Record<string, unknown>).protein_hit : false,
      total_points: todayScore ? (todayScore as Record<string, unknown>).total_points : 0,
      weekly_total: weeklyTotal,
    };
  });

  // Sort by weekly total descending
  memberList.sort((a: Record<string, unknown>, b: Record<string, unknown>) =>
    (b.weekly_total as number) - (a.weekly_total as number)
  );

  // Get member count
  const memberCount = (members ?? []).length;

  return {
    group: {
      ...group,
      member_count: memberCount,
    },
    members: memberList,
    week_start: startDate,
    week_end: endDate,
    today,
  };
}));
