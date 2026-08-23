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

  // Grant 7-day fine waiver to BOTH users.
  // Use GREATEST to never shorten an existing longer unlock (e.g., from pushups or paid fine).
  const unlockUntil = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

  await grantReferralReward(user.id, unlockUntil);
  await grantReferralReward(referrer.id, unlockUntil);

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

/**
 * Grants a referral reward without shortening an existing longer unlock.
 * Fetches the current unlock_granted_until and takes the later of the two dates.
 */
async function grantReferralReward(userId: string, newUnlockUntil: string): Promise<void> {
  const { data: existing } = await adminClient
    .from("blocked_apps_config")
    .select("unlock_granted_until")
    .eq("user_id", userId)
    .maybeSingle();

  // Keep the later date: never shorten an existing unlock
  let effectiveUntil = newUnlockUntil;
  if (existing?.unlock_granted_until) {
    const existingDate = new Date(existing.unlock_granted_until);
    const newDate = new Date(newUnlockUntil);
    if (existingDate > newDate) {
      effectiveUntil = existing.unlock_granted_until;
    }
  }

  await adminClient
    .from("blocked_apps_config")
    .upsert({
      user_id: userId,
      last_unlocked_at: new Date().toISOString(),
      unlock_granted_until: effectiveUntil,
      unlock_source: "referral_reward",
    }, { onConflict: "user_id" });
}
