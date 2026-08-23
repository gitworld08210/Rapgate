import { adminClient, invoke, requireCron, listUserIds } from "../_shared/common.ts";
import { recordAndSendNotification } from "../_shared/notifications.ts";

interface BadgeDef {
  key: string;
  name: string;
  description: string;
}

const BADGES: BadgeDef[] = [
  { key: "first_pushup", name: "First Push-up", description: "Completed your first verified push-up session" },
  { key: "streak_7", name: "7-Day Warrior", description: "Maintained a 7-day push-up streak" },
  { key: "streak_30", name: "30-Day Legend", description: "Maintained a 30-day push-up streak" },
  { key: "water_champion", name: "Water Champion", description: "Hit your water goal 7 consecutive days" },
  { key: "early_bird", name: "Early Bird", description: "Completed push-ups before 7 AM" },
  { key: "century_club", name: "Century Club", description: "100 total verified push-up sessions" },
  { key: "clean_eater", name: "Clean Eater", description: "Logged 3 meals for 7 consecutive days" },
];

async function getEarnedBadges(uid: string): Promise<Set<string>> {
  const { data } = await adminClient
    .from("achievements")
    .select("badge_key")
    .eq("user_id", uid);
  return new Set((data ?? []).map((row) => String(row.badge_key)));
}

async function checkFirstPushup(uid: string): Promise<boolean> {
  const { data } = await adminClient
    .from("pushup_sessions")
    .select("id")
    .eq("user_id", uid)
    .eq("status", "verified")
    .limit(1);
  return (data ?? []).length > 0;
}

async function checkStreak7(uid: string): Promise<boolean> {
  const { data } = await adminClient
    .from("streaks")
    .select("current_pushup_streak, longest_pushup_streak")
    .eq("user_id", uid)
    .maybeSingle();
  if (!data) return false;
  return (data.current_pushup_streak ?? 0) >= 7 || (data.longest_pushup_streak ?? 0) >= 7;
}

async function checkStreak30(uid: string): Promise<boolean> {
  const { data } = await adminClient
    .from("streaks")
    .select("current_pushup_streak, longest_pushup_streak")
    .eq("user_id", uid)
    .maybeSingle();
  if (!data) return false;
  return (data.current_pushup_streak ?? 0) >= 30 || (data.longest_pushup_streak ?? 0) >= 30;
}

async function checkWaterChampion(uid: string): Promise<boolean> {
  // Check if user hit water goal for 7 consecutive days
  // We look at the last 7 days of water logs vs their target
  const { data: userRow } = await adminClient
    .from("users")
    .select("daily_water_target_ml")
    .eq("id", uid)
    .maybeSingle();

  const target = userRow?.daily_water_target_ml ?? 3000;
  const now = new Date();
  let consecutiveDays = 0;

  for (let i = 0; i < 14; i++) {
    const dayStart = new Date(now);
    dayStart.setDate(now.getDate() - i);
    dayStart.setHours(0, 0, 0, 0);
    const dayEnd = new Date(dayStart);
    dayEnd.setDate(dayStart.getDate() + 1);

    const { data: logs } = await adminClient
      .from("water_logs")
      .select("amount_ml")
      .eq("user_id", uid)
      .gte("logged_at", dayStart.toISOString())
      .lt("logged_at", dayEnd.toISOString());

    const totalMl = (logs ?? []).reduce((sum: number, row: { amount_ml?: number }) => sum + (row.amount_ml ?? 0), 0);

    if (totalMl >= target) {
      consecutiveDays++;
      if (consecutiveDays >= 7) return true;
    } else {
      consecutiveDays = 0;
    }
  }

  return false;
}

async function checkEarlyBird(uid: string): Promise<boolean> {
  // Check if user ever completed push-ups before 7 AM
  const { data } = await adminClient
    .from("pushup_sessions")
    .select("completed_at")
    .eq("user_id", uid)
    .eq("status", "verified")
    .order("completed_at", { ascending: false })
    .limit(200);

  for (const row of data ?? []) {
    const completedAt = new Date(row.completed_at);
    if (completedAt.getHours() < 7) return true;
  }
  return false;
}

async function checkCenturyClub(uid: string): Promise<boolean> {
  const { count } = await adminClient
    .from("pushup_sessions")
    .select("id", { count: "exact", head: true })
    .eq("user_id", uid)
    .eq("status", "verified");
  return (count ?? 0) >= 100;
}

async function checkCleanEater(uid: string): Promise<boolean> {
  // Check if user logged 3+ meals for 7 consecutive days
  const now = new Date();
  let consecutiveDays = 0;

  for (let i = 0; i < 14; i++) {
    const dayStart = new Date(now);
    dayStart.setDate(now.getDate() - i);
    dayStart.setHours(0, 0, 0, 0);
    const dayEnd = new Date(dayStart);
    dayEnd.setDate(dayStart.getDate() + 1);

    const { data: logs } = await adminClient
      .from("food_logs")
      .select("id")
      .eq("user_id", uid)
      .gte("logged_at", dayStart.toISOString())
      .lt("logged_at", dayEnd.toISOString());

    if ((logs ?? []).length >= 3) {
      consecutiveDays++;
      if (consecutiveDays >= 7) return true;
    } else {
      consecutiveDays = 0;
    }
  }

  return false;
}

type CheckFn = (uid: string) => Promise<boolean>;

const BADGE_CHECKS: Record<string, CheckFn> = {
  first_pushup: checkFirstPushup,
  streak_7: checkStreak7,
  streak_30: checkStreak30,
  water_champion: checkWaterChampion,
  early_bird: checkEarlyBird,
  century_club: checkCenturyClub,
  clean_eater: checkCleanEater,
};

async function processUser(uid: string): Promise<string[]> {
  const earned = await getEarnedBadges(uid);
  const newBadges: string[] = [];

  for (const badge of BADGES) {
    if (earned.has(badge.key)) continue;

    const checkFn = BADGE_CHECKS[badge.key];
    if (!checkFn) continue;

    try {
      const qualifies = await checkFn(uid);
      if (!qualifies) continue;

      // Insert achievement
      const { error } = await adminClient.from("achievements").insert({
        user_id: uid,
        badge_key: badge.key,
        metadata: { name: badge.name, description: badge.description },
      });

      if (error) {
        // Unique constraint violation means already earned (race condition)
        if (error.code === "23505") continue;
        console.error(`Failed to insert badge ${badge.key} for ${uid}:`, error);
        continue;
      }

      newBadges.push(badge.key);

      // Send notification for new badge
      await recordAndSendNotification(uid, "achievement_earned", {
        title: "Badge Earned! 🏆",
        body: `Congratulations! You earned the "${badge.name}" badge.`,
        badge_key: badge.key,
        badge_name: badge.name,
        channel: "achievements",
      });
    } catch (err) {
      console.error(`check-achievements: error checking ${badge.key} for ${uid}:`, err);
    }
  }

  return newBadges;
}

Deno.serve((req) =>
  invoke("check-achievements", req, async (request) => {
    requireCron(request);

    const userIds = await listUserIds();
    let totalNew = 0;
    let processed = 0;

    for (const uid of userIds) {
      try {
        const newBadges = await processUser(uid);
        totalNew += newBadges.length;
        processed++;
      } catch (err) {
        console.error(`check-achievements failed for ${uid}:`, err);
      }
    }

    return { processed, totalNew, total: userIds.length };
  })
);
