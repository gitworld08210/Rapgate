import { adminClient, invoke, requireCron, listUserIds } from "../_shared/common.ts";
import { recordAndSendNotification } from "../_shared/notifications.ts";

Deno.serve((req) => invoke("send-pre-lock-reminder", req, async (request) => {
  requireCron(request);
  const since = new Date(Date.now() - 23 * 60 * 60 * 1000).toISOString();
  const userIds = await listUserIds();
  let reminded = 0;
  for (const uid of userIds) {
    try {
      const { data: verified } = await adminClient.from("pushup_sessions").select("id").eq("user_id", uid).eq("status", "verified").gte("completed_at", since).limit(1);
      if (verified && verified.length > 0) continue;
      const { data: tokens } = await adminClient.from("notification_tokens").select("id").eq("user_id", uid).limit(1);
      if (!tokens || tokens.length === 0) continue;
      await recordAndSendNotification(uid, "pre_lock_reminder", { title: "1 ghanta baaki hai 💪", body: "Push-ups complete karo warna apps lock ho jayenge aur fine lagega.", channel: "pushup_reminders" });
      reminded++;
    } catch (error) { console.warn("Reminder failed", uid, error); }
  }
  return { checked: userIds.length, reminded };
}));
