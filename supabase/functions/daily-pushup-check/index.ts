import { adminClient, invoke, requireCron, listUserIds } from "../_shared/common.ts";
import { notifyAccountabilityContact } from "../_shared/notifications.ts";

Deno.serve((req) => invoke("daily-pushup-check", req, async (request) => {
  requireCron(request);
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const userIds = await listUserIds();
  let missed = 0;
  for (const uid of userIds) {
    try {
      const { data: verified } = await adminClient.from("pushup_sessions").select("id").eq("user_id", uid).eq("status", "verified").gte("completed_at", cutoff).limit(1);
      if (verified && verified.length > 0) continue;
      const { data: paid } = await adminClient.from("fines").select("id").eq("user_id", uid).eq("status", "approved").gte("reviewed_at", cutoff).limit(1);
      if (paid && paid.length > 0) continue;

      // Reset streak and atomically increment consecutive misses
      await adminClient.from("streaks").update({ current_pushup_streak: 0 }).eq("user_id", uid);
      const { data: updatedRow } = await adminClient.rpc("increment_consecutive_misses", { p_user_id: uid });
      const currentMisses = typeof updatedRow === "number" ? updatedRow : 1;

      // Compute escalated fine based on consecutive misses
      const { data: fineAmount } = await adminClient.rpc("compute_escalated_fine", { consecutive: currentMisses });
      const escalatedAmount = typeof fineAmount === "number" ? fineAmount : Number(Deno.env.get("FINE_AMOUNT_PAISE") ?? 5000);

      await adminClient.rpc("create_fine_if_missing", { p_user_id: uid, p_reason: "pushup_skipped", p_amount_paise: escalatedAmount });
      await notifyAccountabilityContact(uid);
      missed++;
    } catch (error) { console.error("dailyPushupCheck failed", uid, error); }
  }
  return { checked: userIds.length, missed };
}));
