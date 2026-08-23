import { adminClient, invoke, requireCron, listUserIds } from "../_shared/common.ts";
import { sendSmartNotification } from "../_shared/notifications.ts";

/**
 * Smart Notifications CRON function.
 * Runs every hour and checks user behavior to send contextual notifications.
 *
 * IST = UTC + 5:30
 * Schedule: every hour (externally configured via cron scheduler hitting this endpoint).
 */
Deno.serve((req) => invoke("smart-notifications", req, async (request) => {
  requireCron(request);

  // Current IST hour
  const now = new Date();
  const istOffsetMs = 5.5 * 60 * 60 * 1000;
  const istNow = new Date(now.getTime() + istOffsetMs);
  const istHour = istNow.getUTCHours();
  const istDay = istNow.getUTCDay(); // 0 = Sunday

  const userIds = await listUserIds();
  const todayStart = getTodayStartIST();

  let sent = 0;

  for (const uid of userIds) {
    try {
      // Fetch user preferences
      const { data: prefs } = await adminClient
        .from("notification_preferences")
        .select("*")
        .eq("user_id", uid)
        .maybeSingle();

      // Default to all enabled if no preferences row exists
      const preferences = prefs ?? {
        lunch_reminder: true,
        pushup_reminder: true,
        streak_alerts: true,
        protein_tips: true,
        weekly_summary: true,
        preferred_workout_hour: null,
      };

      // (1) Lunch reminder at 2pm IST - "Lunch log nahi kiya"
      if (istHour === 14 && preferences.lunch_reminder) {
        const hasLunchOrLater = await hasRecentFoodLog(uid, todayStart, ["lunch", "dinner", "snack"]);
        if (!hasLunchOrLater) {
          await sendSmartNotification(
            uid,
            "Lunch log nahi kiya 🍽️",
            "Abhi lunch log karo — track karna easy hai!",
            "smart_reminders",
          );
          sent++;
        }
      }

      // (2) Pushup reminder at user's usual workout time
      if (preferences.pushup_reminder) {
        const workoutHour = preferences.preferred_workout_hour ?? await getMedianWorkoutHour(uid);
        if (workoutHour !== null && istHour === workoutHour) {
          const hasPushupToday = await hasVerifiedPushupToday(uid, todayStart);
          if (!hasPushupToday) {
            await sendSmartNotification(
              uid,
              "Pushup time! \u{1F3CB}\uFE0F Sirf 10 min",
              "Teri body tera temple — chal shuru kar!",
              "smart_reminders",
            );
            sent++;
          }
        }
      }

      // (3) Streak celebration at 8pm IST
      if (istHour === 20 && preferences.streak_alerts) {
        const { data: streak } = await adminClient
          .from("streaks")
          .select("current_pushup_streak")
          .eq("user_id", uid)
          .maybeSingle();

        if (streak && streak.current_pushup_streak >= 3) {
          await sendSmartNotification(
            uid,
            `${streak.current_pushup_streak}-day streak! Don't break it tomorrow \u{1F525}`,
            "Consistency is king — kal bhi dikhana hai!",
            "smart_reminders",
          );
          sent++;
        }
      }

      // (4) Protein deficit at 7pm IST
      if (istHour === 19 && preferences.protein_tips) {
        const deficit = await getProteinDeficit(uid, todayStart);
        if (deficit !== null && deficit >= 30) {
          await sendSmartNotification(
            uid,
            `Aaj protein ${Math.round(deficit)}g short hai`,
            "Dinner mein paneer, eggs ya dal try karo \u{1F4AA}",
            "smart_reminders",
          );
          sent++;
        }
      }

      // (5) Weekly summary on Sunday at 10am IST
      if (istDay === 0 && istHour === 10 && preferences.weekly_summary) {
        const summary = await getWeeklySummary(uid);
        await sendSmartNotification(
          uid,
          "\u{1F4CA} Weekly Summary",
          `This week: ${summary.foodLogs} food logs, ${summary.pushups} pushups, avg ${summary.avgProtein}g protein/day`,
          "weekly_summary",
        );
        sent++;
      }
    } catch (error) {
      console.error(`[smart-notifications] Error for user ${uid}:`, error);
    }
  }

  return { checked: userIds.length, sent };
}));

// ---- Helper functions ----

