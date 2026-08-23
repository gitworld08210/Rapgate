import { adminClient, invoke, requireUser } from "../_shared/common.ts";

Deno.serve((req) => invoke("get-referral-stats", req, async (request) => {
  const { user } = await requireUser(request);

  // Get user's referral code
  const { data: userData } = await adminClient
    .from("users")
    .select("referral_code")
    .eq("id", user.id)
    .single();

  const referralCode = userData?.referral_code ?? "";

  // Get total referral count for this user
  const { count: totalReferrals } = await adminClient
    .from("referrals")
    .select("id", { count: "exact", head: true })
    .eq("referrer_id", user.id)
    .in("status", ["completed", "rewarded"]);

  // Get top 10 leaderboard (users with most completed referrals)
  const { data: leaderboard } = await adminClient
    .rpc("get_referral_leaderboard");

  return {
    referral_code: referralCode,
    total_referrals: totalReferrals ?? 0,
    leaderboard: leaderboard ?? [],
  };
}));
