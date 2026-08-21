import {
  adminClient,
  body,
  FunctionError,
  invoke,
  requireUser,
  round,
} from "../_shared/common.ts";

/**
 * generate-health-report -- builds a structured weekly or monthly health report
 * for a user, then calls Gemini for a personalised insight paragraph.
 *
 * The function returns all the numbers/tables the Flutter client needs to render
 * the report card -- the client does layout and charting, not the server.
 *
 * Model: gemini-2.5-flash. Good for short structured generation within budget.
 */

const MODEL = "gemini-2.5-flash";

// ---------- types ----------

interface DayNutrition {
  date: string; // YYYY-MM-DD
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  water_ml: number;
}

interface PushupDayEntry {
  date: string;
  completed: boolean;
  reps: number;
  fine_amount_paise: number;
}

interface FoodFrequency {
  name: string;
  frequency: number;
  calories: number;
  protein: number;
}

interface WeekBucket {
  label: string; // "Week 1", "Week 2", ...
  avg_calories: number;
  avg_protein: number;
  pushup_days: number;
  avg_water_ml: number;
}

// ---------- IST helpers ----------

function istNow(): Date {
  return new Date(Date.now() + 5.5 * 60 * 60 * 1000);
}

/** Returns a Date at midnight IST for the given YYYY-MM-DD string. */
function istMidnight(dateStr: string): Date {
  return new Date(`${dateStr}T00:00:00+05:30`);
}

