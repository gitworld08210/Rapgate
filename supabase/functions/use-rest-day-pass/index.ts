import { adminClient, invoke, requireUser } from "../_shared/common.ts";

Deno.serve((req) =>
  invoke("use-rest-day-pass", req, async (request) => {
    const { user } = await requireUser(request);

    // Check current passes before calling the function
    const { data: streak, error: streakErr } = await adminClient
      .from("streaks")
      .select("rest_day_passes, current_pushup_streak")
      .eq("user_id", user.id)
      .maybeSingle();

    if (streakErr || !streak) {
      throw { status: 404, message: "Streak record not found." };
    }

    if ((streak.rest_day_passes ?? 0) <= 0) {
      throw { status: 400, message: "No rest day passes available." };
    }

    // Call the server function
    const { data: remaining, error: rpcErr } = await adminClient.rpc(
      "use_rest_day_pass",
      { p_user_id: user.id }
    );

    if (rpcErr) {
      console.error("use_rest_day_pass RPC error:", rpcErr);
      throw { status: 500, message: "Failed to use rest day pass." };
    }

    return {
      success: true,
      remaining_passes: remaining ?? 0,
      message: "Rest day pass used. Your streak is protected!",
    };
  })
);
