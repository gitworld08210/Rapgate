import { createClient, type SupabaseClient, type User } from "https://esm.sh/@supabase/supabase-js@2";

export const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

export const adminClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

export function userClient(accessToken: string): SupabaseClient {
  return createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export class FunctionError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
    this.name = "FunctionError";
  }
}

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

export function cors(req: Request): Response | null {
  return req.method === "OPTIONS" ? json({}, 204) : null;
}

export async function body(req: Request): Promise<Record<string, unknown>> {
  try {
    const value: unknown = await req.json();
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new FunctionError(400, "Request body must be a JSON object.");
    }
    return value as Record<string, unknown>;
  } catch (error) {
    if (error instanceof FunctionError) throw error;
    throw new FunctionError(400, "Request body must be valid JSON.");
  }
}

// Parsed without a regex on purpose. This file is sometimes deployed by
// transmitting its source as a JSON string, where an over-escaped backslash in
// a regex literal silently changes the whitespace class into "literal
// backslash followed by s". That matches no real Authorization header, so every
// authenticated request fails with "Sign in first.". Plain string parsing keeps
// this function immune to that class of bug.
export function bearer(req: Request): string {
  const value = (req.headers.get("Authorization") ?? "").trim();
  const prefix = "bearer ";
  if (value.toLowerCase().startsWith(prefix)) {
    const token = value.slice(prefix.length).trim();
    if (token.length > 0) return token;
  }
  throw new FunctionError(401, "Sign in first.");
}

export async function requireUser(req: Request): Promise<{ user: User; token: string }> {
  const token = bearer(req);
  const { data, error } = await userClient(token).auth.getUser(token);
  if (error || !data.user) throw new FunctionError(401, "Sign in first.");
  return { user: data.user, token };
}

export function requireCron(req: Request): void {
  const expected = Deno.env.get("CRON_SECRET");
  if (!expected || req.headers.get("x-cron-secret") !== expected) {
    throw new FunctionError(401, "Invalid scheduler credential.");
  }
}

export async function requireAdmin(req: Request): Promise<{ user: User; token: string }> {
  const auth = await requireUser(req);
  const allowlist = (Deno.env.get("ADMIN_EMAILS") ?? "")
    .split(",").map((email) => email.trim().toLowerCase()).filter(Boolean);
  const email = auth.user.email?.toLowerCase();
  if (!email || !auth.user.email_confirmed_at || !allowlist.includes(email)) {
    throw new FunctionError(403, "You are not authorised to perform this action.");
  }
  const { data: role, error } = await adminClient
    .from("admin_roles").select("user_id").eq("user_id", auth.user.id).is("revoked_at", null).maybeSingle();
  if (error || !role) throw new FunctionError(403, "You are not authorised to perform this action.");
  return auth;
}

export function requiredString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new FunctionError(400, `${field} is required.`);
  }
  return value.trim();
}

export function optionalString(value: unknown, max: number): string | null {
  if (typeof value !== "string" || value.trim().length === 0) return null;
  return value.trim().slice(0, max);
}

export function numberOr(value: unknown, fallback: number): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

export function clamp(value: unknown, min: number, max: number): number {
  return Math.min(Math.max(numberOr(value, 0), min), max);
}

export function round(value: number): number {
  return Math.round(value * 10) / 10;
}

export function hoursFromNow(hours: number): string {
  return new Date(Date.now() + hours * 60 * 60 * 1000).toISOString();
}

export function isOwnedStoragePath(path: string, uid: string): boolean {
  return path.startsWith(`${uid}/`) && !path.includes("..") && path.length <= 512;
}

export async function listUserIds(): Promise<string[]> {
  const ids: string[] = [];
  const pageSize = 500;
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await adminClient.from("users").select("id").order("id", { ascending: true }).range(from, from + pageSize - 1);
    if (error) throw new FunctionError(500, "Could not enumerate users.");
    ids.push(...(data ?? []).map((row) => String(row.id)));
    if (!data || data.length < pageSize) return ids;
  }
}

export async function invoke(name: string, req: Request, handler: (req: Request) => Promise<unknown>): Promise<Response> {
  try {
    const preflight = cors(req);
    if (preflight) return preflight;
    if (req.method !== "POST") throw new FunctionError(405, "Use POST.");
    return json(await handler(req));
  } catch (error) {
    console.error(`[${name}]`, error);
    if (error instanceof FunctionError) return json({ error: error.message }, error.status);
    return json({ error: "Unexpected server error." }, 500);
  }
}
