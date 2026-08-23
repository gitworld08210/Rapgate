-- 007_leaderboard.sql
-- Leaderboard support: display_name_public column + leaderboard function

-- Allow users to opt-in to showing their name publicly on leaderboards
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS display_name_public boolean NOT NULL DEFAULT false;

-- Function: get_leaderboard
-- Returns the authenticated user plus their accountability-linked contacts
-- with current streaks and this week's verified pushup count, ranked by streak then weekly pushups.
CREATE OR REPLACE FUNCTION public.get_leaderboard(p_user_id uuid)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  current_streak int,
  weekly_pushups bigint,
  rank bigint,
  is_current_user boolean
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  week_start timestamptz := date_trunc('week', now());
BEGIN
  RETURN QUERY
  WITH linked_users AS (
    -- The user themselves
    SELECT p_user_id AS uid
    UNION
    -- Users they are linked to (either direction)
    SELECT al.contact_id AS uid
    FROM public.accountability_links al
    WHERE al.user_id = p_user_id AND al.status = 'active'
    UNION
    SELECT al.user_id AS uid
    FROM public.accountability_links al
    WHERE al.contact_id = p_user_id AND al.status = 'active'
  ),
  user_stats AS (
    SELECT
      lu.uid,
      COALESCE(u.name, 'Anonymous') AS display_name,
      COALESCE(s.current_pushup_streak, 0) AS current_streak,
      COALESCE(wp.weekly_count, 0)::bigint AS weekly_pushups,
      (lu.uid = p_user_id) AS is_current_user
    FROM linked_users lu
    LEFT JOIN public.users u ON u.id = lu.uid
    LEFT JOIN public.streaks s ON s.user_id = lu.uid
    LEFT JOIN LATERAL (
      SELECT COUNT(*)::bigint AS weekly_count
      FROM public.pushup_sessions ps
      WHERE ps.user_id = lu.uid
        AND ps.status = 'verified'
        AND ps.rep_count > 0
        AND ps.started_at >= week_start
    ) wp ON true
    WHERE u.display_name_public = true OR lu.uid = p_user_id
  )
  SELECT
    us.uid AS user_id,
    us.display_name,
    us.current_streak::int,
    us.weekly_pushups,
    ROW_NUMBER() OVER (
      ORDER BY us.current_streak DESC, us.weekly_pushups DESC
    ) AS rank,
    us.is_current_user
  FROM user_stats us
  ORDER BY us.current_streak DESC, us.weekly_pushups DESC;
END;
$$;
