// ==========================================================================
// Azure Communication Services (ACS) Email client
// ==========================================================================
//
// All transactional email in Rapgate (OTP codes, weekly/monthly reports) is
// delivered through Azure Communication Services Email — never through
// Supabase's built-in mailer.
//
// Auth uses ACS's HMAC-SHA256 request signing scheme, which works with the
// resource's connection string (endpoint + accessKey). No SDK is required, so
// this stays a zero-dependency Deno module.
//
// Required Edge Function secrets:
//   AZURE_ACS_CONNECTION_STRING  e.g. "endpoint=https://<res>.communication.azure.com/;accesskey=<base64key>"
//   AZURE_ACS_SENDER             verified MailFrom address, e.g. "DoNotReply@<verified-domain>"
//
// Optionally, instead of the connection string you may set:
//   AZURE_ACS_ENDPOINT           "https://<res>.communication.azure.com"
//   AZURE_ACS_ACCESS_KEY         base64 access key
//
// If ACS is not configured, isAzureEmailConfigured() returns false and callers
// decide what to do (the OTP function refuses; report functions skip quietly).

const API_VERSION = "2023-03-31";

interface AcsCreds {
  endpoint: string; // no trailing slash, e.g. https://res.communication.azure.com
  accessKey: string; // base64
  host: string; // res.communication.azure.com
}

function parseConnectionString(cs: string): { endpoint?: string; accessKey?: string } {
  const out: { endpoint?: string; accessKey?: string } = {};
  for (const part of cs.split(";")) {
    const idx = part.indexOf("=");
    if (idx <= 0) continue;
    const key = part.slice(0, idx).trim().toLowerCase();
    const value = part.slice(idx + 1).trim();
    if (key === "endpoint") out.endpoint = value;
    else if (key === "accesskey") out.accessKey = value;
  }
  return out;
}

function resolveCreds(): AcsCreds | null {
  const cs = Deno.env.get("AZURE_ACS_CONNECTION_STRING") ?? "";
  let endpoint = Deno.env.get("AZURE_ACS_ENDPOINT") ?? "";
  let accessKey = Deno.env.get("AZURE_ACS_ACCESS_KEY") ?? "";

  if (cs) {
    const parsed = parseConnectionString(cs);
    endpoint = endpoint || (parsed.endpoint ?? "");
    accessKey = accessKey || (parsed.accessKey ?? "");
  }

  endpoint = endpoint.replace(/\/+$/, "");
  if (!endpoint || !accessKey) return null;

  let host: string;
  try {
    host = new URL(endpoint).host;
  } catch {
    return null;
  }
  return { endpoint, accessKey, host };
}

export function isAzureEmailConfigured(): boolean {
  return resolveCreds() !== null && (Deno.env.get("AZURE_ACS_SENDER") ?? "").length > 0;
}

function toBase64(bytes: ArrayBuffer): string {
  const arr = new Uint8Array(bytes);
  let binary = "";
  for (let i = 0; i < arr.length; i++) binary += String.fromCharCode(arr[i]);
  return btoa(binary);
}

function fromBase64(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function sha256Base64(payload: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(payload));
  return toBase64(digest);
}

async function hmacSha256Base64(keyB64: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    fromBase64(keyB64),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return toBase64(sig);
}

export interface EmailMessage {
  to: string;
  subject: string;
  html: string;
  plainText?: string;
}

export interface EmailSendResult {
  ok: boolean;
  status: number;
  error?: string;
  messageId?: string;
}

/**
 * Sends a single email via Azure Communication Services.
 * Returns a result object rather than throwing, so callers can decide whether a
 * delivery failure is fatal (OTP) or best-effort (reports).
 */
export async function sendAzureEmail(message: EmailMessage): Promise<EmailSendResult> {
  const creds = resolveCreds();
  const sender = Deno.env.get("AZURE_ACS_SENDER") ?? "";
  if (!creds || !sender) {
    return { ok: false, status: 0, error: "Azure ACS email is not configured." };
  }

  const url = `${creds.endpoint}/emails:send?api-version=${API_VERSION}`;
  const payload = JSON.stringify({
    senderAddress: sender,
    content: {
      subject: message.subject,
      plainText: message.plainText ?? stripHtml(message.html),
      html: message.html,
    },
    recipients: { to: [{ address: message.to }] },
  });

  const dateHeader = new Date().toUTCString();
  const contentHash = await sha256Base64(payload);
  const target = new URL(url);
  const pathAndQuery = `${target.pathname}${target.search}`;
  // ACS string-to-sign: VERB\npath?query\ndate;host;x-ms-content-sha256
  const stringToSign = `POST\n${pathAndQuery}\n${dateHeader};${creds.host};${contentHash}`;
  const signature = await hmacSha256Base64(creds.accessKey, stringToSign);
  const authHeader =
    `HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256&Signature=${signature}`;

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-ms-date": dateHeader,
        "x-ms-content-sha256": contentHash,
        "host": creds.host,
        "Authorization": authHeader,
      },
      body: payload,
    });

    if (res.status >= 200 && res.status < 300) {
      const messageId = res.headers.get("operation-location") ??
        res.headers.get("x-ms-request-id") ?? undefined;
      return { ok: true, status: res.status, messageId };
    }

    const text = await res.text().catch(() => "");
    return { ok: false, status: res.status, error: text.slice(0, 500) || `HTTP ${res.status}` };
  } catch (error) {
    return { ok: false, status: 0, error: String(error) };
  }
}

function stripHtml(html: string): string {
  return html
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}
