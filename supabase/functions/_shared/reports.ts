// ==========================================================================
// Weekly / monthly report builder + emailer (Azure ACS delivered)
// ==========================================================================
//
// Shared by send-weekly-report and send-monthly-report. Builds a per-user
// health summary over a period and emails it via Azure Communication Services.
// Delivery is best-effort: a single user's failure never aborts the sweep.

import { adminClient } from "./common.ts";
import { isAzureEmailConfigured, sendAzureEmail } from "./azure_email.ts";

export type ReportPeriod = "weekly" | "monthly";

interface UserRow {
  id: string;
  name: string | null;
  report_email: string | null;
  daily_calorie_target: number | null;
  daily_protein_target: number | null;
  weekly_report_opt_in: boolean;
  monthly_report_opt_in: boolean;
}

interface Summary {
  days: number;
  foodLogDays: number;
  totalCalories: number;
  avgCaloriesPerLoggedDay: number;
  totalProtein: number;
  waterMl: number;
  pushupSessions: number;
  pushupReps: number;
  currentPushupStreak: number;
  weightStart: number | null;
  weightEnd: number | null;
}

function sumItems(items: unknown, key: string): number {
  if (!Array.isArray(items)) return 0;
  let total = 0;
  for (const it of items) {
    if (it && typeof it === "object" && typeof (it as Record<string, unknown>)[key] === "number") {
      total += (it as Record<string, number>)[key];
    }
  }
  return total;
}

async function buildSummary(userId: string, sinceIso: string, days: number): Promise<Summary> {
  const [food, water, weight, pushups, streak] = await Promise.all([
    adminClient.from("food_logs").select("logged_at, detected_items").eq("user_id", userId).gte("logged_at", sinceIso).limit(2000),
    adminClient.from("water_logs").select("amount_ml").eq("user_id", userId).gte("logged_at", sinceIso).limit(2000),
    adminClient.from("weight_logs").select("weight_kg, logged_at").eq("user_id", userId).gte("logged_at", sinceIso).order("logged_at", { ascending: true }).limit(500),
    adminClient.from("pushup_sessions").select("rep_count").eq("user_id", userId).eq("status", "verified").gte("completed_at", sinceIso).limit(500),
    adminClient.from("streaks").select("current_pushup_streak").eq("user_id", userId).maybeSingle(),
  ]);

  const foodRows = food.data ?? [];
  const loggedDays = new Set<string>();
  let totalCalories = 0;
  let totalProtein = 0;
  for (const row of foodRows) {
    totalCalories += sumItems(row.detected_items, "calories");
    totalProtein += sumItems(row.detected_items, "protein");
    const d = String(row.logged_at ?? "").slice(0, 10);
    if (d) loggedDays.add(d);
  }

  const waterMl = (water.data ?? []).reduce((s, r) => s + Number(r.amount_ml ?? 0), 0);
  const pushupReps = (pushups.data ?? []).reduce((s, r) => s + Number(r.rep_count ?? 0), 0);
  const weightRows = weight.data ?? [];

  return {
    days,
    foodLogDays: loggedDays.size,
    totalCalories: Math.round(totalCalories),
    avgCaloriesPerLoggedDay: loggedDays.size > 0 ? Math.round(totalCalories / loggedDays.size) : 0,
    totalProtein: Math.round(totalProtein),
    waterMl,
    pushupSessions: (pushups.data ?? []).length,
    pushupReps,
    currentPushupStreak: Number(streak.data?.current_pushup_streak ?? 0),
    weightStart: weightRows.length ? Number(weightRows[0].weight_kg) : null,
    weightEnd: weightRows.length ? Number(weightRows[weightRows.length - 1].weight_kg) : null,
  };
}

function stat(label: string, value: string, accent = "#b5e048"): string {
  return `<tr>
    <td style="padding:12px 0;border-bottom:1px solid #2e332f;color:#8e8e93;font-size:14px;">${label}</td>
    <td style="padding:12px 0;border-bottom:1px solid #2e332f;color:${accent};font-size:16px;font-weight:700;text-align:right;">${value}</td>
  </tr>`;
}

