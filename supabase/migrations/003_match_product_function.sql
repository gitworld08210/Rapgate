-- Enable pg_trgm extension for trigram similarity matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Add search_key column to local_products if it does not already exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'local_products'
      AND column_name = 'search_key'
  ) THEN
    ALTER TABLE public.local_products ADD COLUMN search_key text;
  END IF;
END;
$$;

-- Create GIN index on search_key using gin_trgm_ops if it does not already exist
CREATE INDEX IF NOT EXISTS idx_local_products_search_key_trgm
  ON public.local_products USING gin (search_key gin_trgm_ops);

-- Create or replace function to match a product by name using trigram similarity
CREATE OR REPLACE FUNCTION public.match_product_by_name(search_text text)
RETURNS SETOF public.local_products
LANGUAGE sql
STABLE
AS $$
  SELECT *
  FROM public.local_products
  WHERE similarity(search_key, search_text) > 0.3
  ORDER BY similarity(search_key, search_text) DESC
  LIMIT 1;
$$;

-- Backfill existing rows that have an empty or null search_key
UPDATE public.local_products
SET search_key = lower(trim(coalesce(brand, '') || ' ' || coalesce(product_name, '')))
WHERE search_key IS NULL OR search_key = '';
