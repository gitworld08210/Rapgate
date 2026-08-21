import {
  adminClient,
  body,
  FunctionError,
  invoke,
  requireUser,
  supabaseUrl,
} from "../_shared/common.ts";

// @deno-types="https://esm.sh/jspdf@2.5.2"
import { jsPDF } from "https://esm.sh/jspdf@2.5.2";

/** Timeout (ms) for the internal report generation call. */
const REPORT_FETCH_TIMEOUT_MS = 30_000;

/**
 * send-health-report-email -- generates a health report for the user, builds
 * a PDF attachment from the data, and sends a SHORT email with the PDF
 * attached via the Resend API.
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

// ---------- PDF generation using jsPDF ----------

function buildReportPdf(report: ReportData): string {
  const doc = new jsPDF({ orientation: "portrait", unit: "mm", format: "a4" });
  const pageWidth = doc.internal.pageSize.getWidth();
  const margin = 14;
  const contentWidth = pageWidth - margin * 2;
  let y = 14;

  const isWeekly = report.type === "weekly";
  const title = isWeekly ? "Weekly Health Report" : "Monthly Health Report";
  const dateLabel = report.header.date_range ?? report.header.month_label ?? "";

  // Helper: check if we need a new page
  function ensureSpace(needed: number) {
    const pageHeight = doc.internal.pageSize.getHeight();
    if (y + needed > pageHeight - 15) {
      doc.addPage();
      y = 14;
    }
  }

  // ----- Header -----
  doc.setFillColor(27, 94, 32); // #1B5E20
  doc.rect(0, 0, pageWidth, 28, "F");
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(20);
  doc.setFont("helvetica", "bold");
  doc.text("REPGATE", pageWidth / 2, 12, { align: "center" });
  doc.setFontSize(11);
  doc.setFont("helvetica", "normal");
  doc.text(title, pageWidth / 2, 19, { align: "center" });
  doc.setFontSize(9);
  doc.text(dateLabel, pageWidth / 2, 25, { align: "center" });

  y = 36;
  doc.setTextColor(0, 0, 0);

  // ----- User name -----
  doc.setFontSize(12);
  doc.setFont("helvetica", "bold");
  doc.text(`Hello ${report.header.user_name}!`, margin, y);
  y += 8;

  // ----- Top Stats -----
  ensureSpace(20);
  doc.setFillColor(232, 245, 233); // light green bg
  doc.rect(margin, y - 4, contentWidth, 16, "F");
  doc.setFontSize(10);
  doc.setFont("helvetica", "bold");
  doc.setTextColor(27, 94, 32);

  const pushupDaysLabel = report.top_stats.pushup_days
    ? `${report.top_stats.pushup_days.value}/${report.top_stats.pushup_days.total}`
    : `${report.top_stats.current_streak ?? 0}`;

  const stats = [
    { label: "Push-up Days", value: pushupDaysLabel },
    { label: "Total Reps", value: String(report.top_stats.total_reps) },
    { label: "Avg kcal/day", value: String(report.top_stats.avg_calories_per_day) },
    { label: "Avg Protein/day", value: `${report.top_stats.avg_protein_per_day}g` },
  ];

  const colWidth = contentWidth / 4;
  for (let i = 0; i < stats.length; i++) {
    const cx = margin + colWidth * i + colWidth / 2;
    doc.setFontSize(13);
    doc.setFont("helvetica", "bold");
    doc.text(stats[i].value, cx, y + 3, { align: "center" });
    doc.setFontSize(7);
    doc.setFont("helvetica", "normal");
    doc.text(stats[i].label, cx, y + 9, { align: "center" });
  }
  y += 18;
  doc.setTextColor(0, 0, 0);

  // ----- Nutrition Summary Table -----
  ensureSpace(10 + report.nutrition_summary.length * 7);
  doc.setFontSize(11);
  doc.setFont("helvetica", "bold");
  doc.text("Nutrition Summary", margin, y);
  y += 5;

  // Table header
  doc.setFillColor(27, 94, 32);
  doc.rect(margin, y, contentWidth, 6, "F");
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(8);
  doc.setFont("helvetica", "bold");
  const nCols = [margin + 2, margin + 55, margin + 90, margin + 125];
  doc.text("Metric", nCols[0], y + 4);
  doc.text("Daily Avg", nCols[1], y + 4);
  doc.text("Target", nCols[2], y + 4);
  doc.text("Status", nCols[3], y + 4);
  y += 7;

  doc.setTextColor(0, 0, 0);
  doc.setFont("helvetica", "normal");
  for (let i = 0; i < report.nutrition_summary.length; i++) {
    ensureSpace(7);
    const row = report.nutrition_summary[i];
    if (i % 2 === 0) {
      doc.setFillColor(245, 245, 245);
      doc.rect(margin, y - 3.5, contentWidth, 6, "F");
    }
    doc.setFontSize(8);
    doc.text(row.metric, nCols[0], y);
    doc.text(String(row.daily_average), nCols[1], y);
    doc.text(row.target != null ? String(row.target) : "-", nCols[2], y);
    const statusText = row.status === "on_track" ? "On Track" : row.status === "below_target" ? "Below Target" : row.status;
    doc.text(statusText, nCols[3], y);
    y += 6;
  }
  y += 4;

  // ----- Push-up Discipline Log -----
  ensureSpace(10 + report.pushup_log.length * 7);
  doc.setFontSize(11);
  doc.setFont("helvetica", "bold");
  doc.text("Push-up Discipline Log", margin, y);
  y += 5;

  doc.setFillColor(27, 94, 32);
  doc.rect(margin, y, contentWidth, 6, "F");
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(8);
  doc.setFont("helvetica", "bold");
  const pCols = [margin + 2, margin + 45, margin + 85, margin + 125];
  doc.text("Day", pCols[0], y + 4);
  doc.text("Status", pCols[1], y + 4);
  doc.text("Reps", pCols[2], y + 4);
  doc.text("Fine", pCols[3], y + 4);
  y += 7;

  doc.setTextColor(0, 0, 0);
  doc.setFont("helvetica", "normal");
  for (let i = 0; i < report.pushup_log.length; i++) {
    ensureSpace(7);
    const entry = report.pushup_log[i];
    if (i % 2 === 0) {
      doc.setFillColor(245, 245, 245);
      doc.rect(margin, y - 3.5, contentWidth, 6, "F");
    }
    doc.setFontSize(8);
    doc.text(`${dayLabel(entry.date)} ${formatDate(entry.date)}`, pCols[0], y);
    doc.text(entry.completed ? "Done" : "Missed", pCols[1], y);
    doc.text(String(entry.reps), pCols[2], y);
    const fineText = entry.fine_amount_paise > 0 ? `Rs ${(entry.fine_amount_paise / 100).toFixed(0)}` : "-";
    doc.text(fineText, pCols[3], y);
    y += 6;
  }
  y += 4;

  // ----- Most Logged Foods -----
  if (report.most_logged_foods.length > 0) {
    ensureSpace(10 + report.most_logged_foods.length * 7);
    doc.setFontSize(11);
    doc.setFont("helvetica", "bold");
    doc.text("Most Logged Foods", margin, y);
    y += 5;

    doc.setFillColor(27, 94, 32);
    doc.rect(margin, y, contentWidth, 6, "F");
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(8);
    doc.setFont("helvetica", "bold");
    const fCols = [margin + 2, margin + 55, margin + 90, margin + 125];
    doc.text("Food", fCols[0], y + 4);
    doc.text("Times Logged", fCols[1], y + 4);
    doc.text("Avg kcal", fCols[2], y + 4);
    doc.text("Avg Protein", fCols[3], y + 4);
    y += 7;

    doc.setTextColor(0, 0, 0);
    doc.setFont("helvetica", "normal");
    for (let i = 0; i < report.most_logged_foods.length; i++) {
      ensureSpace(7);
      const food = report.most_logged_foods[i];
      if (i % 2 === 0) {
        doc.setFillColor(245, 245, 245);
        doc.rect(margin, y - 3.5, contentWidth, 6, "F");
      }
      doc.setFontSize(8);
      const displayName = food.name.charAt(0).toUpperCase() + food.name.slice(1);
      doc.text(displayName, fCols[0], y);
      doc.text(String(food.frequency), fCols[1], y);
      doc.text(String(food.calories), fCols[2], y);
      doc.text(`${food.protein}g`, fCols[3], y);
      y += 6;
    }
    y += 4;
  }

  // ----- Progress Summary -----
  const progress = report.progress_summary;
  const progressRows: [string, string][] = [];
  if (progress.starting_weight != null) progressRows.push(["Starting Weight", `${progress.starting_weight} kg`]);
  if (progress.current_weight != null) progressRows.push(["Current Weight", `${progress.current_weight} kg`]);
  if (progress.weight_change != null) {
    const sign = progress.weight_change >= 0 ? "+" : "";
    progressRows.push(["Change", `${sign}${progress.weight_change} kg`]);
  }
  if (progress.current_streak != null) progressRows.push(["Current Streak", `${progress.current_streak} days`]);
  if (progress.longest_streak != null) progressRows.push(["Longest Streak", `${progress.longest_streak} days`]);

  if (progressRows.length > 0) {
    ensureSpace(10 + progressRows.length * 6);
    doc.setFontSize(11);
    doc.setFont("helvetica", "bold");
    doc.text("Progress Summary", margin, y);
    y += 6;

    doc.setFont("helvetica", "normal");
    doc.setFontSize(9);
    for (const [label, val] of progressRows) {
      ensureSpace(6);
      doc.setTextColor(100, 100, 100);
      doc.text(label, margin + 2, y);
      doc.setTextColor(0, 0, 0);
      doc.setFont("helvetica", "bold");
      doc.text(val, margin + 60, y);
      doc.setFont("helvetica", "normal");
      y += 6;
    }
    y += 4;
  }

  // ----- Weekly Breakdown (monthly only) -----
  if (!isWeekly && report.weekly_breakdown && report.weekly_breakdown.length > 0) {
    ensureSpace(10 + report.weekly_breakdown.length * 7);
    doc.setFontSize(11);
    doc.setFont("helvetica", "bold");
    doc.setTextColor(0, 0, 0);
    doc.text("Weekly Breakdown", margin, y);
    y += 5;

    doc.setFillColor(27, 94, 32);
    doc.rect(margin, y, contentWidth, 6, "F");
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(7);
    doc.setFont("helvetica", "bold");
    const wCols = [margin + 2, margin + 35, margin + 65, margin + 95, margin + 130];
    doc.text("Week", wCols[0], y + 4);
    doc.text("Avg kcal", wCols[1], y + 4);
    doc.text("Avg Protein", wCols[2], y + 4);
    doc.text("Push-up Days", wCols[3], y + 4);
    doc.text("Avg Water", wCols[4], y + 4);
    y += 7;

    doc.setTextColor(0, 0, 0);
    doc.setFont("helvetica", "normal");
    for (let i = 0; i < report.weekly_breakdown.length; i++) {
      ensureSpace(7);
      const week = report.weekly_breakdown[i];
      if (i % 2 === 0) {
        doc.setFillColor(245, 245, 245);
        doc.rect(margin, y - 3.5, contentWidth, 6, "F");
      }
      doc.setFontSize(8);
      doc.text(week.label, wCols[0], y);
      doc.text(String(week.avg_calories), wCols[1], y);
      doc.text(`${week.avg_protein}g`, wCols[2], y);
      doc.text(String(week.pushup_days), wCols[3], y);
      doc.text(`${week.avg_water_ml}ml`, wCols[4], y);
      y += 6;
    }
    y += 4;
  }

  // ----- Discipline Summary (monthly only) -----
  if (!isWeekly && report.discipline_summary) {
    const ds = report.discipline_summary;
    ensureSpace(40);
    doc.setFontSize(11);
    doc.setFont("helvetica", "bold");
    doc.setTextColor(0, 0, 0);
    doc.text("Discipline Summary", margin, y);
    y += 6;

    const dsRows: [string, string][] = [
      ["Total Reps", String(ds.total_reps)],
      ["Current Streak", `${ds.current_streak} days`],
      ["Longest Streak This Month", `${ds.longest_streak_this_month} days`],
      ["Missed Days", String(ds.missed_days)],
      ["Total Fines", `Rs ${(ds.total_fines_paise / 100).toFixed(0)}`],
    ];

    doc.setFont("helvetica", "normal");
    doc.setFontSize(9);
    for (const [label, val] of dsRows) {
      doc.setTextColor(100, 100, 100);
      doc.text(label, margin + 2, y);
      doc.setTextColor(0, 0, 0);
      doc.setFont("helvetica", "bold");
      doc.text(val, margin + 70, y);
      doc.setFont("helvetica", "normal");
      y += 6;
    }
    y += 4;
  }

  // ----- AI Insight -----
  if (report.insight) {
    ensureSpace(20);
    doc.setFillColor(232, 245, 233);
    doc.rect(margin, y - 2, contentWidth, 18, "F");
    doc.setFontSize(10);
    doc.setFont("helvetica", "bold");
    doc.setTextColor(27, 94, 32);
    doc.text("AI Insight", margin + 4, y + 3);
    doc.setFont("helvetica", "normal");
    doc.setFontSize(8);
    doc.setTextColor(51, 51, 51);
    const insightLines = doc.splitTextToSize(report.insight, contentWidth - 8);
    doc.text(insightLines, margin + 4, y + 9);
    y += 18 + Math.max(0, (insightLines.length - 2) * 4);
  }

  // ----- Footer -----
  ensureSpace(12);
  y += 4;
  doc.setDrawColor(200, 200, 200);
  doc.line(margin, y, pageWidth - margin, y);
  y += 5;
  doc.setFontSize(7);
  doc.setTextColor(150, 150, 150);
  doc.setFont("helvetica", "normal");
  const footerLines = doc.splitTextToSize(report.footer, contentWidth);
  doc.text(footerLines, pageWidth / 2, y, { align: "center" });

  // Return as base64 string
  return doc.output("datauristring").split(",")[1];
}

// ---------- short email HTML body ----------

function buildShortEmailHtml(userName: string, type: string): string {
  const reportType = type === "weekly" ? "weekly" : "monthly";
  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;padding:24px;color:#333;">
  <p>Hi <strong>${userName}</strong>,</p>
  <p>Your ${reportType} health report is ready! Please find it attached as a PDF.</p>
  <p>Keep pushing forward! 💪</p>
  <br>
  <p style="color:#888;font-size:12px;">- Team RepGate</p>
</body>
</html>`;
}

// ---------- email sending via Resend (with attachment) ----------

async function sendEmailWithAttachment(
  to: string,
  subject: string,
  html: string,
  pdfBase64: string,
  filename: string,
): Promise<void> {
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
      from: Deno.env.get("RESEND_FROM_EMAIL") ?? "RepGate <reports@repgate.app>",
      to: [to],
      subject,
      html,
      attachments: [
        {
          filename,
          content: pdfBase64,
        },
      ],
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    console.error(`[send-health-report-email] Resend error ${response.status}: ${errorBody.slice(0, 300)}`);
    throw new FunctionError(500, "Failed to send email. Please try again later.");
  }
}

// ---------- generate report by calling the existing function ----------

/**
 * Calls generate-health-report internally using the service-role key rather
 * than the user's short-lived JWT. This avoids the token-expiry race that
 * occurs when report generation (including a 20s Gemini call) outlasts the
 * remaining lifetime of the user's access token.
 */
