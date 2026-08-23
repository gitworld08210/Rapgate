-- 008: Atomic consecutive_misses increment + wire earn_rest_day_pass into bump_pushup_streak
-- Fixes race condition in daily-pushup-check and ensures rest day passes are earned.

-- ============================================================
-- 1. Atomic increment for consecutive_misses
--    Returns the new value after incrementing.
-- ============================================================

CREATE OR REPLACE FUNCTION public.increment_consecutive_misses(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_misses integer;
BEGIN
  UPDATE public.streaks
     SET consecutive_misses = consecutive_misses + 1
   WHERE user_id = p_user_id
  RETURNING consecutive_misses INTO v_new_misses;

  IF NOT FOUND THEN
    -- Ensure a streak row exists and retry
    INSERT INTO public.streaks (user_id, consecutive_misses)
      VALUES (p_user_id, 1)
      ON CONFLICT (user_id) DO UPDATE SET consecutive_misses = streaks.consecutive_misses + 1
      RETURNING consecutive_misses INTO v_new_misses;
  END IF;

  RETURN v_new_misses;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_consecutive_misses(uuid) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_consecutive_misses(uuid) TO service_role;

-- ============================================================
-- 2. Updated bump_pushup_streak that also calls earn_rest_day_pass
--    when the streak crosses a 7-day multiple.
-- ============================================================

CREATE OR REPLACE FUNCTION public.bump_pushup_streak(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_row public.streaks%rowtype;
  today date;
  yesterday date;
  next_streak integer;
BEGIN
  INSERT INTO public.streaks (user_id) VALUES (p_user_id) ON CONFLICT (user_id) DO NOTHING;
  SELECT * INTO current_row FROM public.streaks WHERE user_id = p_user_id FOR UPDATE;

  today := (now() AT TIME ZONE 'Asia/Kolkata')::date;
  yesterday := today - 1;

  IF current_row.last_pushup_date = today THEN
    RETURN;
  END IF;

  next_streak := CASE
    WHEN current_row.last_pushup_date = yesterday THEN current_row.current_pushup_streak + 1
    ELSE 1
  END;

  UPDATE public.streaks
     SET current_pushup_streak = next_streak,
         longest_pushup_streak = GREATEST(longest_pushup_streak, next_streak),
         last_pushup_date = today,
         consecutive_misses = 0
   WHERE user_id = p_user_id;

  -- Update pushup target based on streak
  UPDATE public.users
     SET pushup_target = LEAST(25, 10 + FLOOR(GREATEST(next_streak, 0) / 7.0)::integer)
   WHERE id = p_user_id;

  -- Award a rest day pass when streak crosses a 7-day multiple
  IF next_streak > 0 AND next_streak % 7 = 0 THEN
    PERFORM public.earn_rest_day_pass(p_user_id);
  END IF;
END;
$$;
