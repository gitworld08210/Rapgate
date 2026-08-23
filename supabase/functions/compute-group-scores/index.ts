import { adminClient, invoke, requireCron } from "../_shared/common.ts";

Deno.serve((req) => invoke("compute-group-scores", req, async (request) => {
  requireCron(request);

  const today = new Date().toISOString().split("T")[0];
  const todayStart = `${today}T00:00:00.000Z`;
  const todayEnd = `${today}T23:59:59.999Z`;

  // Get all groups
  const { data: groups, error: groupsError } = await adminClient
    .from("groups")
    .select("id");

  if (groupsError || !groups) {
    return { error: "Failed to fetch groups.", processed: 0 };
  }

  let processed = 0;
  let errors = 0;

  for (const group of groups) {
    try {
      // Get all members of this group
      const { data: members } = await adminClient
        .from("group_members")
        .select("user_id")
        .eq("group_id", group.id);

      if (!members || members.length === 0) continue;

      for (const member of members) {
        try {
          const userId = member.user_id;

          // Check if user logged food today
          const { data: foodLogs } = await adminClient
            .from("food_logs")
            .select("id")
            .eq("user_id", userId)
            .gte("logged_at", todayStart)
            .lte("logged_at", todayEnd)
            .limit(1);
          const foodLogged = (foodLogs && foodLogs.length > 0);

          // Check if user did pushups today (verified)
          const { data: pushups } = await adminClient
            .from("pushup_sessions")
            .select("id")
            .eq("user_id", userId)
            .eq("status", "verified")
            .gte("completed_at", todayStart)
            .lte("completed_at", todayEnd)
            .limit(1);
          const pushupsDone = (pushups && pushups.length > 0);

          // Check if protein target hit: sum food_log protein >= user.daily_protein_target
          const { data: userRow } = await adminClient
            .from("users")
            .select("daily_protein_target")
            .eq("id", userId)
            .single();

          const proteinTarget = (userRow?.daily_protein_target as number) ?? 100;

          // Get all food logs for today to sum protein
          const { data: allFoodLogs } = await adminClient
            .from("food_logs")
            .select("detected_items")
            .eq("user_id", userId)
            .gte("logged_at", todayStart)
            .lte("logged_at", todayEnd);

          let totalProtein = 0;
          if (allFoodLogs) {
            for (const log of allFoodLogs) {
              const items = (log.detected_items as Array<Record<string, unknown>>) ?? [];
              for (const item of items) {
                totalProtein += ((item.protein as number) ?? 0);
              }
            }
          }
          const proteinHit = totalProtein >= proteinTarget;

          // Calculate total points
          let totalPoints = 0;
          if (foodLogged) totalPoints += 1;
          if (pushupsDone) totalPoints += 1;
          if (proteinHit) totalPoints += 1;

          // Upsert the daily score
          await adminClient
            .from("group_daily_scores")
            .upsert(
              {
                group_id: group.id,
                user_id: userId,
                score_date: today,
                food_logged: foodLogged,
                pushups_done: pushupsDone,
                protein_hit: proteinHit,
                total_points: totalPoints,
              },
              { onConflict: "group_id,user_id,score_date" }
            );

          processed++;
        } catch (e) {
          console.error(`[compute-group-scores] Error for user ${member.user_id} in group ${group.id}:`, e);
          errors++;
        }
      }
    } catch (e) {
      console.error(`[compute-group-scores] Error processing group ${group.id}:`, e);
      errors++;
    }
  }

  return { processed, errors, groups_count: groups.length, date: today };
}));
