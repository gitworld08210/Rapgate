-- Crowdsourced / seeded packaged-food nutrition cache.
-- Referenced by search-food-by-barcode and scan-food-image edge functions and
-- by migration 003 (match_product_by_name). It was missing from the original
-- migrations, so barcode lookup and the AI cache both failed on a fresh DB.
create table if not exists public.local_products (
  id uuid primary key default gen_random_uuid(),
  barcode text,
  brand text not null default '',
  product_name text not null default '',
  category text not null default '',
  serving_g numeric not null default 100,
  calories numeric not null default 0,
  protein numeric not null default 0,
  carbs numeric not null default 0,
  fat numeric not null default 0,
  fiber numeric not null default 0,
  sodium_mg numeric not null default 0,
  search_key text,
  source text not null default 'seed',
  created_at timestamptz not null default now()
);

create index if not exists local_products_barcode_idx on public.local_products (barcode) where barcode is not null;

-- Read-only reference data for signed-in users; writes happen through edge
-- functions using the service role (which bypasses RLS).
alter table public.local_products enable row level security;
create policy local_products_select on public.local_products for select to authenticated using (true);