function reportHtml(name: string, period: ReportPeriod, s: Summary): string {
  const title = period === "weekly" ? "Your week at RepGate" : "Your month at RepGate";
  const greeting = name && name.trim().length > 0 ? name.trim() : "there";
  const weightLine = s.weightStart != null && s.weightEnd != null
    ? `${s.weightStart.toFixed(1)} → ${s.weightEnd.toFixed(1)} kg (${(s.weightEnd - s.weightStart >= 0 ? "+" : "")}${(s.weightEnd - s.weightStart).toFixed(1)})`
    : "No weigh-ins logged";
  const waterLabel = s.waterMl >= 1000 ? `${(s.waterMl / 1000).toFixed(1)} L` : `${s.waterMl} ml`;

  return `<!doctype html><html><body style="margin:0;background:#0f1110;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
  <div style="max-width:520px;margin:0 auto;padding:32px 24px;">
    <div style="background:#1a1d1b;border-radius:24px;padding:32px;border:1px solid #2e332f;">
      <div style="font-size:22px;font-weight:800;color:#b5e048;letter-spacing:-0.4px;">RepGate</div>
      <h1 style="font-size:22px;color:#ffffff;margin:18px 0 6px;">${title}</h1>
      <p style="font-size:14px;color:#8e8e93;margin:0 0 24px;">Hi ${greeting}, here's your summary over the last ${s.days} days.</p>
      <table style="width:100%;border-collapse:collapse;">
        ${stat("Push-ups verified", `${s.pushupReps} reps · ${s.pushupSessions} sessions`)}
        ${stat("Current push-up streak", `${s.currentPushupStreak} days`, "#ff9500")}
        ${stat("Days you logged food", `${s.foodLogDays} / ${s.days}`)}
        ${stat("Avg calories / logged day", `${s.avgCaloriesPerLoggedDay} kcal`)}
        ${stat("Total protein", `${s.totalProtein} g`, "#2196f3")}
        ${stat("Water logged", waterLabel, "#32ade6")}
        ${stat("Weight", weightLine, "#ffffff")}
      </table>
      <p style="font-size:13px;color:#8e8e93;margin:26px 0 0;">Keep earning your screen time. Open RepGate to log today.</p>
      <p style="font-size:11px;color:#5a5f5b;margin:18px 0 0;">You're receiving this because ${period} reports are on in your RepGate settings.</p>
    </div>
  </div></body></html>`;
}

export interface ReportRunResult {
  period: ReportPeriod;
  eligible: number;
  sent: number;
  skipped: number;
  failed: number;
  configured: boolean;
}

/**
 * Runs the report sweep for the given period. Enumerates opted-in users, builds
 * each summary, and emails it via Azure ACS. Per-user failures are isolated.
 */
export async function runReportSweep(period: ReportPeriod): Promise<ReportRunResult> {
  const configured = isAzureEmailConfigured();
  const result: ReportRunResult = { period, eligible: 0, sent: 0, skipped: 0, failed: 0, configured };
  if (!configured) return result; // nothing to do; caller logs this

  const days = period === "weekly" ? 7 : 30;
  const sinceIso = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
  const optInColumn = period === "weekly" ? "weekly_report_opt_in" : "monthly_report_opt_in";
  const stampColumn = period === "weekly" ? "last_weekly_report_at" : "last_monthly_report_at";
  const pageSize = 200;

  for (let from = 0; ; from += pageSize) {
    const { data, error } = await adminClient
      .from("users")
      .select("id, name, report_email, daily_calorie_target, daily_protein_target, weekly_report_opt_in, monthly_report_opt_in")
      .eq(optInColumn, true)
      .not("report_email", "is", null)
      .order("id", { ascending: true })
      .range(from, from + pageSize - 1);
    if (error) break;
    const rows = (data ?? []) as UserRow[];
    if (rows.length === 0) break;

    for (const user of rows) {
      const email = (user.report_email ?? "").trim();
      if (!email) { result.skipped++; continue; }
      result.eligible++;
      try {
        const summary = await buildSummary(user.id, sinceIso, days);
        // Skip users with no activity at all this period — avoids empty emails.
        if (summary.pushupReps === 0 && summary.foodLogDays === 0 && summary.waterMl === 0) {
          result.skipped++;
          continue;
        }
        const sendRes = await sendAzureEmail({
          to: email,
          subject: period === "weekly" ? "Your RepGate weekly report" : "Your RepGate monthly report",
          html: reportHtml(user.name ?? "", period, summary),
        });
        if (sendRes.ok) {
          result.sent++;
          await adminClient.from("users").update({ [stampColumn]: new Date().toISOString() }).eq("id", user.id);
          await adminClient.from("notification_events").insert({
            user_id: user.id,
            event_type: `${period}_report_email`,
            payload: { email },
            delivered_at: new Date().toISOString(),
          }).then(() => {}, () => {});
        } else {
          result.failed++;
          console.error(`[${period}-report] send failed for ${user.id}`, sendRes.status, sendRes.error);
        }
      } catch (err) {
        result.failed++;
        console.error(`[${period}-report] error for ${user.id}`, err);
      }
    }

    if (rows.length < pageSize) break;
  }

  return result;
}
