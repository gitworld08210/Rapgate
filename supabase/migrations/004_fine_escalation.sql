-- Fine escalation: consecutive misses increase the fine amount.
-- Adds tracking column and a pure function for computing the escalated fine.

-- 1. Add consecutive_misses column to streaks table
alter table public.streaks
  add column if not exists consecutive_misses integer not null default 0
  check (consecutive_misses >= 0);

-- 2. Pure function that determines the fine amount based on consecutive misses.
--    1 miss  = 5000 paise (₹50)
--    2 misses = 7500 paise (₹75)
--    3+ misses = 10000 paise (₹100)
create or replace function public.compute_escalated_fine(consecutive integer)
returns integer
language sql
immutable
as $$
  select case
    when consecutive <= 1 then 5000
    when consecutive = 2 then 7500
    else 10000
  end;
$$;

-- 3. Update bump_pushup_streak to reset consecutive_misses when user completes push-ups.
--    This ensures the escalation counter resets on successful completion.
create or replace function public.bump_pushup_streak(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare current_row public.streaks%rowtype; today date; yesterday date; next_streak integer;
begin
  insert into public.streaks (user_id) values (p_user_id) on conflict (user_id) do nothing;
  select * into current_row from public.streaks where user_id = p_user_id for update;
  today := current_date;
  yesterday := today - 1;
  next_streak := case when current_row.last_pushup_date = yesterday then current_row.current_pushup_streak + 1 when current_row.last_pushup_date = today then current_row.current_pushup_streak else 1 end;
  update public.streaks
    set current_pushup_streak = next_streak,
        longest_pushup_streak = greatest(longest_pushup_streak, next_streak),
        last_pushup_date = today,
        consecutive_misses = 0
    where user_id = p_user_id;
end;
$$;

-- Grant execute to service_role only (Edge Functions)
revoke all on function public.compute_escalated_fine(integer) from public, anon, authenticated;
grant execute on function public.compute_escalated_fine(integer) to service_role;
