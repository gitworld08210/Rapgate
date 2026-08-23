-- App-wide settings (singleton row)
CREATE TABLE public.app_settings (
  id             integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  upi_id         text NOT NULL DEFAULT 'yourname@upi',
  upi_payee_name text NOT NULL DEFAULT 'RepGate',
  fine_amount_paise integer NOT NULL DEFAULT 5000 CHECK (fine_amount_paise > 0),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  updated_by     uuid REFERENCES auth.users(id)
);

-- Enable Row Level Security
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can read settings
CREATE POLICY "Authenticated users can read app_settings"
  ON public.app_settings
  FOR SELECT
  TO authenticated
  USING (true);

-- No INSERT/UPDATE/DELETE policies for clients.
-- Admin writes go through Edge Functions using service_role which bypasses RLS.

-- Seed the singleton row
INSERT INTO public.app_settings (id) VALUES (1);

-- Auto-update updated_at on modification (reuses existing trigger function)
CREATE TRIGGER set_app_settings_updated_at
  BEFORE UPDATE ON public.app_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();
