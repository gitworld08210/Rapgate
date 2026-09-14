-- ==========================================================================
-- Email OTP (Azure-delivered) + report email support
-- ==========================================================================

-- Passwordless email OTP codes. Codes are stored ONLY as a SHA-256 hash; the
-- plaintext code lives only in the Azure-delivered email. All access is via
-- Edge Functions using the service role, so no client RLS policies exist.
create table if not exists public.email_otps (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  code_hash text not null,
  purpose text not null default 'auth' check (purpose in ('auth')),
  attempts integer not null default 0 check (attempts >= 0),
  max_attempts integer not null default 5 check (max_attempts > 0),
  consumed_at timestamptz,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  ip inet
);

create index if not exists email_otps_email_created_idx
  on public.email_otps (lower(email), created_at desc);
create index if not exists email_otps_expires_idx on public.email_otps (expires_at);

alter table public.email_otps enable row level security;
-- No policies: only the service role (Edge Functions) may touch this table.

-- Deletes expired / consumed OTP rows. Called by the OTP functions and can be
-- scheduled. SECURITY DEFINER so it runs regardless of caller.
create or replace function public.purge_expired_email_otps() returns void
language sql security definer set search_path = public as $$
  delete from public.email_otps
  where expires_at < now() - interval '1 day' or consumed_at is not null;
$$;
revoke all on function public.purge_expired_email_otps() from public, anon, authenticated;
grant execute on function public.purge_expired_email_otps() to service_role;

-- --------------------------------------------------------------------------
-- Report email support on the users profile
-- --------------------------------------------------------------------------
-- The Flutter client never writes these directly; the report scheduler reads
-- the email from auth.users, but we also cache a contactable email and opt-in
-- flags here so a single query drives the weekly/monthly sweep.
alter table public.users
  add column if not exists report_email text,
  add column if not exists weekly_report_opt_in boolean not null default true,
  add column if not exists monthly_report_opt_in boolean not null default true,
  add column if not exists last_weekly_report_at timestamptz,
  add column if not exists last_monthly_report_at timestamptz;

-- Keep the server-owned report timestamps out of client reach.
create or replace function public.protect_users_report_fields() returns trigger
language plpgsql as $$
begin
  if auth.role() <> 'service_role' and not public.has_admin_role(auth.uid()) and (
    new.last_weekly_report_at is distinct from old.last_weekly_report_at
    or new.last_monthly_report_at is distinct from old.last_monthly_report_at
    or new.report_email is distinct from old.report_email
  ) then
    raise exception 'report delivery fields are server-owned';
  end if;
  return new;
end;
$$;
drop trigger if exists users_report_fields on public.users;
create trigger users_report_fields before update on public.users
  for each row execute procedure public.protect_users_report_fields();
