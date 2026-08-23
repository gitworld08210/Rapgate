import { invoke, requireUser, adminClient, json } from "../_shared/common.ts";

Deno.serve((req) =>
  invoke("get-leaderboard", req, async (req) => {
    const { user } = await requireUser(req);

    const { data, error } = await adminClient.rpc("get_leaderboard", {
      p_user_id: user.id,
    });

    if (error) {
      console.error("Leaderboard RPC error:", error);
      throw { status: 500, message: "Failed to fetch leaderboard." };
    }

    return { leaderboard: data ?? [] };
  })
);
