-- Rapgate / HealthPush Supabase migration
-- Server-authoritative outcomes are written by Edge Functions with the service role.
-- Client RLS can only read earned outcomes and write self-reported health data.

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  age integer check (age is null or (age > 0 and age < 130)),
  weight numeric check (weight is null or (weight > 20 and weight < 500)),
  height numeric check (height is null or (height > 50 and height < 300)),
  gender text,
  daily_calorie_target integer,
  daily_protein_target numeric,
  pushup_target integer not null default 10 check (pushup_target between 10 and 25),
  created_at timestamptz not null default now(),
  admin_claim_updated_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  image_path text,
  detected_items jsonb not null default '[]'::jsonb check (jsonb_typeof(detected_items) = 'array' and jsonb_array_length(detected_items) <= 30),
  meal_type text not null default 'snack' check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  logged_at timestamptz not null default now(),
  source text not null default 'manual' check (source in ('manual', 'ai_scan', 'barcode')),
  created_at timestamptz not null default now()
);

create table if not exists public.water_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  amount_ml integer not null check (amount_ml > 0 and amount_ml <= 5000),
  logged_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.weight_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  weight_kg numeric not null check (weight_kg > 20 and weight_kg < 500),
  logged_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.pushup_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'verified', 'rejected')),
  required_reps integer not null check (required_reps between 1 and 100),
  rep_count integer not null default 0 check (rep_count >= 0),
  face_visible_check boolean not null default false,
  angle_valid_check boolean not null default false,
  pose_landmark_summary jsonb,
  verify_state jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  unlock_granted_until timestamptz,
  rejection_reason text,
  version integer not null default 0
);

create table if not exists public.blocked_apps_config (
  user_id uuid primary key references public.users(id) on delete cascade,
  blocked_packages text[] not null default '{}',
  allowlist_packages text[] not null default '{}',
  last_unlocked_at timestamptz,
  unlock_granted_until timestamptz,
  unlock_source text check (unlock_source is null or unlock_source in ('pushup_verified', 'fine_paid', 'emergency')),
  updated_at timestamptz not null default now()
);

create table if not exists public.streaks (
  user_id uuid primary key references public.users(id) on delete cascade,
  current_pushup_streak integer not null default 0 check (current_pushup_streak >= 0),
  longest_pushup_streak integer not null default 0 check (longest_pushup_streak >= 0),
  current_food_log_streak integer not null default 0 check (current_food_log_streak >= 0),
  last_pushup_date date,
  last_food_log_date date,
  updated_at timestamptz not null default now()
);

create table if not exists public.fines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  amount_paise integer not null default 5000 check (amount_paise > 0),
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'submitted', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  upi_utr text,
  screenshot_path text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  review_note text check (review_note is null or char_length(review_note) <= 500)
);

create table if not exists public.emergency_unlocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  reason text,
  granted_until timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create table if not exists public.accountability_links (
  user_id uuid primary key references public.users(id) on delete cascade,
  linked_contact_uid uuid references public.users(id) on delete set null,
  contact_phone text,
  contact_name text,
  notify_on_miss boolean not null default false,
  updated_at timestamptz not null default now()
);

-- This table is the server-side source of truth for admin access. Do not use
-- user-editable user_metadata for authorization.
create table if not exists public.admin_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  granted_at timestamptz not null default now(),
  granted_by uuid references auth.users(id),
  revoked_at timestamptz
);

create table if not exists public.admin_audit (
  id uuid primary key default gen_random_uuid(),
  actor_uid uuid not null references auth.users(id),
  actor_email text,
  action text not null,
  target_uid uuid references auth.users(id),
  target_id text,
  detail jsonb not null default '{}'::jsonb,
  at timestamptz not null default now()
);

create table if not exists public.notification_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  token text not null,
  platform text,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, token)
);

