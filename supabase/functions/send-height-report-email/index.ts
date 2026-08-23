import {
  adminClient,
  body,
  FunctionError,
  invoke,
  requireUser,
  round,
} from "../_shared/common.ts";

// @deno-types="https://esm.sh/jspdf@2.5.2"
import { jsPDF } from "https://esm.sh/jspdf@2.5.2";

/**
 * send-height-report-email -- generates a height measurement report PDF and
 * emails it to the user via the Resend API.
 *
 * Request body: {
 *   measurements: Array<{ method, value_cm, timestamp, reference_object_type? }>,
 *   median: number,
 *   average: number,
 *   is_accuracy_mode: boolean
 * }
 * Returns: { success: true, email: "<recipient>" }
 */

// ---------- types ----------

interface HeightMeasurement {
  method: string;
  value_cm: number;
  timestamp: string;
  reference_object_type?: string | null;
}

// ---------- helpers ----------

function methodLabel(method: string): string {
  switch (method) {
    case "pose":
      return "Pose Detection";
    case "pose_reference":
      return "Pose + Reference Object";
    case "arcore":
      return "ARCore";
    case "lidar":
      return "LiDAR/ToF";
    default:
      return method.charAt(0).toUpperCase() + method.slice(1);
  }
}

function formatTimestamp(ts: string): string {
  const d = new Date(ts);
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  const day = d.getDate();
  const month = months[d.getMonth()];
  const year = d.getFullYear();
  const hours = d.getHours().toString().padStart(2, "0");
  const mins = d.getMinutes().toString().padStart(2, "0");
  return `${month} ${day}, ${year} at ${hours}:${mins}`;
}

function formatDateOnly(d: Date): string {
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
}

// ---------- PDF generation using jsPDF ----------

