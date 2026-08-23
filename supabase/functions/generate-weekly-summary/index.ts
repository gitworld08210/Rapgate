import { adminClient, invoke, requireCron, listUserIds } from "../_shared/common.ts";
import { recordAndSendNotification } from "../_shared/notifications.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent";

interface WeeklyData {
  foodLogs: number;
  avgCalories: number;
  avgProtein: number;
  waterLogs: number;
  avgWaterMl: number;
  pushupSessions: number;
  totalReps: number;
  currentStreak: number;
}

async function fetchUserWeekData(uid: string, weekStart: string, weekEnd: string): Promise<WeeklyData> {
  const [foodRes, waterRes, pushupRes, streakRes] = await Promise.all([
    adminClient.from("food_logs").select("detected_items").eq("user_id", uid).gte("logged_at", weekStart).lt("logged_at", weekEnd),
    adminClient.from("water_logs").select("amount_ml").eq("user_id", uid).gte("logged_at", weekStart).lt("logged_at", weekEnd),
    adminClient.from("pushup_sessions").select("rep_count").eq("user_id", uid).eq("status", "verified").gte("completed_at", weekStart).lt("completed_at", weekEnd),
    adminClient.from("streaks").select("current_pushup_streak").eq("user_id", uid).maybeSingle(),
  ]);

  const foodLogs = foodRes.data ?? [];
  let totalCalories = 0;
  let totalProtein = 0;
  for (const log of foodLogs) {
    const items = (log.detected_items as Array<{ calories?: number; protein?: number }>) ?? [];
    for (const item of items) {
      totalCalories += item.calories ?? 0;
      totalProtein += item.protein ?? 0;
    }
  }

  const waterLogs = waterRes.data ?? [];
  const totalWaterMl = waterLogs.reduce((sum: number, row: { amount_ml?: number }) => sum + (row.amount_ml ?? 0), 0);

  const pushupSessions = pushupRes.data ?? [];
  const totalReps = pushupSessions.reduce((sum: number, row: { rep_count?: number }) => sum + (row.rep_count ?? 0), 0);

  const daysWithFood = foodLogs.length > 0 ? Math.min(7, foodLogs.length) : 0;

  return {
    foodLogs: foodLogs.length,
    avgCalories: daysWithFood > 0 ? Math.round(totalCalories / daysWithFood) : 0,
    avgProtein: daysWithFood > 0 ? Math.round(totalProtein / daysWithFood) : 0,
    waterLogs: waterLogs.length,
    avgWaterMl: waterLogs.length > 0 ? Math.round(totalWaterMl / waterLogs.length) : 0,
    pushupSessions: pushupSessions.length,
    totalReps,
    currentStreak: streakRes.data?.current_pushup_streak ?? 0,
  };
}

function buildPrompt(data: WeeklyData): string {
  return `You are a supportive, concise health coach. Based on this user's weekly health data, write a brief encouraging summary (2-3 sentences) and exactly 3 short, actionable insights. Keep it positive and motivating.

Weekly data:
- Food logs recorded: ${data.foodLogs}
- Average daily calories: ${data.avgCalories} kcal
- Average daily protein: ${data.avgProtein}g
- Water logs: ${data.waterLogs} entries (avg ${data.avgWaterMl}ml per entry)
- Push-up sessions completed: ${data.pushupSessions}
- Total reps this week: ${data.totalReps}
- Current push-up streak: ${data.currentStreak} days

Respond in this exact JSON format:
{
  "summary": "Your 2-3 sentence encouraging summary here.",
  "insights": ["Insight 1", "Insight 2", "Insight 3"]
}`;
}

async function callGemini(prompt: string): Promise<{ summary: string; insights: string[] }> {
  const response = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 512,
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Gemini API error ${response.status}: ${errorText}`);
  }

  const result = await response.json();
  const text = result.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

  // Extract JSON from response (handles markdown code blocks)
  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    return { summary: text.trim(), insights: [] };
  }

  try {
    const parsed = JSON.parse(jsonMatch[0]);
    return {
      summary: parsed.summary ?? text.trim(),
      insights: Array.isArray(parsed.insights) ? parsed.insights.slice(0, 3) : [],
    };
  } catch {
    return { summary: text.trim(), insights: [] };
  }
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

Deno.serve((req) =>
  invoke("generate-weekly-summary", req, async (request) => {
    requireCron(request);

    if (!GEMINI_API_KEY) {
      return { error: "GEMINI_API_KEY not configured", processed: 0 };
    }

    const userIds = await listUserIds();
    const now = new Date();
    // Week start = last Monday
    const dayOfWeek = now.getDay();
    const mondayOffset = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
    const weekStartDate = new Date(now);
    weekStartDate.setDate(now.getDate() - mondayOffset - 7); // Previous week's Monday
    weekStartDate.setHours(0, 0, 0, 0);

    const weekEndDate = new Date(weekStartDate);
    weekEndDate.setDate(weekStartDate.getDate() + 7);

    const weekStart = weekStartDate.toISOString();
    const weekEnd = weekEndDate.toISOString();
    const weekStartStr = weekStartDate.toISOString().split("T")[0];

    let processed = 0;
    let errors = 0;

    for (const uid of userIds) {
      try {
        // Check if summary already exists for this week
        const { data: existing } = await adminClient
          .from("health_summaries")
          .select("id")
          .eq("user_id", uid)
          .eq("week_start", weekStartStr)
          .maybeSingle();

        if (existing) continue;

        const data = await fetchUserWeekData(uid, weekStart, weekEnd);

        // Skip users with no activity
        if (data.foodLogs === 0 && data.waterLogs === 0 && data.pushupSessions === 0) {
          continue;
        }

        const prompt = buildPrompt(data);
        const { summary, insights } = await callGemini(prompt);

        await adminClient.from("health_summaries").insert({
          user_id: uid,
          week_start: weekStartStr,
          summary_text: summary,
          insights: insights,
        });

        // Send notification
        await recordAndSendNotification(uid, "weekly_summary", {
          title: "Your Weekly Health Summary",
          body: "Your personalized health insights for this week are ready!",
          channel: "weekly_summary",
        });

        processed++;

        // Rate limit: 200ms delay between users to respect Gemini limits
        await delay(200);
      } catch (err) {
        console.error(`generate-weekly-summary failed for ${uid}:`, err);
        errors++;
        // Continue processing other users
        await delay(500);
      }
    }

    return { processed, errors, total: userIds.length };
  })
);
