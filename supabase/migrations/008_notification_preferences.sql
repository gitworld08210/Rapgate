-- Notification preferences for smart push notifications.
-- Each user can opt in/out of individual notification categories.

CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id         uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  lunch_reminder  boolean NOT NULL DEFAULT true,
  pushup_reminder boolean NOT NULL DEFAULT true,
  streak_alerts   boolean NOT NULL DEFAULT true,
  protein_tips    boolean NOT NULL DEFAULT true,
  weekly_summary  boolean NOT NULL DEFAULT true,
  preferred_workout_hour int,  -- 0-23, auto-detected from pushup_sessions if null
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- RLS: users can read and update their own row only.
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notification preferences"
  ON notification_preferences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notification preferences"
  ON notification_preferences FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can insert own notification preferences"
  ON notification_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Auto-create a default preferences row when a new user signs up.
-- This appends to the existing handle_new_auth_user trigger function.
CREATE OR REPLACE FUNCTION create_notification_preferences()
RETURNS trigger AS $$
BEGIN
  INSERT INTO notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_user_created_notification_prefs
  AFTER INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION create_notification_preferences();

-- Backfill existing users who don't have preferences yet.
INSERT INTO notification_preferences (user_id)
SELECT id FROM users
WHERE id NOT IN (SELECT user_id FROM notification_preferences)
ON CONFLICT (user_id) DO NOTHING;
