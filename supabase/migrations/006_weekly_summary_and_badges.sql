-- 006: Weekly AI health summaries, achievement badges, and meal favorites
-- =========================================================================

-- ==================== HEALTH SUMMARIES ====================
CREATE TABLE IF NOT EXISTS health_summaries (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  week_start  date NOT NULL,
  summary_text text NOT NULL,
  insights    jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_health_summaries_user_week
  ON health_summaries (user_id, week_start DESC);

ALTER TABLE health_summaries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own summaries"
  ON health_summaries FOR SELECT
  USING (auth.uid() = user_id);

-- ==================== ACHIEVEMENTS ====================
CREATE TABLE IF NOT EXISTS achievements (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  badge_key text NOT NULL,
  earned_at timestamptz NOT NULL DEFAULT now(),
  metadata  jsonb DEFAULT '{}'::jsonb,
  UNIQUE (user_id, badge_key)
);

CREATE INDEX idx_achievements_user
  ON achievements (user_id, earned_at DESC);

ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own achievements"
  ON achievements FOR SELECT
  USING (auth.uid() = user_id);

-- ==================== MEAL FAVORITES ====================
CREATE TABLE IF NOT EXISTS meal_favorites (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name           text NOT NULL,
  detected_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  meal_type      text,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_meal_favorites_user
  ON meal_favorites (user_id, created_at DESC);

ALTER TABLE meal_favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own favorites"
  ON meal_favorites FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own favorites"
  ON meal_favorites FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own favorites"
  ON meal_favorites FOR DELETE
  USING (auth.uid() = user_id);

-- ==================== REALTIME ====================
ALTER PUBLICATION supabase_realtime ADD TABLE health_summaries;
ALTER PUBLICATION supabase_realtime ADD TABLE achievements;
ALTER PUBLICATION supabase_realtime ADD TABLE meal_favorites;
