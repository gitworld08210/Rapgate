-- 006_referrals.sql
-- Referral system: unique codes per user, referral tracking, 7-day fine waiver reward.

-- Add referral_code column to users table
alter table public.users add column if not exists referral_code text unique;

-- Create index on referral_code for fast lookups
create index if not exists users_referral_code_idx on public.users (referral_code) where referral_code is not null;

-- Referrals tracking table
create table if not exists public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid not null references public.users(id) on delete cascade,
  referee_id uuid references public.users(id) on delete set null,
  code text not null,
  status text not null default 'pending' check (status in ('pending', 'completed', 'rewarded')),
  reward_type text not null default 'fine_waiver_7d',
  created_at timestamptz not null default now()
);

-- Enforce that a user can only be referred once (prevents double-apply race condition)
alter table public.referrals add constraint referrals_referee_unique unique (referee_id);

create index if not exists referrals_referrer_id_idx on public.referrals (referrer_id);
create index if not exists referrals_code_idx on public.referrals (code);

-- RLS for referrals table
alter table public.referrals enable row level security;

create policy referrals_select on public.referrals
  for select using (referrer_id = auth.uid() or referee_id = auth.uid() or public.has_admin_role());

-- No client insert/update/delete - only service_role (Edge Functions) can write.

-- Update the unlock_source check constraint to include 'referral_reward'
alter table public.blocked_apps_config
  drop constraint if exists blocked_apps_config_unlock_source_check;

alter table public.blocked_apps_config
  add constraint blocked_apps_config_unlock_source_check
  check (unlock_source is null or unlock_source in ('pushup_verified', 'fine_paid', 'emergency', 'referral_reward'));

-- Function to generate a referral code: first 4 chars of name (uppercased, padded) + 4 random digits
create or replace function public.generate_referral_code(p_user_id uuid, p_name text)
returns text language plpgsql security definer set search_path = public as $$
declare
  prefix text;
  code text;
  attempts integer := 0;
begin
  -- Take first 4 chars of name, uppercase, pad with X if name is short
  prefix := upper(left(regexp_replace(coalesce(p_name, ''), '[^a-zA-Z]', '', 'g'), 4));
  if length(prefix) < 4 then
    prefix := rpad(prefix, 4, 'X');
  end if;

  -- Generate unique code with random 4-digit suffix
  loop
    code := prefix || lpad((floor(random() * 10000))::integer::text, 4, '0');
    -- Check uniqueness
    if not exists (select 1 from public.users where referral_code = code) then
      return code;
    end if;
    attempts := attempts + 1;
    if attempts > 100 then
      -- Fallback: use more random chars
      code := prefix || lpad((floor(random() * 100000))::integer::text, 5, '0');
      return code;
    end if;
  end loop;
end;
$$;

-- Update handle_new_auth_user to also generate a referral code
create or replace function public.handle_new_auth_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  user_name text;
  ref_code text;
begin
  user_name := coalesce(new.raw_user_meta_data ->> 'name', '');
  ref_code := public.generate_referral_code(new.id, user_name);

  insert into public.users (id, name, referral_code)
    values (new.id, user_name, ref_code)
    on conflict (id) do update set referral_code = coalesce(public.users.referral_code, excluded.referral_code);

  insert into public.streaks (user_id) values (new.id) on conflict (user_id) do nothing;
  insert into public.blocked_apps_config (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

-- Backfill referral codes for existing users who do not have one
do $$
declare
  r record;
begin
  for r in select id, name from public.users where referral_code is null
  loop
    update public.users
      set referral_code = public.generate_referral_code(r.id, r.name)
      where id = r.id;
  end loop;
end;
$$;

-- Leaderboard function: top 10 users by completed referral count
create or replace function public.get_referral_leaderboard()
returns table(user_id uuid, name text, referral_count bigint)
language sql stable security definer set search_path = public as $$
  select r.referrer_id as user_id, u.name, count(*) as referral_count
  from public.referrals r
  join public.users u on u.id = r.referrer_id
  where r.status in ('completed', 'rewarded')
  group by r.referrer_id, u.name
  order by referral_count desc
  limit 10;
$$;

-- Revoke direct access to generate_referral_code from public roles
revoke all on function public.generate_referral_code(uuid, text) from public, anon, authenticated;
grant execute on function public.generate_referral_code(uuid, text) to service_role;

-- Leaderboard is called by the Edge Function via service_role, not by clients directly
revoke all on function public.get_referral_leaderboard() from public, anon, authenticated;
grant execute on function public.get_referral_leaderboard() to service_role;
