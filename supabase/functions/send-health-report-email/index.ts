import {
  adminClient,
  body,
  FunctionError,
  invoke,
  requireUser,
  supabaseUrl,
} from "../_shared/common.ts";

/**
 * send-health-report-email -- generates a health report for the user, renders
 * it as an HTML email, and sends it to the user's registered email address
 * via the Resend API.
 *
 * Request body: { type: "weekly" | "monthly" }
 * Returns: { success: true, email: "<recipient>" }
 */

// ---------- types matching generate-health-report response ----------

interface TopStats {
  pushup_days?: { value: number; total: number };
  total_reps: number;
  avg_calories_per_day: number;
  avg_protein_per_day: number;
  current_streak?: number;
}

interface NutritionRow {
  metric: string;
  daily_average: number;
  target: number | null;
  status: string;
}

interface DailyTrend {
  date: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  water_ml: number;
}

interface PushupEntry {
  date: string;
  completed: boolean;
  reps: number;
  fine_amount_paise: number;
}

interface FoodEntry {
  name: string;
  frequency: number;
  calories: number;
  protein: number;
}

interface WeekBucket {
  label: string;
  avg_calories: number;
  avg_protein: number;
  pushup_days: number;
  avg_water_ml: number;
}

interface ProgressSummary {
  starting_weight: number | null;
  current_weight: number | null;
  weight_change: number | null;
  current_streak?: number;
  longest_streak?: number;
}

interface DisciplineSummary {
  total_reps: number;
  current_streak: number;
  longest_streak_this_month: number;
  missed_days: number;
  total_fines_paise: number;
}

interface ReportHeader {
  date_range?: string;
  month_label?: string;
  start_date: string;
  end_date: string;
  user_name: string;
}

interface ReportData {
  type: string;
  header: ReportHeader;
  top_stats: TopStats;
  nutrition_summary: NutritionRow[];
  daily_trends: DailyTrend[];
  pushup_log: PushupEntry[];
  most_logged_foods: FoodEntry[];
  progress_summary: ProgressSummary;
  weekly_breakdown?: WeekBucket[];
  discipline_summary?: DisciplineSummary;
  insight: string;
  footer: string;
}

// ---------- helpers ----------

function formatDate(dateStr: string): string {
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  const d = new Date(dateStr + "T00:00:00Z");
  return `${months[d.getUTCMonth()]} ${d.getUTCDate()}`;
}

function dayLabel(dateStr: string): string {
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const d = new Date(dateStr + "T00:00:00Z");
  return days[d.getUTCDay()];
}

// ---------- HTML email template ----------

