import { adminClient, FunctionError, invoke, body, requireUser, optionalString, requiredString } from "../_shared/common.ts";

Deno.serve((req) => invoke("register-notification-token", req, async (request) => {
  const { user } = await requireUser(request);
  const input = await body(request);
  const token = requiredString(input.token, "token").slice(0, 2048);
  const platform = optionalString(input.platform, 32);
  const { error } = await adminClient.from("notification_tokens").upsert({ user_id: user.id, token, platform, last_seen_at: new Date().toISOString() }, { onConflict: "user_id,token" });
  if (error) throw new FunctionError(500, "Could not register notification token.");
  return { registered: true };
}));
