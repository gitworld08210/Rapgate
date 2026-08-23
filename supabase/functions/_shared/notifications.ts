import { adminClient } from "./common.ts";

/**
 * Sends a smart (contextual) notification to a user.
 * Wraps recordAndSendNotification with the standard payload format
 * including title, body, and channel fields.
 */
export async function sendSmartNotification(
  userId: string,
  title: string,
  body: string,
  channel: string,
): Promise<void> {
  await recordAndSendNotification(userId, "smart_notification", {
    title,
    body,
    channel,
  });
}

export async function recordAndSendNotification(
  userId: string,
  eventType: string,
  payload: Record<string, unknown>,
): Promise<void> {
  const { data: event, error } = await adminClient.from("notification_events").insert({ user_id: userId, event_type: eventType, payload }).select("id").single();
  if (error) {
    console.warn("Could not record notification event", error.message);
    return;
  }
  const { data: rows } = await adminClient.from("notification_tokens").select("token").eq("user_id", userId);
  const tokens = (rows ?? []).map((row) => String(row.token)).filter(Boolean);
  const webhook = Deno.env.get("PUSH_WEBHOOK_URL");
  if (!webhook || tokens.length === 0) return;
  try {
    const response = await fetch(webhook, { method: "POST", headers: { "Content-Type": "application/json", ...(Deno.env.get("PUSH_WEBHOOK_TOKEN") ? { Authorization: `Bearer ${Deno.env.get("PUSH_WEBHOOK_TOKEN")}` } : {}) }, body: JSON.stringify({ tokens, eventType, payload }) });
    if (!response.ok) throw new Error(`push provider returned ${response.status}`);
    await adminClient.from("notification_events").update({ delivered_at: new Date().toISOString() }).eq("id", event.id);
  } catch (error) {
    console.warn("Push delivery failed; event remains recorded", error);
  }
}

export async function notifyAccountabilityContact(uid: string): Promise<void> {
  const { data: link } = await adminClient.from("accountability_links").select("linked_contact_uid, notify_on_miss").eq("user_id", uid).maybeSingle();
  if (!link?.notify_on_miss || !link.linked_contact_uid) return;
  const { data: owner } = await adminClient.from("users").select("name").eq("id", uid).maybeSingle();
  await recordAndSendNotification(String(link.linked_contact_uid), "accountability_miss", { title: "Accountability nudge", body: `${owner?.name || "Your friend"} missed their push-ups today.`, channel: "streaks" });
}