function buildHeightReportPdf(
  userName: string,
  measurements: HeightMeasurement[],
  median: number,
  average: number,
  isAccuracyMode: boolean,
): string {
  const doc = new jsPDF({ orientation: "portrait", unit: "mm", format: "a4" });
  const pageWidth = doc.internal.pageSize.getWidth();
  const margin = 14;
  const contentWidth = pageWidth - margin * 2;
  let y = 14;

  function ensureSpace(needed: number) {
    const pageHeight = doc.internal.pageSize.getHeight();
    if (y + needed > pageHeight - 15) {
      doc.addPage();
      y = 14;
    }
  }

  // ----- Header (green banner) -----
  doc.setFillColor(27, 94, 32); // #1B5E20
  doc.rect(0, 0, pageWidth, 28, "F");
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(20);
  doc.setFont("helvetica", "bold");
  doc.text("REPGATE", pageWidth / 2, 12, { align: "center" });
  doc.setFontSize(11);
  doc.setFont("helvetica", "normal");
  doc.text("Height Measurement Report", pageWidth / 2, 19, { align: "center" });
  doc.setFontSize(9);
  doc.text(formatDateOnly(new Date()), pageWidth / 2, 25, { align: "center" });

  y = 36;
  doc.setTextColor(0, 0, 0);

  // ----- User name -----
  doc.setFontSize(12);
  doc.setFont("helvetica", "bold");
  doc.text(`Hello ${userName}!`, margin, y);
  y += 8;

  // ----- Mode indicator -----
  doc.setFontSize(10);
  doc.setFont("helvetica", "normal");
  doc.setTextColor(100, 100, 100);
  const modeText = isAccuracyMode
    ? "Mode: Accuracy (multiple measurements)"
    : "Mode: Single Measurement";
  doc.text(modeText, margin, y);
  y += 8;
  doc.setTextColor(0, 0, 0);

  // ----- Final Height (prominent display) -----
  ensureSpace(24);
  doc.setFillColor(232, 245, 233); // light green bg
  doc.rect(margin, y - 4, contentWidth, 20, "F");
  doc.setFontSize(10);
  doc.setFont("helvetica", "normal");
  doc.setTextColor(27, 94, 32);
  doc.text("Final Determined Height", pageWidth / 2, y + 2, { align: "center" });
  doc.setFontSize(18);
  doc.setFont("helvetica", "bold");
  const finalHeight = isAccuracyMode ? median : measurements[0]?.value_cm ?? 0;
  doc.text(`${round(finalHeight)} cm`, pageWidth / 2, y + 12, { align: "center" });
  y += 22;
  doc.setTextColor(0, 0, 0);

  // ----- Accuracy mode: Median and Average -----
  if (isAccuracyMode) {
    ensureSpace(20);
    y += 4;
    doc.setFontSize(11);
    doc.setFont("helvetica", "bold");
    doc.text("Statistical Summary", margin, y);
    y += 6;

    doc.setFontSize(9);
    doc.setFont("helvetica", "normal");
    const summaryRows: [string, string][] = [
      ["Median Height", `${round(median)} cm`],
      ["Average Height", `${round(average)} cm`],
      ["Number of Readings", String(measurements.length)],
    ];

    for (const [label, val] of summaryRows) {
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

  // ----- Individual Readings Table -----
  ensureSpace(10 + measurements.length * 7);
  doc.setFontSize(11);
  doc.setFont("helvetica", "bold");
  doc.setTextColor(0, 0, 0);
  doc.text(
    isAccuracyMode ? "Individual Readings" : "Measurement Details",
    margin,
    y,
  );
  y += 5;

  // Table header
  doc.setFillColor(27, 94, 32);
  doc.rect(margin, y, contentWidth, 6, "F");
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(8);
  doc.setFont("helvetica", "bold");
  const cols = [margin + 2, margin + 20, margin + 60, margin + 110];
  doc.text("#", cols[0], y + 4);
  doc.text("Method", cols[1], y + 4);
  doc.text("Height (cm)", cols[2], y + 4);
  doc.text("Timestamp", cols[3], y + 4);
  y += 7;

  doc.setTextColor(0, 0, 0);
  doc.setFont("helvetica", "normal");
  for (let i = 0; i < measurements.length; i++) {
    ensureSpace(7);
    const m = measurements[i];
    if (i % 2 === 0) {
      doc.setFillColor(245, 245, 245);
      doc.rect(margin, y - 3.5, contentWidth, 6, "F");
    }
    doc.setFontSize(8);
    doc.text(String(i + 1), cols[0], y);
    doc.text(methodLabel(m.method), cols[1], y);
    doc.text(String(round(m.value_cm)), cols[2], y);
    doc.text(formatTimestamp(m.timestamp), cols[3], y);
    y += 6;
  }
  y += 4;

  // ----- Reference object info (if available) -----
  const refType = measurements[0]?.reference_object_type;
  if (refType) {
    ensureSpace(12);
    doc.setFontSize(9);
    doc.setFont("helvetica", "normal");
    doc.setTextColor(100, 100, 100);
    const refLabel = refType === "a4_paper"
      ? "A4 Paper"
      : refType === "credit_card"
      ? "Credit Card"
      : refType;
    doc.text(`Reference Object Used: ${refLabel}`, margin, y);
    y += 8;
    doc.setTextColor(0, 0, 0);
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
  const footer = "Generated by RepGate. Measurements are estimates and should not replace professional medical assessments.";
  const footerLines = doc.splitTextToSize(footer, contentWidth);
  doc.text(footerLines, pageWidth / 2, y, { align: "center" });

  // Return as base64 string
  return doc.output("datauristring").split(",")[1];
}

// ---------- short email HTML body ----------

function buildEmailHtml(userName: string, heightCm: number, isAccuracyMode: boolean): string {
  const modeNote = isAccuracyMode
    ? "Multiple measurements were taken for accuracy. The median value has been used as your final height."
    : "A single measurement was recorded.";

  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;padding:24px;color:#333;">
  <p>Hi <strong>${userName}</strong>,</p>
  <p>Your height measurement report is ready! Please find it attached as a PDF.</p>
  <p><strong>Determined Height:</strong> ${round(heightCm)} cm</p>
  <p style="color:#666;font-size:13px;">${modeNote}</p>
  <p>Keep tracking your progress! 💪</p>
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
    console.error(`[send-height-report-email] Resend error ${response.status}: ${errorBody.slice(0, 300)}`);
    throw new FunctionError(500, "Failed to send email. Please try again later.");
  }
}

// ---------- entry point ----------

Deno.serve((req) =>
  invoke("send-height-report-email", req, async (request) => {
    const { user } = await requireUser(request);
    const input = await body(request);

    // Validate measurements array
    const rawMeasurements = input.measurements;
    if (!Array.isArray(rawMeasurements) || rawMeasurements.length === 0) {
      throw new FunctionError(400, "measurements array is required and must not be empty.");
    }

    const measurements: HeightMeasurement[] = rawMeasurements.map((m: unknown) => {
      const item = m as Record<string, unknown>;
      return {
        method: String(item.method ?? "pose"),
        value_cm: Number(item.value_cm ?? 0),
        timestamp: String(item.timestamp ?? new Date().toISOString()),
        reference_object_type: item.reference_object_type ? String(item.reference_object_type) : null,
      };
    });

    // Validate that all height values are within sane bounds (50-250 cm)
    for (const m of measurements) {
      if (!Number.isFinite(m.value_cm) || m.value_cm < 50 || m.value_cm > 250) {
        throw new FunctionError(
          400,
          `Invalid height value: ${m.value_cm} cm. Must be between 50 and 250 cm.`,
        );
      }
    }

    const median = Number(input.median ?? 0);
    const average = Number(input.average ?? 0);
    const isAccuracyMode = Boolean(input.is_accuracy_mode);

    // Validate median and average are within sane bounds
    if (median !== 0 && (!Number.isFinite(median) || median < 50 || median > 250)) {
      throw new FunctionError(
        400,
        `Invalid median value: ${median} cm. Must be between 50 and 250 cm.`,
      );
    }
    if (average !== 0 && (!Number.isFinite(average) || average < 50 || average > 250)) {
      throw new FunctionError(
        400,
        `Invalid average value: ${average} cm. Must be between 50 and 250 cm.`,
      );
    }

    // Get user details (name and email)
    const { data: userData, error: userError } = await adminClient
      .from("users")
      .select("name, email")
      .eq("id", user.id)
      .single();

    if (userError || !userData) {
      throw new FunctionError(500, "Could not retrieve user details.");
    }

    // Resolve email - prefer from users table, fallback to auth
    let email = userData.email as string | null;
    if (!email) {
      const { data: authUser, error: authError } = await adminClient.auth.admin.getUserById(user.id);
      if (authError || !authUser?.user?.email) {
        throw new FunctionError(400, "Could not determine your email address.");
      }
      email = authUser.user.email;
    }

    const userName = (userData.name as string) || "there";

    // Build PDF
    const pdfBase64 = buildHeightReportPdf(
      userName,
      measurements,
      median,
      average,
      isAccuracyMode,
    );

    // Determine final height for email body
    const finalHeight = isAccuracyMode ? median : measurements[0].value_cm;

    // Build and send email
    const subject = "Your Height Measurement Report";
    const html = buildEmailHtml(userName, finalHeight, isAccuracyMode);
    const filename = "RepGate-Height-Measurement-Report.pdf";
    await sendEmailWithAttachment(email, subject, html, pdfBase64, filename);

    return { success: true, email };
  })
);
