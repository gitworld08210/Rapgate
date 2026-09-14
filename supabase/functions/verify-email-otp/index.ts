// verify-email-otp
// ----------------
// Passwordless email OTP — STEP 2 of 2. Public (pre-auth) function.
//
// Verifies the 6-digit code the user typed against the stored SHA-256 hash,
// enforcing expiry, single-use, and a max-attempts cap. On success it ensures a
// Supabase Auth user exists for the email and returns a real session
// (access_token + refresh_token) that the Flutter client installs.
//
// Session minting strategy:
//   1. Ensure the auth user exists (create with email_confirm=true if new).
//   2. admin.generateLink({ type: 'magiclink' }) -> returns a token_hash.
//   3. Exchange token_hash via anon-client verifyOtp({ type: 'email' }) to get
//      a session. This keeps password handling entirely out of the flow.
//
// Deploy with verify_jwt = false (there is no session yet).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  adminClient,
  body,
  cors,
  FunctionError,
  json,
  requiredString,
  supabaseUrl,
} from "../_shared/common.ts";

const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function normalizeEmail(raw: string): string {
  return raw.trim().toLowerCase();
}

async function hashCode(email: string, code: string): Promise<string> {
  const data = new TextEncoder().encode(`${email}:${code}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Constant-time-ish comparison for the two hex hashes.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function findAuthUserByEmail(email: string): Promise<{ id: string } | null> {
  // Paginate the admin user list to find a matching email.
  for (let page = 1; page <= 20; page++) {
    const { data, error } = await adminClient.auth.admin.listUsers({ page, perPage: 200 });
    if (error) throw new FunctionError(500, "Could not look up the account.");
    const match = data.users.find((u) => (u.email ?? "").toLowerCase() === email);
    if (match) return { id: match.id };
    if (data.users.length < 200) break;
  }
  return null;
}

Deno.serve(async (req) => {
  const preflight = cors(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  try {
    const input = await body(req);
    const email = normalizeEmail(requiredString(input.email, "email"));
    const code = requiredString(input.code, "code").replace(/\s+/g, "");
    if (!EMAIL_RE.test(email)) throw new FunctionError(400, "Enter a valid email address.");
    if (!/^\d{6}$/.test(code)) throw new FunctionError(400, "Enter the 6-digit code.");

    // Fetch the newest unconsumed OTP for this email.
    const { data: otp, error: otpErr } = await adminClient
      .from("email_otps")
      .select("id, code_hash, attempts, max_attempts, expires_at, consumed_at")
      .eq("email", email)
      .is("consumed_at", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (otpErr) throw new FunctionError(500, "Could not verify the code.");
    if (!otp) throw new FunctionError(400, "No active code. Request a new one.");

    if (new Date(otp.expires_at as string).getTime() < Date.now()) {
      await adminClient.from("email_otps").update({ consumed_at: new Date().toISOString() }).eq("id", otp.id);
      throw new FunctionError(400, "That code has expired. Request a new one.");
    }

    if ((otp.attempts as number) >= (otp.max_attempts as number)) {
      await adminClient.from("email_otps").update({ consumed_at: new Date().toISOString() }).eq("id", otp.id);
      throw new FunctionError(429, "Too many incorrect attempts. Request a new code.");
    }

    const providedHash = await hashCode(email, code);
    if (!timingSafeEqual(providedHash, otp.code_hash as string)) {
      await adminClient
        .from("email_otps")
        .update({ attempts: (otp.attempts as number) + 1 })
        .eq("id", otp.id);
      const remaining = (otp.max_attempts as number) - (otp.attempts as number) - 1;
      throw new FunctionError(
        401,
        remaining > 0 ? `Incorrect code. ${remaining} attempt(s) left.` : "Incorrect code. Request a new one.",
      );
    }

    // Correct code — consume it immediately (single use).
    await adminClient.from("email_otps").update({ consumed_at: new Date().toISOString() }).eq("id", otp.id);

    // Ensure an auth user exists for this email.
    let existing = await findAuthUserByEmail(email);
    let isNewUser = false;
    if (!existing) {
      const { data: created, error: createErr } = await adminClient.auth.admin.createUser({
        email,
        email_confirm: true,
      });
      if (createErr || !created.user) {
        // Possible race: another request created it. Re-fetch once.
        existing = await findAuthUserByEmail(email);
        if (!existing) throw new FunctionError(500, "Could not create your account.");
      } else {
        existing = { id: created.user.id };
        isNewUser = true;
      }
    } else {
      // Make sure the email is confirmed so future flows treat it as verified.
      await adminClient.auth.admin.updateUserById(existing.id, { email_confirm: true }).catch(() => {});
    }

    // Cache a contactable report email on the profile (server-owned field).
    await adminClient.from("users").update({ report_email: email }).eq("id", existing.id).catch(() => {});

    // Mint a session via a magiclink token_hash exchange.
    const { data: linkData, error: linkErr } = await adminClient.auth.admin.generateLink({
      type: "magiclink",
      email,
    });
    if (linkErr || !linkData?.properties?.hashed_token) {
      throw new FunctionError(500, "Could not start your session.");
    }

    const anon = createClient(supabaseUrl, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: verified, error: verifyErr } = await anon.auth.verifyOtp({
      type: "email",
      token_hash: linkData.properties.hashed_token,
    });
    if (verifyErr || !verified.session) {
      throw new FunctionError(500, "Could not start your session.");
    }

    return json({
      verified: true,
      isNewUser,
      session: {
        access_token: verified.session.access_token,
        refresh_token: verified.session.refresh_token,
        expires_in: verified.session.expires_in,
        expires_at: verified.session.expires_at,
        token_type: verified.session.token_type,
      },
    });
  } catch (error) {
    console.error("[verify-email-otp]", error);
    if (error instanceof FunctionError) return json({ error: error.message }, error.status);
    return json({ error: "Unexpected server error." }, 500);
  }
});
