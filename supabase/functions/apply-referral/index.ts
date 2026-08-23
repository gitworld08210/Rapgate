import { adminClient, invoke, body, requireUser, requiredString, FunctionError } from "../_shared/common.ts";
import { recordAndSendNotification } from "../_shared/notifications.ts";

Deno.serve((req) => invoke("apply-referral", req, async (request) => {
  const { user } = await requireUser(request);
  const input = await body(request);
  const code = requiredString(input.code, "code").toUpperCase();

  // Look up the referral code owner
  const { data: referrer, error: referrerError } = await adminClient
    .from("users")
    .select("id, name, referral_code")
    .eq("referral_code", code)
    .maybeSingle();

  if (referrerError || !referrer) {
    throw new FunctionError(404, "Invalid referral code.");
  }

  // Prevent self-referral
  if (referrer.id === user.id) {
    throw new FunctionError(400, "You cannot use your own referral code.");
  }

  // Check if this user has already used a referral code (referee already exists)
  const { data: existingReferral } = await adminClient
    .from("referrals")
    .select("id")
    .eq("referee_id", user.id)
    .limit(1);

  if (existingReferral && existingReferral.length > 0) {
    throw new FunctionError(400, "You have already used a referral code.");
  }

  // Insert the referral record (UNIQUE constraint on referee_id prevents double-apply race)
  const { error: insertError } = await adminClient
    .from("referrals")
    .insert({
      referrer_id: referrer.id,
      referee_id: user.id,
      code: code,
      status: "completed",
      reward_type: "fine_waiver_7d",
    });

  if (insertError) {
    // Handle unique constraint violation (concurrent double-apply)
    if (insertError.code === "23505") {
      throw new FunctionError(400, "You have already used a referral code.");
    }
    console.error("Failed to insert referral", insertError);
    throw new FunctionError(500, "Could not apply referral code.");
  }

  // Grant 7-day fine waiver to BOTH users
  const unlockUntil = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

  // Grant to referee (current user)
  await adminClient
    .from("blocked_apps_config")
    .upsert({
      user_id: user.id,
      last_unlocked_at: new Date().toISOString(),
      unlock_granted_until: unlockUntil,
      unlock_source: "referral_reward",
    }, { onConflict: "user_id" });

  // Grant to referrer
  await adminClient
    .from("blocked_apps_config")
    .upsert({
      user_id: referrer.id,
      last_unlocked_at: new Date().toISOString(),
      unlock_granted_until: unlockUntil,
      unlock_source: "referral_reward",
    }, { onConflict: "user_id" });

  // Notify both users
  await recordAndSendNotification(user.id, "referral_applied", {
    title: "Referral reward unlocked! 🎉",
    body: `You used ${referrer.name || "a friend"}'s code. Enjoy 7 days fine-free!`,
    channel: "referrals",
  });

  await recordAndSendNotification(referrer.id, "referral_earned", {
    title: "New referral! 🎉",
    body: `Someone joined with your code! You both get 7 days fine-free.`,
    channel: "referrals",
  });

  return {
    success: true,
    message: "Referral applied! Both you and your friend get 7 days fine-free.",
    unlock_until: unlockUntil,
  };
}));