function buildHtmlEmail(report: ReportData): string {
  const isWeekly = report.type === "weekly";
  const title = isWeekly ? "Weekly Health Report" : "Monthly Health Report";
  const dateLabel = report.header.date_range ?? report.header.month_label ?? "";

  // Top stats section
  const pushupDaysLabel = report.top_stats.pushup_days
    ? `${report.top_stats.pushup_days.value}/${report.top_stats.pushup_days.total}`
    : `${report.top_stats.current_streak ?? 0} day streak`;

  const topStatsHtml = `
    <table width="100%" cellpadding="0" cellspacing="0" style="margin:16px 0;">
      <tr>
        <td align="center" style="padding:8px;">
          <div style="font-size:24px;font-weight:bold;color:#1B5E20;">${pushupDaysLabel}</div>
          <div style="font-size:12px;color:#666;">Push-up Days</div>
        </td>
        <td align="center" style="padding:8px;">
          <div style="font-size:24px;font-weight:bold;color:#1B5E20;">${report.top_stats.total_reps}</div>
          <div style="font-size:12px;color:#666;">Total Reps</div>
        </td>
        <td align="center" style="padding:8px;">
          <div style="font-size:24px;font-weight:bold;color:#1B5E20;">${report.top_stats.avg_calories_per_day}</div>
          <div style="font-size:12px;color:#666;">Avg kcal/day</div>
        </td>
        <td align="center" style="padding:8px;">
          <div style="font-size:24px;font-weight:bold;color:#1B5E20;">${report.top_stats.avg_protein_per_day}g</div>
          <div style="font-size:12px;color:#666;">Avg Protein/day</div>
        </td>
      </tr>
    </table>`;

  // Nutrition summary table
  let nutritionHtml = `
    <table width="100%" cellpadding="8" cellspacing="0" style="border-collapse:collapse;margin:12px 0;">
      <tr style="background:#1B5E20;color:#fff;">
        <th align="left" style="padding:8px;border:1px solid #ddd;">Metric</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Daily Avg</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Target</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Status</th>
      </tr>`;
  for (let i = 0; i < report.nutrition_summary.length; i++) {
    const row = report.nutrition_summary[i];
    const bgColor = i % 2 === 0 ? "#f9f9f9" : "#ffffff";
    const statusIcon = row.status === "on_track" ? "&#9989;" : row.status === "below_target" ? "&#9888;&#65039;" : "&#8212;";
    nutritionHtml += `
      <tr style="background:${bgColor};">
        <td style="padding:8px;border:1px solid #eee;">${row.metric}</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${row.daily_average}</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${row.target ?? "-"}</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${statusIcon}</td>
      </tr>`;
  }
  nutritionHtml += "</table>";

  // Push-up log table
  let pushupHtml = `
    <table width="100%" cellpadding="8" cellspacing="0" style="border-collapse:collapse;margin:12px 0;">
      <tr style="background:#1B5E20;color:#fff;">
        <th align="left" style="padding:8px;border:1px solid #ddd;">Day</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Status</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Reps</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Fine</th>
      </tr>`;
  for (let i = 0; i < report.pushup_log.length; i++) {
    const entry = report.pushup_log[i];
    const bgColor = i % 2 === 0 ? "#f9f9f9" : "#ffffff";
    const statusText = entry.completed ? "&#9989; Done" : "&#10060; Missed";
    const fineText = entry.fine_amount_paise > 0 ? `Rs ${(entry.fine_amount_paise / 100).toFixed(0)}` : "-";
    pushupHtml += `
      <tr style="background:${bgColor};">
        <td style="padding:8px;border:1px solid #eee;">${dayLabel(entry.date)} ${formatDate(entry.date)}</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${statusText}</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${entry.reps}</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${fineText}</td>
      </tr>`;
  }
  pushupHtml += "</table>";

  // Most logged foods
  let foodsHtml = "";
  if (report.most_logged_foods.length > 0) {
    foodsHtml = `
    <h3 style="color:#1B5E20;margin:16px 0 8px 0;">Most Logged Foods</h3>
    <table width="100%" cellpadding="8" cellspacing="0" style="border-collapse:collapse;margin:12px 0;">
      <tr style="background:#1B5E20;color:#fff;">
        <th align="left" style="padding:8px;border:1px solid #ddd;">Food</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Times Logged</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Avg kcal</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Avg Protein</th>
      </tr>`;
    for (let i = 0; i < report.most_logged_foods.length; i++) {
      const food = report.most_logged_foods[i];
      const bgColor = i % 2 === 0 ? "#f9f9f9" : "#ffffff";
      const displayName = food.name.charAt(0).toUpperCase() + food.name.slice(1);
      foodsHtml += `
      <tr style="background:${bgColor};">
        <td style="padding:8px;border:1px solid #eee;">${displayName}</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${food.frequency}</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${food.calories}</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${food.protein}g</td>
      </tr>`;
    }
    foodsHtml += "</table>";
  }

  // Progress summary
  const progress = report.progress_summary;
  let progressHtml = `<h3 style="color:#1B5E20;margin:16px 0 8px 0;">Progress Summary</h3><table width="100%" cellpadding="8" cellspacing="0" style="border-collapse:collapse;margin:12px 0;">`;
  if (progress.starting_weight != null) {
    progressHtml += `<tr><td style="padding:6px 8px;color:#666;">Starting Weight</td><td style="padding:6px 8px;font-weight:bold;">${progress.starting_weight} kg</td></tr>`;
  }
  if (progress.current_weight != null) {
    progressHtml += `<tr><td style="padding:6px 8px;color:#666;">Current Weight</td><td style="padding:6px 8px;font-weight:bold;">${progress.current_weight} kg</td></tr>`;
  }
  if (progress.weight_change != null) {
    const sign = progress.weight_change >= 0 ? "+" : "";
    progressHtml += `<tr><td style="padding:6px 8px;color:#666;">Change</td><td style="padding:6px 8px;font-weight:bold;">${sign}${progress.weight_change} kg</td></tr>`;
  }
  if (progress.current_streak != null) {
    progressHtml += `<tr><td style="padding:6px 8px;color:#666;">Current Streak</td><td style="padding:6px 8px;font-weight:bold;">${progress.current_streak} days</td></tr>`;
  }
  if (progress.longest_streak != null) {
    progressHtml += `<tr><td style="padding:6px 8px;color:#666;">Longest Streak</td><td style="padding:6px 8px;font-weight:bold;">${progress.longest_streak} days</td></tr>`;
  }
  progressHtml += "</table>";

  // Weekly breakdown (monthly only)
  let weeklyHtml = "";
  if (!isWeekly && report.weekly_breakdown && report.weekly_breakdown.length > 0) {
    weeklyHtml = `
    <h3 style="color:#1B5E20;margin:16px 0 8px 0;">Weekly Breakdown</h3>
    <table width="100%" cellpadding="8" cellspacing="0" style="border-collapse:collapse;margin:12px 0;">
      <tr style="background:#1B5E20;color:#fff;">
        <th align="left" style="padding:8px;border:1px solid #ddd;">Week</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Avg kcal</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Avg Protein</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Push-up Days</th>
        <th align="center" style="padding:8px;border:1px solid #ddd;">Avg Water</th>
      </tr>`;
    for (let i = 0; i < report.weekly_breakdown.length; i++) {
      const week = report.weekly_breakdown[i];
      const bgColor = i % 2 === 0 ? "#f9f9f9" : "#ffffff";
      weeklyHtml += `
      <tr style="background:${bgColor};">
        <td style="padding:8px;border:1px solid #eee;">${week.label}</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${week.avg_calories}</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${week.avg_protein}g</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${week.pushup_days}</td>
        <td align="center" style="padding:8px;border:1px solid #eee;">${week.avg_water_ml}ml</td>
      </tr>`;
    }
    weeklyHtml += "</table>";
  }

  // Discipline summary (monthly only)
  let disciplineHtml = "";
  if (!isWeekly && report.discipline_summary) {
    const ds = report.discipline_summary;
    disciplineHtml = `
    <h3 style="color:#1B5E20;margin:16px 0 8px 0;">Discipline Summary</h3>
    <table width="100%" cellpadding="8" cellspacing="0" style="border-collapse:collapse;margin:12px 0;">
      <tr><td style="padding:6px 8px;color:#666;">Total Reps</td><td style="padding:6px 8px;font-weight:bold;">${ds.total_reps}</td></tr>
      <tr><td style="padding:6px 8px;color:#666;">Current Streak</td><td style="padding:6px 8px;font-weight:bold;">${ds.current_streak} days</td></tr>
      <tr><td style="padding:6px 8px;color:#666;">Longest Streak This Month</td><td style="padding:6px 8px;font-weight:bold;">${ds.longest_streak_this_month} days</td></tr>
      <tr><td style="padding:6px 8px;color:#666;">Missed Days</td><td style="padding:6px 8px;font-weight:bold;">${ds.missed_days}</td></tr>
      <tr><td style="padding:6px 8px;color:#666;">Total Fines</td><td style="padding:6px 8px;font-weight:bold;">Rs ${(ds.total_fines_paise / 100).toFixed(0)}</td></tr>
    </table>`;
  }

  // AI insight
  const insightHtml = report.insight
    ? `<div style="background:#E8F5E9;border-left:4px solid #1B5E20;padding:12px 16px;margin:16px 0;border-radius:4px;">
        <strong style="color:#1B5E20;">AI Insight</strong>
        <p style="margin:8px 0 0 0;color:#333;">${report.insight}</p>
      </div>`
    : "";

  // Full email
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
</head>
<body style="margin:0;padding:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f5f5;padding:20px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background:#1B5E20;padding:24px;text-align:center;">
              <h1 style="margin:0;color:#ffffff;font-size:24px;letter-spacing:1px;">REPGATE</h1>
              <p style="margin:4px 0 0 0;color:#C8E6C9;font-size:14px;">${title}</p>
            </td>
          </tr>

          <!-- Date range -->
          <tr>
            <td style="padding:16px 24px 0 24px;text-align:center;">
              <p style="margin:0;font-size:16px;color:#333;font-weight:500;">${dateLabel}</p>
              <p style="margin:4px 0 0 0;font-size:13px;color:#888;">Hello ${report.header.user_name}! Here is your ${report.type} report.</p>
            </td>
          </tr>

          <!-- Top Stats -->
          <tr>
            <td style="padding:8px 24px;">
              ${topStatsHtml}
            </td>
          </tr>

          <!-- Nutrition Summary -->
          <tr>
            <td style="padding:0 24px;">
              <h3 style="color:#1B5E20;margin:16px 0 8px 0;">Nutrition Summary</h3>
              ${nutritionHtml}
            </td>
          </tr>

          <!-- Push-up Log -->
          <tr>
            <td style="padding:0 24px;">
              <h3 style="color:#1B5E20;margin:16px 0 8px 0;">Push-up Discipline Log</h3>
              ${pushupHtml}
            </td>
          </tr>

          <!-- Most Logged Foods -->
          <tr>
            <td style="padding:0 24px;">
              ${foodsHtml}
            </td>
          </tr>

          <!-- Progress Summary -->
          <tr>
            <td style="padding:0 24px;">
              ${progressHtml}
            </td>
          </tr>

          <!-- Weekly Breakdown (monthly only) -->
          <tr>
            <td style="padding:0 24px;">
              ${weeklyHtml}
            </td>
          </tr>

          <!-- Discipline Summary (monthly only) -->
          <tr>
            <td style="padding:0 24px;">
              ${disciplineHtml}
            </td>
          </tr>

          <!-- AI Insight -->
          <tr>
            <td style="padding:0 24px;">
              ${insightHtml}
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:16px 24px 24px 24px;border-top:1px solid #eee;margin-top:16px;">
              <p style="margin:0;font-size:11px;color:#999;text-align:center;">${report.footer}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

// ---------- email sending via Resend ----------

async function sendEmail(to: string, subject: string, html: string): Promise<void> {
  const apiKey = Deno.env.get("RESEND_API_KEY") ?? "";
  if (!apiKey) {
    throw new FunctionError(500, "Email service is not configured.");
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "RepGate <reports@repgate.app>",
      to: [to],
      subject,
      html,
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    console.error(`[send-health-report-email] Resend error ${response.status}: ${errorBody.slice(0, 300)}`);
    throw new FunctionError(500, "Failed to send email. Please try again later.");
  }
}

// ---------- generate report by calling the existing function ----------

async function fetchReportData(type: string, token: string): Promise<ReportData> {
  const url = `${supabaseUrl}/functions/v1/generate-health-report`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ type }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    console.error(`[send-health-report-email] report fetch error ${response.status}: ${errorBody.slice(0, 300)}`);
    throw new FunctionError(500, "Could not generate report data for email.");
  }

  return await response.json() as ReportData;
}

// ---------- entry point ----------

Deno.serve((req) =>
  invoke("send-health-report-email", req, async (request) => {
    const { user, token } = await requireUser(request);
    const input = await body(request);

    const type = String(input.type ?? "").trim();
    if (type !== "weekly" && type !== "monthly") {
      throw new FunctionError(400, "type must be 'weekly' or 'monthly'.");
    }

    // Resolve recipient email
    let email = typeof input.email === "string" ? input.email.trim() : "";
    if (!email) {
      // Look up email from Supabase Auth
      const { data: authUser, error: authError } = await adminClient.auth.admin.getUserById(user.id);
      if (authError || !authUser?.user?.email) {
        throw new FunctionError(400, "Could not determine your email address. Please provide one.");
      }
      email = authUser.user.email;
    }

    // Generate the report
    const reportData = await fetchReportData(type, token);

    // Build email subject
    const dateLabel = reportData.header.date_range ?? reportData.header.month_label ?? "";
    const subject = `Your ${type === "weekly" ? "Weekly" : "Monthly"} Health Report${dateLabel ? ` - ${dateLabel}` : ""}`;

    // Build HTML and send
    const html = buildHtmlEmail(reportData);
    await sendEmail(email, subject, html);

    return { success: true, email };
  })
);
