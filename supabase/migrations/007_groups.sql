-- 007_groups.sql
-- Group Challenges: groups, membership, daily scoring for accountability leaderboards.

-- Groups table
create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null references public.users(id) on delete cascade,
  invite_code text unique not null,
  max_members integer not null default 10,
  created_at timestamptz not null default now()
);

-- Group members
create table if not exists public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  unique (group_id, user_id)
);

-- Daily scores per member per group
create table if not exists public.group_daily_scores (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  score_date date not null,
  food_logged boolean not null default false,
  pushups_done boolean not null default false,
  protein_hit boolean not null default false,
  total_points integer not null default 0,
  unique (group_id, user_id, score_date)
);

-- Indexes for efficient queries
create index if not exists group_members_group_id_idx on public.group_members (group_id);
create index if not exists group_members_user_id_idx on public.group_members (user_id);
create index if not exists group_daily_scores_group_date_idx on public.group_daily_scores (group_id, score_date);

-- Enable RLS
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_daily_scores enable row level security;

-- RLS Policies: members can read their own group data

-- Groups: users can see groups they belong to
create policy groups_select on public.groups
  for select using (
    id in (select group_id from public.group_members where user_id = auth.uid())
  );

-- Group members: users can see members of groups they belong to
create policy group_members_select on public.group_members
  for select using (
    group_id in (select group_id from public.group_members gm where gm.user_id = auth.uid())
  );

-- Group daily scores: users can see scores for their groups
create policy group_daily_scores_select on public.group_daily_scores
  for select using (
    group_id in (select group_id from public.group_members where user_id = auth.uid())
  );

-- No client insert/update/delete policies - only service_role (Edge Functions) can write.

-- Trigger to enforce max_members atomically (prevents TOCTOU race on concurrent joins)
create or replace function public.enforce_group_max_members()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  current_count integer;
  max_allowed integer;
begin
  select count(*) into current_count
    from public.group_members
    where group_id = new.group_id;

  select max_members into max_allowed
    from public.groups
    where id = new.group_id;

  if current_count >= max_allowed then
    raise exception 'Group has reached its maximum member limit of %', max_allowed;
  end if;

  return new;
end;
$$;

create trigger trg_enforce_group_max_members
  before insert on public.group_members
  for each row execute function public.enforce_group_max_members();
