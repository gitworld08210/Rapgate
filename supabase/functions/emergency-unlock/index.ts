import {
  adminClient,
  invoke,
  requireUser,
  body,
  requiredString,
  hoursFromNow,
  FunctionError,
} from "../_shared/common.ts";

const MAX_EMERGENCY_UNLOCKS_PER_WEEK = 2;
const EMERGENCY_UNLOCK_HOURS = 2;

Deno.serve((req) =>
  invoke("emergency-unlock", req, async (request) => {
    const { user } = await requireUser(request);
    const payload = await body(request);
    const reason = requiredString(payload.reason, "reason");

    // Check weekly limit
    const now = new Date();
    const dayOfWeek = now.getDay() === 0 ? 7 : now.getDay(); // Mon=1 .. Sun=7
    const startOfWeek = new Date(now);
    startOfWeek.setDate(now.getDate() - (dayOfWeek - 1));
    startOfWeek.setHours(0, 0, 0, 0);

    const { data: unlocks, error: countErr } = await adminClient
      .from("emergency_unlocks")
      .select("id")
      .eq("user_id", user.id)
      .gte("created_at", startOfWeek.toISOString());

    if (countErr) {
      throw new FunctionError(500, "Could not check unlock history.");
    }

    const usedThisWeek = unlocks?.length ?? 0;
    if (usedThisWeek >= MAX_EMERGENCY_UNLOCKS_PER_WEEK) {
      throw new FunctionError(
        429,
        `You have used all ${MAX_EMERGENCY_UNLOCKS_PER_WEEK} emergency unlocks this week.`
      );
    }

    // Insert emergency unlock record
    const expiresAt = hoursFromNow(EMERGENCY_UNLOCK_HOURS);

    const { error: insertErr } = await adminClient
      .from("emergency_unlocks")
      .insert({
        user_id: user.id,
        reason,
        granted_until: expiresAt,
      });

    if (insertErr) {
      console.error("emergency_unlocks insert error:", insertErr);
      throw new FunctionError(500, "Failed to create emergency unlock.");
    }

    // Grant unlock via blocked_apps_config
    const { error: updateErr } = await adminClient
      .from("blocked_apps_config")
      .update({
        unlock_granted_until: expiresAt,
        unlock_source: "emergency",
      })
      .eq("user_id", user.id);

    if (updateErr) {
      console.error("blocked_apps_config update error:", updateErr);
      // Non-fatal: unlock record exists, client can still check it
    }

    // Create a fine for using emergency unlock
    const fineAmount = Number(Deno.env.get("FINE_AMOUNT_PAISE") ?? 5000);
    const { error: fineErr } = await adminClient.from("fines").insert({
      user_id: user.id,
      amount_paise: fineAmount,
      reason: "emergency_unlock",
      status: "pending",
    });

    if (fineErr) {
      console.error("fine insert error:", fineErr);
      // Non-fatal: the unlock was granted, but log the issue
    }

    return {
      success: true,
      unlocked_until: expiresAt,
      used_this_week: usedThisWeek + 1,
      max_per_week: MAX_EMERGENCY_UNLOCKS_PER_WEEK,
      message: `Apps unlocked for ${EMERGENCY_UNLOCK_HOURS} hours. A fine has been created.`,
    };
  })
);
