// send-email-otp
// ---------------
// Passwordless email OTP — STEP 1 of 2. Public (pre-auth) function.
//
// Generates a 6-digit code, stores only its SHA-256 hash in `email_otps`, and
// delivers the plaintext code via Azure Communication Services Email. The code
// is never logged and never returned in the response.
//
// Abuse controls:
//   * per-email rate limit (max sends per rolling window)
//   * short expiry (10 minutes)
//   * verify-email-otp enforces max attempts and single-use consumption
//
// Deploy with verify_jwt = false (there is no session yet).

import {
  adminClient,
  body,
  cors,
  FunctionError,
  json,
  requiredString,
} from "../_shared/common.ts";
import { isAzureEmailConfigured, sendAzureEmail } from "../_shared/azure_email.ts";

const CODE_TTL_MINUTES = 10;
const MAX_SENDS_PER_WINDOW = 5;
const WINDOW_MINUTES = 15;
const RESEND_COOLDOWN_SECONDS = 30;

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function normalizeEmail(raw: string): string {
  return raw.trim().toLowerCase();
}

function generateCode(): string {
  // Uniform 6-digit code (000000–999999) from a CSPRNG.
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  return String(buf[0] % 1_000_000).padStart(6, "0");
}

async function hashCode(email: string, code: string): Promise<string> {
  // Bind the hash to the email so a leaked hash for one address can't be
  // replayed against another.
  const data = new TextEncoder().encode(`${email}:${code}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function otpEmailHtml(code: string): string {
  return `<!doctype html><html><body style="margin:0;background:#0f1110;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
  <div style="max-width:480px;margin:0 auto;padding:32px 24px;">
    <div style="background:#1a1d1b;border-radius:24px;padding:32px;border:1px solid #2e332f;">
      <div style="font-size:22px;font-weight:800;color:#b5e048;letter-spacing:-0.4px;">RepGate</div>
      <h1 style="font-size:20px;color:#ffffff;margin:20px 0 8px;">Your sign-in code</h1>
      <p style="font-size:14px;color:#8e8e93;margin:0 0 24px;">Enter this code in the app to continue. It expires in ${CODE_TTL_MINUTES} minutes.</p>
      <div style="font-size:38px;font-weight:800;letter-spacing:10px;color:#ffffff;background:#222623;border-radius:16px;padding:18px;text-align:center;">${code}</div>
      <p style="font-size:12px;color:#8e8e93;margin:24px 0 0;">If you didn't request this, you can safely ignore this email — nobody can sign in without the code.</p>
    </div>
  </div></body></html>`;
}

Deno.serve(async (req) => {
  const preflight = cors(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  try {
    if (!isAzureEmailConfigured()) {
      throw new FunctionError(503, "Email delivery is not configured yet. Please try again later.");
    }

    const input = await body(req);
    const email = normalizeEmail(requiredString(input.email, "email"));
    if (!EMAIL_RE.test(email) || email.length > 254) {
      throw new FunctionError(400, "Enter a valid email address.");
    }

    const now = Date.now();

    // Rate limit: count recent sends for this email.
    const windowStart = new Date(now - WINDOW_MINUTES * 60_000).toISOString();
    const { data: recent, error: recentErr } = await adminClient
      .from("email_otps")
      .select("created_at")
      .eq("email", email)
      .gte("created_at", windowStart)
      .order("created_at", { ascending: false });
    if (recentErr) throw new FunctionError(500, "Could not process the request.");

    if ((recent?.length ?? 0) >= MAX_SENDS_PER_WINDOW) {
      throw new FunctionError(429, "Too many codes requested. Please wait a few minutes and try again.");
    }
    if (recent && recent.length > 0) {
      const lastSent = new Date(recent[0].created_at as string).getTime();
      if (now - lastSent < RESEND_COOLDOWN_SECONDS * 1000) {
        throw new FunctionError(429, `Please wait ${RESEND_COOLDOWN_SECONDS}s before requesting another code.`);
      }
    }

    const code = generateCode();
    const codeHash = await hashCode(email, code);
    const expiresAt = new Date(now + CODE_TTL_MINUTES * 60_000).toISOString();

    // Invalidate any still-valid prior codes for this email so only the newest
    // one works.
    await adminClient
      .from("email_otps")
      .update({ consumed_at: new Date().toISOString() })
      .eq("email", email)
      .is("consumed_at", null);

    const { error: insertErr } = await adminClient.from("email_otps").insert({
      email,
      code_hash: codeHash,
      purpose: "auth",
      expires_at: expiresAt,
    });
    if (insertErr) throw new FunctionError(500, "Could not create a sign-in code.");

    const result = await sendAzureEmail({
      to: email,
      subject: "Your RepGate sign-in code",
      html: otpEmailHtml(code),
      plainText: `Your RepGate sign-in code is ${code}. It expires in ${CODE_TTL_MINUTES} minutes.`,
    });

    if (!result.ok) {
      console.error("[send-email-otp] Azure send failed", result.status, result.error);
      throw new FunctionError(502, "We couldn't send your code right now. Please try again.");
    }

    // Best-effort cleanup of stale rows.
    adminClient.rpc("purge_expired_email_otps").then(() => {}).catch(() => {});

    return json({ sent: true, expiresInSeconds: CODE_TTL_MINUTES * 60 });
  } catch (error) {
    console.error("[send-email-otp]", error);
    if (error instanceof FunctionError) return json({ error: error.message }, error.status);
    return json({ error: "Unexpected server error." }, 500);
  }
});
