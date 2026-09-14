-- Scheduled report emails via pg_cron + pg_net.
-- Weekly: every Monday 08:30 IST (03:00 UTC). Monthly: 1st of month 09:00 IST (03:30 UTC).
-- The Edge Function URL is public; x-cron-secret is validated inside the function.
-- Store the project URL and the cron secret in Vault. The cron secret MUST match
-- the CRON_SECRET edge-function secret (set that in the Supabase dashboard).
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Seed Vault entries if absent (idempotent). Replace the cron secret value with
-- the real CRON_SECRET after setting it as an Edge Function secret, e.g.:
--   select vault.update_secret((select id from vault.secrets where name='rapgate_cron_secret'), '<real-secret>');
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'rapgate_supabase_url') then
    perform vault.create_secret('https://YOUR_PROJECT_REF.supabase.co', 'rapgate_supabase_url');
  end if;
  if not exists (select 1 from vault.secrets where name = 'rapgate_cron_secret') then
    perform vault.create_secret('replace-with-the-value-of-CRON_SECRET', 'rapgate_cron_secret');
  end if;
end $$;

-- Weekly report sweep: Mondays 03:00 UTC (08:30 IST).
select cron.schedule(
  'rapgate-weekly-report',
  '0 3 * * 1',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'rapgate_supabase_url') || '/functions/v1/send-weekly-report',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'rapgate_cron_secret')),
    body := '{}'::jsonb
  );
  $$
);

-- Monthly report sweep: 1st of month 03:30 UTC (09:00 IST).
select cron.schedule(
  'rapgate-monthly-report',
  '30 3 1 * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'rapgate_supabase_url') || '/functions/v1/send-monthly-report',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'rapgate_cron_secret')),
    body := '{}'::jsonb
  );
  $$
);
