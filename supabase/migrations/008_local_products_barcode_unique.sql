-- Enforce one row per barcode so the seed load (and crowdsourced upserts) are
-- idempotent and barcode lookups return a single product.
create unique index if not exists local_products_barcode_unique
  on public.local_products (barcode) where barcode is not null;