async function fetchReportData(type: string, userId: string): Promise<ReportData> {
  const url = `${supabaseUrl}/functions/v1/generate-health-report`;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REPORT_FETCH_TIMEOUT_MS);

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ type, user_id: userId }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error(`[send-health-report-email] report fetch error ${response.status}: ${errorBody.slice(0, 300)}`);
      throw new FunctionError(500, "Could not generate report data for email.");
    }

    return await response.json() as ReportData;
  } catch (err) {
    if (err instanceof FunctionError) throw err;
    if (err instanceof DOMException && err.name === "AbortError") {
      console.error("[send-health-report-email] report generation timed out");
      throw new FunctionError(504, "Report generation timed out. Please try again later.");
    }
    console.error("[send-health-report-email] unexpected fetch error:", err);
    throw new FunctionError(500, "Could not generate report data for email.");
  } finally {
    clearTimeout(timeout);
  }
}

// ---------- entry point ----------

Deno.serve((req) =>
  invoke("send-health-report-email", req, async (request) => {
    const { user } = await requireUser(request);
    const input = await body(request);

    const type = String(input.type ?? "").trim();
    if (type !== "weekly" && type !== "monthly") {
      throw new FunctionError(400, "type must be 'weekly' or 'monthly'.");
    }

    // Resolve recipient email
    let email = typeof input.email === "string" ? input.email.trim() : "";
    if (!email) {
      const { data: authUser, error: authError } = await adminClient.auth.admin.getUserById(user.id);
      if (authError || !authUser?.user?.email) {
        throw new FunctionError(400, "Could not determine your email address. Please provide one.");
      }
      email = authUser.user.email;
    }

    // Generate the report using service-role key (avoids token-expiry race)
    const reportData = await fetchReportData(type, user.id);

    // Build PDF from report data
    const pdfBase64 = buildReportPdf(reportData);

    // Build email subject
    const dateLabel = reportData.header.date_range ?? reportData.header.month_label ?? "";
    const subject = `Your ${type === "weekly" ? "Weekly" : "Monthly"} Health Report${dateLabel ? ` - ${dateLabel}` : ""}`;

    // Build short email body and send with PDF attachment
    const html = buildShortEmailHtml(reportData.header.user_name, type);
    const filename = `RepGate-${type === "weekly" ? "Weekly" : "Monthly"}-Report.pdf`;
    await sendEmailWithAttachment(email, subject, html, pdfBase64, filename);

    return { success: true, email };
  })
);