/** Formats a Date (assumed IST-shifted) as YYYY-MM-DD. */
function toIstDateStr(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/** Gets the ISO day of week (1=Mon ... 7=Sun) from an IST-shifted Date. */
function istDayOfWeek(d: Date): number {
  const day = d.getUTCDay(); // 0=Sun
  return day === 0 ? 7 : day;
}

/** Returns [startDate, endDate] for the most recent completed week (Mon-Sun). */
function lastCompletedWeek(): [string, string] {
  const now = istNow();
  const todayStr = toIstDateStr(now);
  const todayMidnight = istMidnight(todayStr);
  const dow = istDayOfWeek(todayMidnight);
  // Most recent Sunday: go back 'dow' days from today
  const lastSunday = new Date(todayMidnight.getTime() - dow * 86400000);
  const lastMonday = new Date(lastSunday.getTime() - 6 * 86400000);
  return [toIstDateStr(lastMonday), toIstDateStr(lastSunday)];
}

/** Returns [startDate, endDate] for the most recent completed month (first to last day). */
function lastCompletedMonth(): [string, string] {
  const now = istNow();
  const year = now.getUTCFullYear();
  const month = now.getUTCMonth(); // 0-indexed; current month
  // Previous month
  let prevYear = year;
  let prevMonth = month - 1;
  if (prevMonth < 0) {
    prevMonth = 11;
    prevYear -= 1;
  }
  const startStr = `${prevYear}-${String(prevMonth + 1).padStart(2, "0")}-01`;
  // Last day of previous month = day 0 of current month
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const endStr = `${prevYear}-${String(prevMonth + 1).padStart(2, "0")}-${String(lastDay).padStart(2, "0")}`;
  return [startStr, endStr];
}

/** Generates all date strings between start and end inclusive. */
function dateRange(start: string, end: string): string[] {
  const dates: string[] = [];
  let current = istMidnight(start).getTime();
  const endTime = istMidnight(end).getTime();
  while (current <= endTime) {
    dates.push(toIstDateStr(new Date(current)));
    current += 86400000;
  }
  return dates;
}

// ---------- data fetching ----------

interface FoodLogRow {
  detected_items: unknown;
  meal_type: string;
  logged_at: string;
}

interface WaterLogRow {
  amount_ml: number;
  logged_at: string;
}

interface WeightLogRow {
  weight_kg: number;
  logged_at: string;
}

interface PushupRow {
  status: string;
  rep_count: number;
  started_at: string;
  completed_at: string | null;
}

interface FineRow {
  amount_paise: number;
  status: string;
  reason: string;
  created_at: string;
}

interface UserProfile {
  name: string | null;
  daily_calorie_target: number | null;
  daily_protein_target: number | null;
  pushup_target: number | null;
  weight: number | null;
  height: number | null;
}

interface StreakRow {
  current_pushup_streak: number | null;
  longest_pushup_streak: number | null;
  current_food_log_streak: number | null;
}

async function fetchFoodLogs(
  userId: string,
  startIso: string,
  endIso: string,
): Promise<FoodLogRow[]> {
  const all: FoodLogRow[] = [];
  const pageSize = 1000;
  let from = 0;
  while (true) {
    const { data, error } = await adminClient
      .from("food_logs")
      .select("detected_items, meal_type, logged_at")
      .eq("user_id", userId)
      .gte("logged_at", startIso)
      .lt("logged_at", endIso)
      .order("logged_at", { ascending: true })
      .range(from, from + pageSize - 1);
    if (error) throw new FunctionError(500, "Failed to fetch food logs.");
    all.push(...(data ?? []));
    if (!data || data.length < pageSize) break;
    from += pageSize;
  }
  return all;
}

async function fetchWaterLogs(
  userId: string,
  startIso: string,
  endIso: string,
): Promise<WaterLogRow[]> {
  const { data, error } = await adminClient
    .from("water_logs")
    .select("amount_ml, logged_at")
    .eq("user_id", userId)
    .gte("logged_at", startIso)
    .lt("logged_at", endIso)
    .order("logged_at", { ascending: true })
    .limit(2000);
  if (error) throw new FunctionError(500, "Failed to fetch water logs.");
  return data ?? [];
}

async function fetchWeightLogs(
  userId: string,
  startIso: string,
  endIso: string,
): Promise<WeightLogRow[]> {
  const { data, error } = await adminClient
    .from("weight_logs")
    .select("weight_kg, logged_at")
    .eq("user_id", userId)
    .gte("logged_at", startIso)
    .lt("logged_at", endIso)
    .order("logged_at", { ascending: true })
    .limit(100);
  if (error) throw new FunctionError(500, "Failed to fetch weight logs.");
  return data ?? [];
}

async function fetchPushupSessions(
  userId: string,
  startIso: string,
  endIso: string,
): Promise<PushupRow[]> {
  const { data, error } = await adminClient
    .from("pushup_sessions")
    .select("status, rep_count, started_at, completed_at")
    .eq("user_id", userId)
    .gte("started_at", startIso)
    .lt("started_at", endIso)
    .order("started_at", { ascending: true })
    .limit(500);
  if (error) throw new FunctionError(500, "Failed to fetch pushup sessions.");
  return data ?? [];
}

async function fetchFines(
  userId: string,
  startIso: string,
  endIso: string,
): Promise<FineRow[]> {
  const { data, error } = await adminClient
    .from("fines")
    .select("amount_paise, status, reason, created_at")
    .eq("user_id", userId)
    .gte("created_at", startIso)
    .lt("created_at", endIso)
    .order("created_at", { ascending: true })
    .limit(500);
  if (error) throw new FunctionError(500, "Failed to fetch fines.");
  return data ?? [];
}

async function fetchProfile(userId: string): Promise<UserProfile> {
  const { data, error } = await adminClient
    .from("users")
    .select("name, daily_calorie_target, daily_protein_target, pushup_target, weight, height")
    .eq("id", userId)
    .maybeSingle();
  if (error) throw new FunctionError(500, "Failed to fetch user profile.");
  return {
    name: data?.name ?? null,
    daily_calorie_target: data?.daily_calorie_target ?? 2000,
    daily_protein_target: data?.daily_protein_target ?? 100,
    pushup_target: data?.pushup_target ?? 7,
    weight: data?.weight ?? null,
    height: data?.height ?? null,
  };
}

async function fetchStreaks(userId: string): Promise<StreakRow> {
  const { data, error } = await adminClient
    .from("streaks")
    .select("current_pushup_streak, longest_pushup_streak, current_food_log_streak")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new FunctionError(500, "Failed to fetch streaks.");
  return {
    current_pushup_streak: data?.current_pushup_streak ?? 0,
    longest_pushup_streak: data?.longest_pushup_streak ?? 0,
    current_food_log_streak: data?.current_food_log_streak ?? 0,
  };
}

// ---------- aggregation ----------

function logDateIst(loggedAt: string): string {
  // Convert UTC timestamp to IST date string
  const ts = new Date(loggedAt).getTime();
  const ist = new Date(ts + 5.5 * 60 * 60 * 1000);
  return toIstDateStr(ist);
}

function aggregateDailyNutrition(
  dates: string[],
  foodLogs: FoodLogRow[],
  waterLogs: WaterLogRow[],
): DayNutrition[] {
  const dayMap: Record<string, DayNutrition> = {};
  for (const d of dates) {
    dayMap[d] = { date: d, calories: 0, protein: 0, carbs: 0, fat: 0, water_ml: 0 };
  }

  for (const log of foodLogs) {
    const day = logDateIst(log.logged_at);
    if (!dayMap[day]) continue;
    const items = Array.isArray(log.detected_items) ? log.detected_items : [];
    for (const raw of items) {
      const item = (raw ?? {}) as Record<string, unknown>;
      dayMap[day].calories += Number(item.calories) || 0;
      dayMap[day].protein += Number(item.protein) || 0;
      dayMap[day].carbs += Number(item.carbs) || 0;
      dayMap[day].fat += Number(item.fat) || 0;
    }
  }

  for (const log of waterLogs) {
    const day = logDateIst(log.logged_at);
    if (!dayMap[day]) continue;
    dayMap[day].water_ml += Number(log.amount_ml) || 0;
  }

  return dates.map((d) => ({
    date: dayMap[d].date,
    calories: round(dayMap[d].calories),
    protein: round(dayMap[d].protein),
    carbs: round(dayMap[d].carbs),
    fat: round(dayMap[d].fat),
    water_ml: round(dayMap[d].water_ml),
  }));
}

function aggregatePushupLog(
  dates: string[],
  pushups: PushupRow[],
  fines: FineRow[],
): PushupDayEntry[] {
  const dayReps: Record<string, number> = {};
  for (const d of dates) dayReps[d] = 0;

  for (const session of pushups) {
    if (session.status !== "verified") continue;
    const day = logDateIst(session.started_at);
    if (day in dayReps) {
      dayReps[day] += Number(session.rep_count) || 0;
    }
  }

  const dayFines: Record<string, number> = {};
  for (const d of dates) dayFines[d] = 0;
  for (const fine of fines) {
    const day = logDateIst(fine.created_at);
    if (day in dayFines) {
      dayFines[day] += Number(fine.amount_paise) || 0;
    }
  }

  return dates.map((d) => ({
    date: d,
    completed: dayReps[d] > 0,
    reps: dayReps[d],
    fine_amount_paise: dayFines[d],
  }));
}

function computeMostLoggedFoods(foodLogs: FoodLogRow[], topN: number): FoodFrequency[] {
  const freq: Record<string, { count: number; totalCalories: number; totalProtein: number }> = {};

  for (const log of foodLogs) {
    const items = Array.isArray(log.detected_items) ? log.detected_items : [];
    for (const raw of items) {
      const item = (raw ?? {}) as Record<string, unknown>;
      const name = String(item.name ?? "").trim().toLowerCase();
      if (!name) continue;
      if (!freq[name]) freq[name] = { count: 0, totalCalories: 0, totalProtein: 0 };
      freq[name].count += 1;
      freq[name].totalCalories += Number(item.calories) || 0;
      freq[name].totalProtein += Number(item.protein) || 0;
    }
  }

  return Object.entries(freq)
    .sort((a, b) => b[1].count - a[1].count)
    .slice(0, topN)
    .map(([name, stats]) => ({
      name,
      frequency: stats.count,
      calories: round(stats.totalCalories / stats.count),
      protein: round(stats.totalProtein / stats.count),
    }));
}

function computeWeekBuckets(
  dates: string[],
  dailyNutrition: DayNutrition[],
  pushupLog: PushupDayEntry[],
): WeekBucket[] {
  const buckets: WeekBucket[] = [];
  const chunkSize = 7;
  let weekIndex = 1;

  for (let i = 0; i < dates.length; i += chunkSize) {
    const chunk = dates.slice(i, i + chunkSize);
    const daysInChunk = chunk.length;

    let totalCal = 0, totalProt = 0, totalWater = 0;
    let pushupDays = 0;

    for (const d of chunk) {
      const dn = dailyNutrition.find((n) => n.date === d);
      if (dn) {
        totalCal += dn.calories;
        totalProt += dn.protein;
        totalWater += dn.water_ml;
      }
      const pl = pushupLog.find((p) => p.date === d);
      if (pl && pl.completed) pushupDays += 1;
    }

    buckets.push({
      label: `Week ${weekIndex}`,
      avg_calories: round(totalCal / daysInChunk),
      avg_protein: round(totalProt / daysInChunk),
      pushup_days: pushupDays,
      avg_water_ml: round(totalWater / daysInChunk),
    });
    weekIndex += 1;
  }

  return buckets;
}

// ---------- AI insight ----------

const INSIGHT_SCHEMA = {
  type: "OBJECT",
  properties: {
    insight: { type: "STRING" },
  },
  required: ["insight"],
};

async function generateInsight(
  reportType: string,
  context: string,
): Promise<string> {
  const key = Deno.env.get("VISION_API_KEY") ?? "";
  if (!key) return "AI insight is not available at this time.";

  const systemPrompt = `You are RepGate's health report analyst. Generate a brief, data-driven insight paragraph (2-3 sentences) for the user's ${reportType} health report.

Rules:
- Reference specific numbers from the data (percentages, day names, actual values).
- Be encouraging but honest. Highlight both strengths and one area to improve.
- Keep it under 60 words total.
- Do not use bullet points or lists. Write flowing prose.
- Do not give medical advice.

Respond ONLY with {"insight": "your text here"}.`;

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(MODEL)}:generateContent?key=${encodeURIComponent(key)}`;

  const payload = JSON.stringify({
    contents: [{ role: "user", parts: [{ text: context }] }],
    systemInstruction: { parts: [{ text: systemPrompt }] },
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 300,
      responseMimeType: "application/json",
      responseSchema: INSIGHT_SCHEMA,
    },
  });

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20_000);
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: controller.signal,
      body: payload,
    });
    clearTimeout(timeout);

    if (!response.ok) {
      console.error(`[health-report] Gemini ${response.status}: ${(await response.text()).slice(0, 200)}`);
      return "AI insight could not be generated at this time.";
    }

    const data = await response.json() as {
      candidates?: { content?: { parts?: { text?: string }[] } }[];
    };
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    if (!text) return "AI insight could not be generated at this time.";

    const parsed = JSON.parse(text) as { insight?: string };
    return String(parsed.insight ?? "").trim() || "AI insight could not be generated at this time.";
  } catch (err) {
    console.error("[health-report] insight generation failed:", err);
    return "AI insight could not be generated at this time.";
  }
}

function buildInsightContext(
  reportType: string,
  profile: UserProfile,
  dailyNutrition: DayNutrition[],
  pushupLog: PushupDayEntry[],
  weightLogs: WeightLogRow[],
  streaks: StreakRow,
): string {
  const lines: string[] = [];
  lines.push(`Report type: ${reportType}`);
  lines.push(`User: ${profile.name ?? "Unknown"}`);
  lines.push(`Targets: ${profile.daily_calorie_target} kcal/day, ${profile.daily_protein_target}g protein/day, ${profile.pushup_target} pushup days/week`);

  const totalDays = dailyNutrition.length;
  const loggedDays = dailyNutrition.filter((d) => d.calories > 0).length;
  const avgCal = totalDays > 0 ? round(dailyNutrition.reduce((s, d) => s + d.calories, 0) / totalDays) : 0;
  const avgProt = totalDays > 0 ? round(dailyNutrition.reduce((s, d) => s + d.protein, 0) / totalDays) : 0;
  const avgWater = totalDays > 0 ? round(dailyNutrition.reduce((s, d) => s + d.water_ml, 0) / totalDays) : 0;
  lines.push(`Nutrition (${totalDays} days, ${loggedDays} logged): avg ${avgCal} kcal, ${avgProt}g protein, ${avgWater}ml water/day`);

  const pushupDaysCount = pushupLog.filter((p) => p.completed).length;
  const totalReps = pushupLog.reduce((s, p) => s + p.reps, 0);
  lines.push(`Push-ups: ${pushupDaysCount}/${totalDays} days completed, ${totalReps} total reps`);

  if (weightLogs.length >= 2) {
    const startW = weightLogs[0].weight_kg;
    const endW = weightLogs[weightLogs.length - 1].weight_kg;
    lines.push(`Weight: ${startW} kg start, ${endW} kg end, change ${round(endW - startW)} kg`);
  } else if (weightLogs.length === 1) {
    lines.push(`Weight: ${weightLogs[0].weight_kg} kg (single entry)`);
  }

  lines.push(`Streaks: current ${streaks.current_pushup_streak}, longest ${streaks.longest_pushup_streak}`);

  // Per-day breakdown for weekly
  if (totalDays <= 7) {
    const dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    for (let i = 0; i < dailyNutrition.length; i++) {
      const d = dailyNutrition[i];
      const p = pushupLog[i];
      const label = dayNames[i] ?? d.date;
      lines.push(`  ${label}: ${d.calories} kcal, ${d.protein}g prot, ${p?.reps ?? 0} reps`);
    }
  }

  return lines.join("\n");
}

// ---------- response builders ----------

function formatDateRange(start: string, end: string): string {
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const s = new Date(start + "T00:00:00Z");
  const e = new Date(end + "T00:00:00Z");
  const sMonth = months[s.getUTCMonth()];
  const eMonth = months[e.getUTCMonth()];
  if (sMonth === eMonth) {
    return `${sMonth} ${s.getUTCDate()} - ${eMonth} ${e.getUTCDate()}, ${e.getUTCFullYear()}`;
  }
  return `${sMonth} ${s.getUTCDate()} - ${eMonth} ${e.getUTCDate()}, ${e.getUTCFullYear()}`;
}

function formatMonthLabel(start: string): string {
  const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  const d = new Date(start + "T00:00:00Z");
  return `${months[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

async function buildWeeklyReport(userId: string) {
  const [startDate, endDate] = lastCompletedWeek();
  const startIso = istMidnight(startDate).toISOString();
  const endIso = new Date(istMidnight(endDate).getTime() + 86400000).toISOString(); // end of Sunday

  const dates = dateRange(startDate, endDate);

  const [foodLogs, waterLogs, weightLogs, pushups, fines, profile, streaks] = await Promise.all([
    fetchFoodLogs(userId, startIso, endIso),
    fetchWaterLogs(userId, startIso, endIso),
    fetchWeightLogs(userId, startIso, endIso),
    fetchPushupSessions(userId, startIso, endIso),
    fetchFines(userId, startIso, endIso),
    fetchProfile(userId),
    fetchStreaks(userId),
  ]);

  const dailyNutrition = aggregateDailyNutrition(dates, foodLogs, waterLogs);
  const pushupLog = aggregatePushupLog(dates, pushups, fines);
  const mostLoggedFoods = computeMostLoggedFoods(foodLogs, 5);

  // Top stats
  const pushupDays = pushupLog.filter((p) => p.completed).length;
  const totalReps = pushupLog.reduce((s, p) => s + p.reps, 0);
  const totalDays = dates.length;
  const avgCalPerDay = totalDays > 0 ? round(dailyNutrition.reduce((s, d) => s + d.calories, 0) / totalDays) : 0;
  const avgProtPerDay = totalDays > 0 ? round(dailyNutrition.reduce((s, d) => s + d.protein, 0) / totalDays) : 0;

  // Nutrition summary
  const avgCarbs = totalDays > 0 ? round(dailyNutrition.reduce((s, d) => s + d.carbs, 0) / totalDays) : 0;
  const avgFat = totalDays > 0 ? round(dailyNutrition.reduce((s, d) => s + d.fat, 0) / totalDays) : 0;
  const avgWater = totalDays > 0 ? round(dailyNutrition.reduce((s, d) => s + d.water_ml, 0) / totalDays) : 0;

  const calTarget = profile.daily_calorie_target ?? 2000;
  const protTarget = profile.daily_protein_target ?? 100;

  const nutritionSummary = [
    { metric: "Calories", daily_average: avgCalPerDay, target: calTarget, status: avgCalPerDay >= calTarget * 0.9 ? "on_track" : "below_target" },
    { metric: "Protein", daily_average: avgProtPerDay, target: protTarget, status: avgProtPerDay >= protTarget * 0.9 ? "on_track" : "below_target" },
    { metric: "Carbohydrates", daily_average: avgCarbs, target: null, status: "info" },
    { metric: "Fat", daily_average: avgFat, target: null, status: "info" },
    { metric: "Water", daily_average: avgWater, target: null, status: "info" },
  ];

  // Progress summary
  const startWeight = weightLogs.length > 0 ? weightLogs[0].weight_kg : (profile.weight ?? null);
  const currentWeight = weightLogs.length > 0 ? weightLogs[weightLogs.length - 1].weight_kg : (profile.weight ?? null);
  const weightChange = (startWeight != null && currentWeight != null) ? round(currentWeight - startWeight) : null;

  // AI insight
  const insightContext = buildInsightContext("weekly", profile, dailyNutrition, pushupLog, weightLogs, streaks);
  const insight = await generateInsight("weekly", insightContext);

  return {
    type: "weekly",
    header: {
      date_range: formatDateRange(startDate, endDate),
      start_date: startDate,
      end_date: endDate,
      user_name: profile.name ?? "User",
    },
    top_stats: {
      pushup_days: { value: pushupDays, total: totalDays },
      total_reps: totalReps,
      avg_calories_per_day: avgCalPerDay,
      avg_protein_per_day: avgProtPerDay,
    },
    nutrition_summary: nutritionSummary,
    daily_trends: dailyNutrition,
    pushup_log: pushupLog,
    most_logged_foods: mostLoggedFoods,
    progress_summary: {
      starting_weight: startWeight,
      current_weight: currentWeight,
      weight_change: weightChange,
      current_streak: streaks.current_pushup_streak ?? 0,
      longest_streak: streaks.longest_pushup_streak ?? 0,
    },
    insight: insight,
    footer: "Nutrition values are AI-estimated from food photos and are not a substitute for medical or dietetic advice. Generated automatically by Repgate.",
  };
}

async function buildMonthlyReport(userId: string) {
  const [startDate, endDate] = lastCompletedMonth();
  const startIso = istMidnight(startDate).toISOString();
  const endIso = new Date(istMidnight(endDate).getTime() + 86400000).toISOString(); // end of last day

  const dates = dateRange(startDate, endDate);

  const [foodLogs, waterLogs, weightLogs, pushups, fines, profile, streaks] = await Promise.all([
    fetchFoodLogs(userId, startIso, endIso),
    fetchWaterLogs(userId, startIso, endIso),
    fetchWeightLogs(userId, startIso, endIso),
    fetchPushupSessions(userId, startIso, endIso),
    fetchFines(userId, startIso, endIso),
    fetchProfile(userId),
    fetchStreaks(userId),
  ]);

  const dailyNutrition = aggregateDailyNutrition(dates, foodLogs, waterLogs);
  const pushupLog = aggregatePushupLog(dates, pushups, fines);
  const mostLoggedFoods = computeMostLoggedFoods(foodLogs, 5);
  const weeklyBreakdown = computeWeekBuckets(dates, dailyNutrition, pushupLog);

  // Top stats
  const totalDays = dates.length;
  const pushupDaysTotal = pushupLog.filter((p) => p.completed).length;
  const totalReps = pushupLog.reduce((s, p) => s + p.reps, 0);
  const avgCalPerDay = totalDays > 0 ? round(dailyNutrition.reduce((s, d) => s + d.calories, 0) / totalDays) : 0;
  const avgProtPerDay = totalDays > 0 ? round(dailyNutrition.reduce((s, d) => s + d.protein, 0) / totalDays) : 0;

  // Discipline summary
  const missedDays = totalDays - pushupDaysTotal;
  const totalFinesPaise = fines.reduce((s, f) => s + (Number(f.amount_paise) || 0), 0);

  // Progress
  const startWeight = weightLogs.length > 0 ? weightLogs[0].weight_kg : (profile.weight ?? null);
  const currentWeight = weightLogs.length > 0 ? weightLogs[weightLogs.length - 1].weight_kg : (profile.weight ?? null);
  const weightChange = (startWeight != null && currentWeight != null) ? round(currentWeight - startWeight) : null;

  // AI insight
  const insightContext = buildInsightContext("monthly", profile, dailyNutrition, pushupLog, weightLogs, streaks);
  const insight = await generateInsight("monthly", insightContext);

  return {
    type: "monthly",
    header: {
      month_label: formatMonthLabel(startDate),
      start_date: startDate,
      end_date: endDate,
      user_name: profile.name ?? "User",
    },
    top_stats: {
      current_streak: streaks.current_pushup_streak ?? 0,
      total_reps: totalReps,
      avg_calories_per_day: avgCalPerDay,
      avg_protein_per_day: avgProtPerDay,
    },
    nutrition_summary: [
      { metric: "Calories", daily_average: avgCalPerDay, target: profile.daily_calorie_target ?? 2000, status: avgCalPerDay >= (profile.daily_calorie_target ?? 2000) * 0.9 ? "on_track" : "below_target" },
      { metric: "Protein", daily_average: avgProtPerDay, target: profile.daily_protein_target ?? 100, status: avgProtPerDay >= (profile.daily_protein_target ?? 100) * 0.9 ? "on_track" : "below_target" },
    ],
    weekly_breakdown: weeklyBreakdown,
    daily_trends: dailyNutrition,
    pushup_log: pushupLog,
    most_logged_foods: mostLoggedFoods,
    discipline_summary: {
      total_reps: totalReps,
      current_streak: streaks.current_pushup_streak ?? 0,
      longest_streak_this_month: streaks.longest_pushup_streak ?? 0,
      missed_days: missedDays,
      total_fines_paise: totalFinesPaise,
    },
    progress_summary: {
      starting_weight: startWeight,
      current_weight: currentWeight,
      weight_change: weightChange,
    },
    insight: insight,
    footer: "Nutrition values are AI-estimated from food photos and are not a substitute for medical or dietetic advice. Generated automatically by Repgate.",
  };
}

// ---------- entry point ----------

Deno.serve((req) =>
  invoke("generate-health-report", req, async (request) => {
    const { user } = await requireUser(request);
    const input = await body(request);

    const type = String(input.type ?? "").trim();
    if (type !== "weekly" && type !== "monthly") {
      throw new FunctionError(400, "type must be 'weekly' or 'monthly'.");
    }

    if (type === "weekly") {
      return await buildWeeklyReport(user.id);
    } else {
      return await buildMonthlyReport(user.id);
    }
  })
);