create table if not exists public.notification_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists fines_upi_utr_unique on public.fines (upi_utr) where upi_utr is not null;
create index if not exists food_logs_user_logged_idx on public.food_logs (user_id, logged_at desc);
create index if not exists water_logs_user_logged_idx on public.water_logs (user_id, logged_at desc);
create index if not exists weight_logs_user_logged_idx on public.weight_logs (user_id, logged_at desc);
create index if not exists pushup_sessions_user_status_completed_idx on public.pushup_sessions (user_id, status, completed_at desc);
create index if not exists fines_user_status_created_idx on public.fines (user_id, status, created_at desc);
create index if not exists fines_status_reviewed_idx on public.fines (status, reviewed_at desc);
create index if not exists notification_tokens_user_idx on public.notification_tokens (user_id);
create index if not exists accountability_links_notify_idx on public.accountability_links (notify_on_miss) where notify_on_miss = true;
create index if not exists admin_audit_at_idx on public.admin_audit (at desc);

create or replace function public.set_updated_at() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.has_admin_role(p_uid uuid default auth.uid()) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.admin_roles
    where user_id = p_uid and revoked_at is null
  );
$$;

create or replace function public.handle_new_auth_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.users (id, name) values (new.id, coalesce(new.raw_user_meta_data ->> 'name', '')) on conflict (id) do nothing;
  insert into public.streaks (user_id) values (new.id) on conflict (user_id) do nothing;
  insert into public.blocked_apps_config (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_auth_user();

create or replace function public.protect_users_server_fields() returns trigger
language plpgsql as $$
begin
  if new.pushup_target is distinct from old.pushup_target
    or new.admin_claim_updated_at is distinct from old.admin_claim_updated_at
    or new.created_at is distinct from old.created_at then
    if auth.role() <> 'service_role' and not public.has_admin_role(auth.uid()) then
      raise exception 'server-owned user fields cannot be changed by the client';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.protect_blocked_config_server_fields() returns trigger
language plpgsql as $$
begin
  if auth.role() <> 'service_role' and not public.has_admin_role(auth.uid()) and (
    new.last_unlocked_at is distinct from old.last_unlocked_at
    or new.unlock_granted_until is distinct from old.unlock_granted_until
    or new.unlock_source is distinct from old.unlock_source
  ) then
    raise exception 'unlock fields are server-owned';
  end if;
  return new;
end;
$$;

create or replace function public.protect_fine_proof_update() returns trigger
language plpgsql as $$
begin
  if auth.role() <> 'service_role' and not public.has_admin_role(auth.uid()) and (
    new.user_id is distinct from old.user_id
    or new.amount_paise is distinct from old.amount_paise
    or new.reason is distinct from old.reason
    or new.status is distinct from old.status
    or new.created_at is distinct from old.created_at
    or new.submitted_at is distinct from old.submitted_at
    or new.reviewed_at is distinct from old.reviewed_at
    or new.reviewed_by is distinct from old.reviewed_by
    or new.review_note is distinct from old.review_note
  ) then
    raise exception 'fine status and review fields are server-owned';
  end if;
  return new;
end;
$$;

create or replace function public.protect_accountability_link() returns trigger
language plpgsql as $$
begin
  if auth.role() <> 'service_role' and not public.has_admin_role(auth.uid()) and new.linked_contact_uid is distinct from old.linked_contact_uid then
    raise exception 'contact linking is server-owned';
  end if;
  return new;
end;
$$;

drop trigger if exists users_updated_at on public.users;
create trigger users_updated_at before update on public.users for each row execute procedure public.set_updated_at();
drop trigger if exists blocked_apps_updated_at on public.blocked_apps_config;
create trigger blocked_apps_updated_at before update on public.blocked_apps_config for each row execute procedure public.set_updated_at();
drop trigger if exists streaks_updated_at on public.streaks;
create trigger streaks_updated_at before update on public.streaks for each row execute procedure public.set_updated_at();
drop trigger if exists users_server_fields on public.users;
create trigger users_server_fields before update on public.users for each row execute procedure public.protect_users_server_fields();
drop trigger if exists blocked_config_server_fields on public.blocked_apps_config;
create trigger blocked_config_server_fields before update on public.blocked_apps_config for each row execute procedure public.protect_blocked_config_server_fields();
drop trigger if exists fine_proof_update on public.fines;
create trigger fine_proof_update before update on public.fines for each row execute procedure public.protect_fine_proof_update();
drop trigger if exists accountability_link_update on public.accountability_links;
create trigger accountability_link_update before update on public.accountability_links for each row execute procedure public.protect_accountability_link();

-- Atomic server-side push-up state application. The Edge Function owns the
-- anti-cheat calculation; this function owns the row lock and unlock write.
create or replace function public.apply_pushup_batch(
  p_session_id uuid, p_user_id uuid, p_version integer, p_state jsonb,
  p_verdict jsonb, p_complete boolean, p_rep_count integer,
  p_summary jsonb, p_unlock_until timestamptz
) returns table(current_validated_reps integer, session_complete boolean, conflict boolean)
language plpgsql security definer set search_path = public as $$
declare s public.pushup_sessions%rowtype;
begin
  select * into s from public.pushup_sessions where id = p_session_id and user_id = p_user_id for update;
  if not found then raise exception 'session_not_found'; end if;
  if s.status = 'verified' then
    return query select s.rep_count, true, false;
    return;
  end if;
  if s.version <> p_version then
    return query select s.rep_count, false, true;
    return;
  end if;
  if p_complete then
    update public.pushup_sessions set status = 'verified', rep_count = p_rep_count,
      face_visible_check = coalesce((p_verdict ->> 'faceOk')::boolean, false),
      angle_valid_check = coalesce((p_verdict ->> 'angleOk')::boolean, false),
      pose_landmark_summary = p_summary, completed_at = now(),
      unlock_granted_until = p_unlock_until, rejection_reason = null,
      verify_state = null, version = version + 1 where id = p_session_id;
    insert into public.blocked_apps_config (user_id, last_unlocked_at, unlock_granted_until, unlock_source)
      values (p_user_id, now(), p_unlock_until, 'pushup_verified')
      on conflict (user_id) do update set last_unlocked_at = now(), unlock_granted_until = excluded.unlock_granted_until, unlock_source = excluded.unlock_source;
  else
    update public.pushup_sessions set rep_count = p_rep_count,
      face_visible_check = coalesce((p_verdict ->> 'faceOk')::boolean, false),
      angle_valid_check = coalesce((p_verdict ->> 'angleOk')::boolean, false),
      verify_state = p_state,
      rejection_reason = p_verdict ->> 'reason', version = version + 1 where id = p_session_id;
  end if;
  return query select p_rep_count, p_complete, false;
end;
$$;

create or replace function public.bump_pushup_streak(p_user_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare current_row public.streaks%rowtype; today date; yesterday date; next_streak integer;
begin
  insert into public.streaks (user_id) values (p_user_id) on conflict (user_id) do nothing;
  select * into current_row from public.streaks where user_id = p_user_id for update;
  today := (now() at time zone 'Asia/Kolkata')::date; yesterday := today - 1;
  if current_row.last_pushup_date = today then return; end if;
  next_streak := case when current_row.last_pushup_date = yesterday then current_row.current_pushup_streak + 1 else 1 end;
  update public.streaks set current_pushup_streak = next_streak, longest_pushup_streak = greatest(longest_pushup_streak, next_streak), last_pushup_date = today where user_id = p_user_id;
  update public.users set pushup_target = least(25, 10 + floor(greatest(next_streak, 0) / 7.0)::integer) where id = p_user_id;
end;
$$;

create or replace function public.apply_pushup_batch_with_streak(
  p_session_id uuid, p_user_id uuid, p_version integer, p_state jsonb,
  p_verdict jsonb, p_complete boolean, p_rep_count integer,
  p_summary jsonb, p_unlock_until timestamptz
) returns table(current_validated_reps integer, session_complete boolean, conflict boolean)
language plpgsql security definer set search_path = public as $$
declare result_row record;
begin
  select * into result_row from public.apply_pushup_batch(p_session_id, p_user_id, p_version, p_state, p_verdict, p_complete, p_rep_count, p_summary, p_unlock_until);
  if result_row.session_complete then perform public.bump_pushup_streak(p_user_id); end if;
  return query select result_row.current_validated_reps, result_row.session_complete, result_row.conflict;
end;
$$;

create or replace function public.bump_food_streak(p_user_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare current_row public.streaks%rowtype; today date; yesterday date; next_streak integer;
begin
  insert into public.streaks (user_id) values (p_user_id) on conflict (user_id) do nothing;
  select * into current_row from public.streaks where user_id = p_user_id for update;
  today := (now() at time zone 'Asia/Kolkata')::date; yesterday := today - 1;
  if current_row.last_food_log_date = today then return; end if;
  next_streak := case when current_row.last_food_log_date = yesterday then current_row.current_food_log_streak + 1 else 1 end;
  update public.streaks set current_food_log_streak = next_streak, last_food_log_date = today where user_id = p_user_id;
end;
$$;

create or replace function public.insert_food_log_and_bump(
  p_user_id uuid, p_image_path text, p_detected_items jsonb, p_meal_type text, p_source text
) returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  insert into public.food_logs (user_id, image_path, detected_items, meal_type, source)
    values (p_user_id, p_image_path, p_detected_items, p_meal_type, p_source) returning id into new_id;
  perform public.bump_food_streak(p_user_id);
  return new_id;
end;
$$;

create or replace function public.create_fine_if_missing(p_user_id uuid, p_reason text, p_amount_paise integer default 5000)
returns uuid language plpgsql security definer set search_path = public as $$
declare existing_id uuid; new_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text || ':' || p_reason, 0));
  select id into existing_id from public.fines where user_id = p_user_id and reason = p_reason and created_at >= now() - interval '20 hours' order by created_at desc limit 1;
  if existing_id is not null then return existing_id; end if;
  insert into public.fines (user_id, reason, amount_paise) values (p_user_id, p_reason, p_amount_paise) returning id into new_id;
  return new_id;
end;
$$;

create or replace function public.review_fine_atomic(
  p_fine_id uuid, p_target_uid uuid, p_actor_uid uuid, p_approve boolean,
  p_note text, p_unlock_until timestamptz
) returns table(reviewed boolean, approved boolean, unlock_until timestamptz)
language plpgsql security definer set search_path = public as $$
declare current_fine public.fines%rowtype;
begin
  select * into current_fine from public.fines where id = p_fine_id and user_id = p_target_uid for update;
  if not found then raise exception 'fine_not_found'; end if;
  if current_fine.status <> 'submitted' then raise exception 'fine_not_submitted'; end if;
  update public.fines set status = case when p_approve then 'approved' else 'rejected' end,
    reviewed_at = now(), reviewed_by = p_actor_uid, review_note = p_note where id = p_fine_id;
  if p_approve then
    insert into public.blocked_apps_config (user_id, last_unlocked_at, unlock_granted_until, unlock_source)
      values (p_target_uid, now(), p_unlock_until, 'fine_paid')
      on conflict (user_id) do update set last_unlocked_at = now(), unlock_granted_until = excluded.unlock_granted_until, unlock_source = excluded.unlock_source;
  end if;
  insert into public.admin_audit (actor_uid, actor_email, action, target_uid, target_id, detail)
    select p_actor_uid, email, case when p_approve then 'fine_approved' else 'fine_rejected' end, p_target_uid, p_fine_id::text, jsonb_build_object('note', p_note)
    from auth.users where id = p_actor_uid;
  return query select true, p_approve, p_unlock_until;
end;
$$;

create or replace function public.grant_admin_role_atomic(p_user_id uuid, p_email text)
returns table(already_granted boolean) language plpgsql security definer set search_path = public as $$
declare was_active boolean;
begin
  select exists(select 1 from public.admin_roles where user_id = p_user_id and revoked_at is null) into was_active;
  if not was_active then
    insert into public.admin_roles (user_id, email, granted_by, revoked_at) values (p_user_id, lower(p_email), p_user_id, null)
      on conflict (user_id) do update set email = excluded.email, granted_at = now(), granted_by = excluded.granted_by, revoked_at = null;
    update public.users set admin_claim_updated_at = now() where id = p_user_id;
    insert into public.admin_audit (actor_uid, actor_email, action) values (p_user_id, lower(p_email), 'admin_claim_granted');
  end if;
  return query select was_active;
end;
$$;

create or replace function public.revoke_admin_role_atomic(p_actor_uid uuid, p_target_uid uuid)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  update public.admin_roles set revoked_at = now() where user_id = p_target_uid and revoked_at is null;
  insert into public.admin_audit (actor_uid, actor_email, action, target_uid)
    select p_actor_uid, actor.email, 'admin_claim_revoked', p_target_uid from auth.users actor where actor.id = p_actor_uid;
  return true;
end;
$$;

-- RLS ----------------------------------------------------------------------
alter table public.users enable row level security;
alter table public.food_logs enable row level security;
alter table public.water_logs enable row level security;
alter table public.weight_logs enable row level security;
alter table public.pushup_sessions enable row level security;
alter table public.blocked_apps_config enable row level security;
alter table public.streaks enable row level security;
alter table public.fines enable row level security;
alter table public.emergency_unlocks enable row level security;
alter table public.accountability_links enable row level security;
alter table public.admin_roles enable row level security;
alter table public.admin_audit enable row level security;
alter table public.notification_tokens enable row level security;
alter table public.notification_events enable row level security;

create policy users_select on public.users for select using (id = auth.uid() or public.has_admin_role());
create policy users_insert on public.users for insert with check (id = auth.uid() and pushup_target = 10 and admin_claim_updated_at is null);
create policy users_update on public.users for update using (id = auth.uid() or public.has_admin_role()) with check (id = auth.uid() or public.has_admin_role());

create policy food_select on public.food_logs for select using (user_id = auth.uid() or public.has_admin_role());
create policy food_insert on public.food_logs for insert with check (user_id = auth.uid());
create policy food_update on public.food_logs for update using (user_id = auth.uid() or public.has_admin_role()) with check (user_id = auth.uid() or public.has_admin_role());
create policy food_delete on public.food_logs for delete using (user_id = auth.uid() or public.has_admin_role());
create policy water_select on public.water_logs for select using (user_id = auth.uid() or public.has_admin_role());
create policy water_insert on public.water_logs for insert with check (user_id = auth.uid());
create policy water_update on public.water_logs for update using (user_id = auth.uid() or public.has_admin_role()) with check (user_id = auth.uid() or public.has_admin_role());
create policy water_delete on public.water_logs for delete using (user_id = auth.uid() or public.has_admin_role());
create policy weight_select on public.weight_logs for select using (user_id = auth.uid() or public.has_admin_role());
create policy weight_insert on public.weight_logs for insert with check (user_id = auth.uid());
create policy weight_update on public.weight_logs for update using (user_id = auth.uid() or public.has_admin_role()) with check (user_id = auth.uid() or public.has_admin_role());
create policy weight_delete on public.weight_logs for delete using (user_id = auth.uid() or public.has_admin_role());

create policy pushup_select on public.pushup_sessions for select using (user_id = auth.uid() or public.has_admin_role());
create policy blocked_select on public.blocked_apps_config for select using (user_id = auth.uid() or public.has_admin_role());
create policy blocked_insert on public.blocked_apps_config for insert with check (user_id = auth.uid() and last_unlocked_at is null and unlock_granted_until is null and unlock_source is null);
create policy blocked_update on public.blocked_apps_config for update using (user_id = auth.uid() or public.has_admin_role()) with check (user_id = auth.uid() or public.has_admin_role());
create policy streak_select on public.streaks for select using (user_id = auth.uid() or public.has_admin_role());
create policy fines_select on public.fines for select using (user_id = auth.uid() or public.has_admin_role());
-- Proof submissions go through submit-fine-proof so UTR format, uniqueness,
-- and storage ownership are checked before a server-authoritative update.
create policy accountability_select on public.accountability_links for select using (user_id = auth.uid() or public.has_admin_role());
create policy accountability_insert on public.accountability_links for insert with check (user_id = auth.uid() and linked_contact_uid is null);
create policy accountability_update on public.accountability_links for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy accountability_delete on public.accountability_links for delete using (user_id = auth.uid());
create policy admin_roles_select on public.admin_roles for select using (public.has_admin_role());
create policy admin_audit_select on public.admin_audit for select using (public.has_admin_role());
create policy notification_tokens_select on public.notification_tokens for select using (user_id = auth.uid() or public.has_admin_role());
create policy notification_events_select on public.notification_events for select using (user_id = auth.uid() or public.has_admin_role());

-- No client INSERT/UPDATE/DELETE policies exist for push-up sessions, streaks,
-- fines creation/status changes, emergency unlocks, admin roles/audit, or
-- notification events. Edge Functions use the service role.

-- Private evidence buckets. Storage object names must begin with <auth uid>/.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('food-images', 'food-images', false, 8388608, array['image/*']),
  ('fine-proofs', 'fine-proofs', false, 5242880, array['image/*'])
on conflict (id) do update set public = false;

create policy food_objects_select on storage.objects for select using (bucket_id = 'food-images' and (storage.foldername(name))[2] = 'food_images' and ((storage.foldername(name))[1] = auth.uid()::text or public.has_admin_role()));
create policy food_objects_insert on storage.objects for insert with check (bucket_id = 'food-images' and (storage.foldername(name))[2] = 'food_images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy food_objects_update on storage.objects for update using (bucket_id = 'food-images' and (storage.foldername(name))[2] = 'food_images' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id = 'food-images' and (storage.foldername(name))[2] = 'food_images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy food_objects_delete on storage.objects for delete using (bucket_id = 'food-images' and (storage.foldername(name))[2] = 'food_images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy fine_objects_select on storage.objects for select using (bucket_id = 'fine-proofs' and (storage.foldername(name))[2] = 'fine_proofs' and ((storage.foldername(name))[1] = auth.uid()::text or public.has_admin_role()));
create policy fine_objects_insert on storage.objects for insert with check (bucket_id = 'fine-proofs' and (storage.foldername(name))[2] = 'fine_proofs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy fine_objects_update on storage.objects for update using (bucket_id = 'fine-proofs' and (storage.foldername(name))[2] = 'fine_proofs' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id = 'fine-proofs' and (storage.foldername(name))[2] = 'fine_proofs' and (storage.foldername(name))[1] = auth.uid()::text);
-- Fine evidence is intentionally not deletable by clients.

revoke all on public.apply_pushup_batch(uuid, uuid, integer, jsonb, jsonb, boolean, integer, jsonb, timestamptz) from public, anon, authenticated;
revoke all on public.apply_pushup_batch_with_streak(uuid, uuid, integer, jsonb, jsonb, boolean, integer, jsonb, timestamptz) from public, anon, authenticated;
revoke all on public.bump_pushup_streak(uuid) from public, anon, authenticated;
revoke all on public.bump_food_streak(uuid) from public, anon, authenticated;
revoke all on public.insert_food_log_and_bump(uuid, text, jsonb, text, text) from public, anon, authenticated;
revoke all on public.create_fine_if_missing(uuid, text, integer) from public, anon, authenticated;
revoke all on public.review_fine_atomic(uuid, uuid, uuid, boolean, text, timestamptz) from public, anon, authenticated;
revoke all on public.grant_admin_role_atomic(uuid, text) from public, anon, authenticated;
revoke all on public.revoke_admin_role_atomic(uuid, uuid) from public, anon, authenticated;
grant execute on function public.apply_pushup_batch(uuid, uuid, integer, jsonb, jsonb, boolean, integer, jsonb, timestamptz) to service_role;
grant execute on function public.apply_pushup_batch_with_streak(uuid, uuid, integer, jsonb, jsonb, boolean, integer, jsonb, timestamptz) to service_role;
grant execute on function public.bump_pushup_streak(uuid) to service_role;
grant execute on function public.bump_food_streak(uuid) to service_role;
grant execute on function public.insert_food_log_and_bump(uuid, text, jsonb, text, text) to service_role;
grant execute on function public.create_fine_if_missing(uuid, text, integer) to service_role;
grant execute on function public.review_fine_atomic(uuid, uuid, uuid, boolean, text, timestamptz) to service_role;
grant execute on function public.grant_admin_role_atomic(uuid, text) to service_role;
grant execute on function public.revoke_admin_role_atomic(uuid, uuid) to service_role;
