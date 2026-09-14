// verify-email-otp
// ----------------
// SIGNUP email verification — STEP 2 of 2. Public (pre-auth) function.
//
// OTP is used ONLY at signup to prove the user owns the email. This verifies
// the 6-digit code against the stored SHA-256 hash (expiry, single-use,
// max-attempts), then CREATES the Supabase Auth user WITH the supplied password
// and marks the email confirmed — all in one step, so no half-created or
// unverified accounts ever exist. Login afterwards is plain email+password
// (no OTP) and does not touch this function.
//
// A session (access_token + refresh_token) is returned so the app is signed in
// immediately after signup.
//
// Deploy with verify_jwt = false (there is no session yet).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  adminClient,
  body,
  cors,
  FunctionError,
  json,
  optionalString,
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

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function findAuthUserByEmail(email: string): Promise<{ id: string } | null> {
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
    const password = requiredString(input.password, "password");
    const name = optionalString(input.name, 80) ?? "";
    if (!EMAIL_RE.test(email)) throw new FunctionError(400, "Enter a valid email address.");
    if (!/^\d{6}$/.test(code)) throw new FunctionError(400, "Enter the 6-digit code.");
    if (password.length < 6) throw new FunctionError(400, "Password must be at least 6 characters.");

    // Signup only: if this email already has an account, they should log in.
    if (await findAuthUserByEmail(email)) {
      throw new FunctionError(409, "This email already has an account. Please log in instead.");
    }

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

    // Create the account WITH the chosen password, email pre-confirmed.
    const { data: created, error: createErr } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: name ? { name } : undefined,
    });
    let userId = created?.user?.id;
    if (createErr || !userId) {
      // Rare race: someone registered between our check and now.
      const raced = await findAuthUserByEmail(email);
      if (raced) throw new FunctionError(409, "This email already has an account. Please log in instead.");
      throw new FunctionError(500, "Could not create your account.");
    }

    // Cache a contactable report email (and name) on the profile row that the
    // on_auth_user_created trigger just inserted. Both are server-owned here.
    await adminClient
      .from("users")
      .update({ report_email: email, ...(name ? { name } : {}) })
      .eq("id", userId)
      .catch(() => {});

    // Sign the new user in right away by exchanging their password for a
    // session (they just chose it, so this is safe and avoids magiclink hops).
    const anon = createClient(supabaseUrl, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: signIn, error: signInErr } = await anon.auth.signInWithPassword({ email, password });
    if (signInErr || !signIn.session) {
      // Account exists and is valid; the client can just log in.
      return json({ verified: true, isNewUser: true, session: null });
    }

    return json({
      verified: true,
      isNewUser: true,
      session: {
        access_token: signIn.session.access_token,
        refresh_token: signIn.session.refresh_token,
        expires_in: signIn.session.expires_in,
        expires_at: signIn.session.expires_at,
        token_type: signIn.session.token_type,
      },
    });
  } catch (error) {
    console.error("[verify-email-otp]", error);
    if (error instanceof FunctionError) return json({ error: error.message }, error.status);
    return json({ error: "Unexpected server error." }, 500);
  }
});
