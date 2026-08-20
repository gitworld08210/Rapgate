import { adminClient, FunctionError, invoke, requireUser } from "../_shared/common.ts";

/**
 * Deletes the caller's account and all owned data.
 *
 * Runs with the service role so it can remove rows across every user-owned
 * table plus the two private Storage buckets, then deletes the Supabase Auth
 * user last (cascading `on delete cascade` foreign keys clean up remaining
 * rows automatically, but Storage objects are not covered by that cascade and
 * are removed explicitly here).
 */
Deno.serve((req) => invoke("delete-account", req, async (request) => {
  const { user } = await requireUser(request);

  const [foodImages, fineProofs] = await Promise.all([
    adminClient.storage.from("food-images").list(`${user.id}/food_images`),
    adminClient.storage.from("fine-proofs").list(`${user.id}/fine_proofs`),
  ]);

  if (foodImages.data?.length) {
    await adminClient.storage
      .from("food-images")
      .remove(foodImages.data.map((f) => `${user.id}/food_images/${f.name}`));
  }
  if (fineProofs.data?.length) {
    await adminClient.storage
      .from("fine-proofs")
      .remove(fineProofs.data.map((f) => `${user.id}/fine_proofs/${f.name}`));
  }

  // `on delete cascade` on every user_id foreign key removes food_logs,
  // water_logs, weight_logs, pushup_sessions, blocked_apps_config, streaks,
  // fines, emergency_unlocks, accountability_links, and admin_roles rows.
  const { error } = await adminClient.auth.admin.deleteUser(user.id);
  if (error) throw new FunctionError(500, "Could not delete the account.");

  return { deleted: true };
}));
