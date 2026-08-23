-- 005: Rest day passes (streak shields) & custom water target
-- Adds rest_day_passes to streaks and daily_water_target_ml to users.
-- Creates server-side functions for earning/using rest day passes.

-- ============================================================
-- Column additions
-- ============================================================

ALTER TABLE streaks
  ADD COLUMN IF NOT EXISTS rest_day_passes integer NOT NULL DEFAULT 0;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS daily_water_target_ml integer NOT NULL DEFAULT 3000
    CHECK (daily_water_target_ml BETWEEN 500 AND 10000);

-- ============================================================
-- earn_rest_day_pass: Called by daily-pushup-check when streak % 7 == 0
-- Caps stored passes at 3.
-- ============================================================

CREATE OR REPLACE FUNCTION earn_rest_day_pass(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_streak integer;
  v_passes integer;
BEGIN
  SELECT current_pushup_streak, rest_day_passes
    INTO v_streak, v_passes
    FROM streaks
   WHERE user_id = p_user_id
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No streak record for user %', p_user_id;
  END IF;

  -- Only award if streak is a multiple of 7 and passes < 3
  IF v_streak > 0 AND v_streak % 7 = 0 AND v_passes < 3 THEN
    UPDATE streaks
       SET rest_day_passes = rest_day_passes + 1
     WHERE user_id = p_user_id;
    RETURN v_passes + 1;
  END IF;

  RETURN v_passes;
END;
$$;

-- ============================================================
-- use_rest_day_pass: Decrements a pass and inserts an exempt session
-- ============================================================

CREATE OR REPLACE FUNCTION use_rest_day_pass(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_passes integer;
BEGIN
  SELECT rest_day_passes
    INTO v_passes
    FROM streaks
   WHERE user_id = p_user_id
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No streak record for user %', p_user_id;
  END IF;

  IF v_passes <= 0 THEN
    RAISE EXCEPTION 'No rest day passes available.';
  END IF;

  -- Decrement pass
  UPDATE streaks
     SET rest_day_passes = rest_day_passes - 1
   WHERE user_id = p_user_id;

  -- Insert an exempt pushup session for today
  INSERT INTO pushup_sessions (
    user_id, status, rep_count, reason,
    started_at, completed_at
  ) VALUES (
    p_user_id, 'verified', 0, 'rest_day_pass',
    now(), now()
  );

  RETURN v_passes - 1;
END;
$$;
