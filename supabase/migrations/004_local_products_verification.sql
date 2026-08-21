-- Migration 004: Add verification/source tracking to local_products
-- Prevents unverified AI estimates from being treated as trusted nutrition data.

-- Add source tracking and verification columns
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'local_products' AND column_name = 'source'
  ) THEN
    ALTER TABLE public.local_products ADD COLUMN source text NOT NULL DEFAULT 'seed_data';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'local_products' AND column_name = 'confidence'
  ) THEN
    ALTER TABLE public.local_products ADD COLUMN confidence numeric NOT NULL DEFAULT 1.0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'local_products' AND column_name = 'verified'
  ) THEN
    ALTER TABLE public.local_products ADD COLUMN verified boolean NOT NULL DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'local_products' AND column_name = 'verified_by'
  ) THEN
    ALTER TABLE public.local_products ADD COLUMN verified_by uuid REFERENCES auth.users(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'local_products' AND column_name = 'verified_at'
  ) THEN
    ALTER TABLE public.local_products ADD COLUMN verified_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'local_products' AND column_name = 'added_by'
  ) THEN
    ALTER TABLE public.local_products ADD COLUMN added_by uuid REFERENCES auth.users(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'local_products' AND column_name = 'created_at'
  ) THEN
    ALTER TABLE public.local_products ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
  END IF;
END;
$$;

-- Add CHECK constraint on source values
ALTER TABLE public.local_products DROP CONSTRAINT IF EXISTS local_products_source_check;
ALTER TABLE public.local_products ADD CONSTRAINT local_products_source_check
  CHECK (source IN ('seed_data', 'gemini_scan', 'label_scan', 'user_correction', 'open_food_facts', 'admin_verified'));

-- Add CHECK constraint on confidence range
ALTER TABLE public.local_products DROP CONSTRAINT IF EXISTS local_products_confidence_check;
ALTER TABLE public.local_products ADD CONSTRAINT local_products_confidence_check
  CHECK (confidence >= 0 AND confidence <= 1);

-- Mark all existing seed data as verified (they came from verified sources)
UPDATE public.local_products
SET verified = true, source = 'seed_data', confidence = 1.0
WHERE source = 'seed_data' AND verified_at IS NULL;

-- Update the match_product_by_name function to prefer verified products
-- and require a higher similarity threshold (0.6 instead of 0.4)
CREATE OR REPLACE FUNCTION public.match_product_by_name(search_text text)
RETURNS TABLE(
  id bigint,
  barcode text,
  brand text,
  product_name text,
  category text,
  serving_g numeric,
  calories numeric,
  protein numeric,
  carbs numeric,
  fat numeric,
  fiber numeric,
  sodium_mg numeric,
  search_key text,
  source text,
  confidence numeric,
  verified boolean,
  verified_by uuid,
  verified_at timestamptz,
  added_by uuid,
  created_at timestamptz,
  similarity_score real
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    lp.*,
    similarity(lp.search_key, search_text) AS similarity_score
  FROM public.local_products lp
  WHERE similarity(lp.search_key, search_text) > 0.6
  ORDER BY
    -- Prefer verified products over unverified
    lp.verified DESC,
    -- Then by similarity
    similarity(lp.search_key, search_text) DESC
  LIMIT 3;
$$;

-- RLS: Remove all client INSERT/UPDATE on local_products.
-- Only service_role (Edge Functions) can write to this table.
ALTER TABLE public.local_products ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read products (needed for lookups)
DROP POLICY IF EXISTS local_products_select ON public.local_products;
CREATE POLICY local_products_select ON public.local_products
  FOR SELECT USING (true);

-- No INSERT/UPDATE/DELETE policies for authenticated role.
-- All writes go through Edge Functions using service_role.
DROP POLICY IF EXISTS local_products_insert ON public.local_products;
DROP POLICY IF EXISTS local_products_update ON public.local_products;
DROP POLICY IF EXISTS local_products_delete ON public.local_products;

-- Revoke direct INSERT/UPDATE/DELETE from authenticated users
REVOKE INSERT, UPDATE, DELETE ON public.local_products FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.local_products FROM anon;

-- Grant full access to service_role (Edge Functions)
GRANT ALL ON public.local_products TO service_role;