/** Get today's start timestamp in IST (as UTC ISO string) */
function getTodayStartIST(): string {
  const now = new Date();
  const istOffsetMs = 5.5 * 60 * 60 * 1000;
  const istNow = new Date(now.getTime() + istOffsetMs);
  // Get IST date components
  const year = istNow.getUTCFullYear();
  const month = istNow.getUTCMonth();
  const day = istNow.getUTCDate();
  // Midnight IST in UTC
  const midnightIST = new Date(Date.UTC(year, month, day) - istOffsetMs);
  return midnightIST.toISOString();
}

/** Check if user has food logs of certain meal types since a given time */
async function hasRecentFoodLog(
  userId: string,
  since: string,
  mealTypes: string[],
): Promise<boolean> {
  const { data } = await adminClient
    .from("food_logs")
    .select("id")
    .eq("user_id", userId)
    .in("meal_type", mealTypes)
    .gte("logged_at", since)
    .limit(1);
  return (data ?? []).length > 0;
}

/** Check if user has a verified pushup session today */
async function hasVerifiedPushupToday(userId: string, todayStart: string): Promise<boolean> {
  const { data } = await adminClient
    .from("pushup_sessions")
    .select("id")
    .eq("user_id", userId)
    .eq("status", "verified")
    .gte("completed_at", todayStart)
    .limit(1);
  return (data ?? []).length > 0;
}

/** Get the median workout hour for a user from their pushup history */
async function getMedianWorkoutHour(userId: string): Promise<number | null> {
  const { data: sessions } = await adminClient
    .from("pushup_sessions")
    .select("started_at")
    .eq("user_id", userId)
    .eq("status", "verified")
    .order("started_at", { ascending: false })
    .limit(20);

  if (!sessions || sessions.length < 3) return null;

  const istOffsetMs = 5.5 * 60 * 60 * 1000;
  const hours = sessions.map((s) => {
    const utcDate = new Date(s.started_at);
    const istDate = new Date(utcDate.getTime() + istOffsetMs);
    return istDate.getUTCHours();
  });

  hours.sort((a, b) => a - b);
  const mid = Math.floor(hours.length / 2);
  return hours.length % 2 === 0
    ? Math.round((hours[mid - 1] + hours[mid]) / 2)
    : hours[mid];
}

/** Get protein deficit for today (target - consumed) */
async function getProteinDeficit(userId: string, todayStart: string): Promise<number | null> {
  // Get user's protein target
  const { data: user } = await adminClient
    .from("users")
    .select("daily_protein_target")
    .eq("id", userId)
    .maybeSingle();

  if (!user || !user.daily_protein_target) return null;

  // Get today's food logs with protein data
  const { data: logs } = await adminClient
    .from("food_logs")
    .select("detected_items")
    .eq("user_id", userId)
    .gte("logged_at", todayStart);

  let totalProtein = 0;
  for (const log of logs ?? []) {
    const items = log.detected_items;
    if (Array.isArray(items)) {
      for (const item of items) {
        totalProtein += Number(item.protein ?? 0);
      }
    }
  }

  const deficit = user.daily_protein_target - totalProtein;
  return deficit > 0 ? deficit : null;
}

/** Get weekly summary stats for a user */
async function getWeeklySummary(userId: string): Promise<{
  foodLogs: number;
  pushups: number;
  avgProtein: number;
}> {
  const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

  // Count food logs this week
  const { data: foodData, count: foodCount } = await adminClient
    .from("food_logs")
    .select("detected_items", { count: "exact" })
    .eq("user_id", userId)
    .gte("logged_at", weekAgo);

  // Count pushup sessions this week
  const { count: pushupCount } = await adminClient
    .from("pushup_sessions")
    .select("id", { count: "exact" })
    .eq("user_id", userId)
    .eq("status", "verified")
    .gte("completed_at", weekAgo);

  // Calculate average daily protein
  let totalProtein = 0;
  for (const log of foodData ?? []) {
    const items = log.detected_items;
    if (Array.isArray(items)) {
      for (const item of items) {
        totalProtein += Number(item.protein ?? 0);
      }
    }
  }
  const avgProtein = Math.round(totalProtein / 7);

  return {
    foodLogs: foodCount ?? 0,
    pushups: pushupCount ?? 0,
    avgProtein,
  };
}
