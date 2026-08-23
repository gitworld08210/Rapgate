# Supabase backend setup

This directory is the Firebase-to-Supabase backend migration for Rapgate. It intentionally does not modify `lib/`, `pubspec.yaml`, or Flutter platform code. The migration keeps the Firebase callable contracts conceptually intact, but requests are HTTP POSTs to Supabase Edge Functions and table fields use PostgreSQL `snake_case`.

## 1. Create and configure the project

1. Create a Supabase project and record its project URL, anon key, and service-role key. Keep the service-role key only in Edge Function secrets; it bypasses RLS.
2. In **SQL Editor**, run `supabase/migrations/001_initial_schema.sql` (or apply it with `supabase db push` after installing the Supabase CLI).
3. In **Authentication > Providers**, enable the providers used by the Flutter app. Configure email confirmation and the production redirect URLs before using `claim-admin-role`.
4. Deploy the functions from the repository root:

   ```bash
   supabase functions deploy scan-food-image
   supabase functions deploy search-food-by-barcode
   supabase functions deploy start-pushup-session
   supabase functions deploy submit-pushup-frame-batch
   supabase functions deploy submit-fine-proof
   supabase functions deploy review-fine
   supabase functions deploy claim-admin-role
   supabase functions deploy revoke-admin-role
   supabase functions deploy daily-pushup-check
   supabase functions deploy send-pre-lock-reminder
   supabase functions deploy set-accountability-contact
   supabase functions deploy register-notification-token
   ```

5. Upload secrets. Start from `supabase/functions/.env.example`; do not commit the populated file:

   ```bash
   supabase secrets set --env-file supabase/functions/.env
   ```

   `ADMIN_EMAILS` is a server-only comma-separated allowlist. An account must also have a confirmed email. `claim-admin-role` writes `admin_roles` and the Supabase `app_metadata.admin` marker; every privileged function still re-checks the database role and allowlist.
6. The migration creates private `food-images` and `fine-proofs` buckets. Client object names must start with the authenticated user id, for example `<uid>/food_images/photo.jpg` and `<uid>/fine_proofs/<fine-id>.jpg`. Bucket size and image MIME restrictions are also set in the migration. Fine proof objects cannot be deleted by clients.

## 2. Function authentication and calls

Authenticated functions expect `Authorization: Bearer <Supabase access token>` and JSON POST bodies. The normal user functions validate the JWT with Supabase Auth, then use the service role only for server-authoritative writes. Scheduled functions have gateway JWT verification disabled in `config.toml`; they always require `x-cron-secret` matching the non-empty `CRON_SECRET` secret inside the function.

The push-up functions deliberately accept only frame angles, timestamps, and exact-true face flags. They ignore any client rep count, preserve the bounded 60-angle duplicate window, require complete extended/flexed/extended cycles, enforce 800–8,000 ms rep cadence and four frames, require 90% face visibility, and apply the duplicate/static-motion checks from `firebase/functions/src/pushup.ts`. Raw frames are never persisted. The SQL RPC locks the session row, checks a version number, and atomically writes the verified session plus 24-hour unlock configuration.

Fines remain `pending -> submitted -> approved|rejected`. Only the proof function can attach a UTR/storage path for an owner, the partial unique UTR index prevents reuse, and only an admin can approve. Approval grants the same 24-hour unlock and records an admin audit entry. `emergency_unlocks` is included as a server-only table because the Firebase model had it, but no emergency-unlock callable existed in the source and this migration does not invent one.

## 3. Scheduling with pg_cron and pg_net

Enable the extensions in **Database > Extensions** (or run the first two statements below). Store the project URL and cron secret in Vault rather than putting a service-role key in SQL. Supabase's hosted database cron timezone is commonly UTC, so these schedules convert the Firebase Asia/Kolkata times: 00:05 IST is 18:35 UTC and 23:00 IST is 17:30 UTC.

```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Replace the placeholders with Vault-backed values. The Edge Function URL is
-- public; x-cron-secret is checked inside the function.
select vault.create_secret('https://YOUR_PROJECT_REF.supabase.co', 'rapgate_supabase_url');
select vault.create_secret('replace-with-the-value-of-CRON_SECRET', 'rapgate_cron_secret');

select cron.schedule(
  'rapgate-daily-pushup-check',
  '35 18 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'rapgate_supabase_url') || '/functions/v1/daily-pushup-check',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'rapgate_cron_secret')),
    body := '{}'::jsonb
  );
  $$
);

select cron.schedule(
  'rapgate-pre-lock-reminder',
  '30 17 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'rapgate_supabase_url') || '/functions/v1/send-pre-lock-reminder',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'rapgate_cron_secret')),
    body := '{}'::jsonb
  );
  $$
);
```

Check jobs with `select * from cron.job;` and request history with `select * from net._http_response order by created desc;`. If the project/database timezone is explicitly configured to `Asia/Kolkata`, use `5 0 * * *` and `0 23 * * *` instead, not both sets of jobs. Jobs are intentionally per-user tolerant: one user's failure is logged without aborting the whole sweep.

## 4. Free-tier and operational caveats

- Supabase free projects can pause after inactivity, have finite database/storage/egress quotas, and have Edge Function and request-duration limits. The vision function has a 120-second client timeout inherited from Firebase; large images and provider latency can still exceed platform limits.
- `pg_cron`/`pg_net` jobs, external vision calls, and push delivery consume quotas. The scheduled functions currently enumerate users and process them serially for predictable load; large populations need pagination/queueing and retry backoff.
- Supabase does not provide Firebase Cloud Messaging. The migration stores deduplicated `notification_tokens` and `notification_events`. If `PUSH_WEBHOOK_URL` is configured, the webhook receives `{tokens,eventType,payload}`; otherwise events are recorded but no device push is sent. Supply an authorized FCM HTTP v1/APNs adapter before relying on reminders or accountability notifications.
- Resolving an accountability phone currently uses a server-only paginated Auth Admin lookup (up to 10,000 users). For a larger deployment, add a consented, privacy-preserving phone index rather than exposing an account directory.
- Firebase custom claims do not automatically migrate. Existing admins must sign in with a confirmed allowlisted email and call `claim-admin-role`, or an operator may seed `admin_roles` through a trusted SQL/admin process. Existing Firebase timestamps, nested document IDs, storage URLs, and field names need an explicit data migration; this commit supplies the target schema, not a destructive importer.
- RLS protects normal client access. Edge Functions use the service role for privileged writes, so never expose `SUPABASE_SERVICE_ROLE_KEY` to Flutter, browser code, logs, or the public repository. Review the generated Storage policies and keep evidence buckets private.

## 5. Validation

The repository had no Supabase project or backend test suite before this migration. The new functions are Deno TypeScript and use URL imports for `@supabase/supabase-js`; validate with the Supabase CLI/Deno runtime available in the deployment environment, then exercise auth, RLS, storage, and cron in a staging project. The existing Firebase code remains available for comparison, and no Flutter source or dependency file was changed.


## 6. Building the Flutter client against Supabase

The app no longer contains Firebase config; Supabase project values are
injected at build time via `--dart-define` (see `lib/supabase_config.dart`):

```bash
flutter pub get

flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --split-per-abi
```

Use the **anon/publishable** key here, never the service-role key. For local
runs:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

The `delete-account` function (added alongside the others) lets a signed-in
user permanently delete their own account: it removes their Storage objects
in `food-images`/`fine-proofs`, then deletes the Supabase Auth user, which
cascades to every `user_id`-scoped table via `on delete cascade`. Deploy it
with the rest:

```bash
supabase functions deploy delete-account
```
