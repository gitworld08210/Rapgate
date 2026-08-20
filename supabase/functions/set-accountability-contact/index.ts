import { adminClient, FunctionError, invoke, body, requireUser, optionalString } from "../_shared/common.ts";

async function resolveContactUid(phone: string | null): Promise<string | null> {
  if (!phone) return null;
  // Supabase Auth does not expose a SQL-safe phone lookup. This deliberately
  // stays server-side; for larger installations replace it with a consented
  // phone hash/profile index instead of exposing a user directory.
  for (let page = 1; page <= 10; page++) {
    const { data, error } = await adminClient.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) return null;
    const match = data.users.find((candidate) => candidate.phone === phone);
    if (match) return match.id;
    if (data.users.length < 1000) break;
  }
  return null;
}

Deno.serve((req) => invoke("set-accountability-contact", req, async (request) => {
  const { user } = await requireUser(request);
  const input = await body(request);
  const notifyOnMiss = input.notifyOnMiss === true;
  const contactPhone = optionalString(input.contactPhone, 20);
  const contactName = optionalString(input.contactName, 80);
  const linkedContactUid = await resolveContactUid(contactPhone);
  const { error } = await adminClient.from("accountability_links").upsert({ user_id: user.id, notify_on_miss: notifyOnMiss, contact_phone: contactPhone, contact_name: contactName, linked_contact_uid: linkedContactUid, updated_at: new Date().toISOString() }, { onConflict: "user_id" });
  if (error) throw new FunctionError(500, "Could not save accountability contact.");
  return { saved: true, linkedToAppUser: linkedContactUid !== null };
}));
