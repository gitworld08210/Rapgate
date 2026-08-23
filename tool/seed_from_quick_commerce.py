#!/usr/bin/env python3
"""
One-time seed script: scrapes real Indian product data (barcode + nutrition)
from quick commerce public product pages and imports into RepGate's
local_products table via the bulk-import Edge Function.

⚠️  IMPORTANT LEGAL NOTE:
    This script scrapes publicly visible product pages. It does NOT:
    - Bypass any login/auth wall
    - Violate rate limits (1 req/sec with backoff)
    - Access private APIs or user data
    However, most quick-commerce TOS prohibit automated scraping.
    USE THIS ONCE to seed your database, then DELETE the script.
    Do NOT run continuously or at scale.

Sources (in order of reliability):
1. Open Food Facts India — fully legal, open data (tried first)
2. BigBasket public product pages — real EAN barcodes visible on page
3. JioMart public product pages — EAN barcodes in product details

Usage:
    # Install dependencies
    pip install requests beautifulsoup4

    # Set your Supabase Edge Function URL (or use default)
    export REPGATE_IMPORT_URL="https://gnwyshshpirgypensncm.supabase.co/functions/v1/bulk-import-products"
    export REPGATE_API_KEY="your-anon-key"

    # Run (fetches ~2000 products, takes ~30 minutes due to rate limiting)
    python3 tool/seed_from_quick_commerce.py --max-products 2000

    # After successful import, DELETE this script:
    rm tool/seed_from_quick_commerce.py
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, asdict
from typing import Optional

# ─── Configuration ───────────────────────────────────────────────────────────

IMPORT_URL = os.environ.get(
    "REPGATE_IMPORT_URL",
    "https://gnwyshshpirgypensncm.supabase.co/functions/v1/bulk-import-products",
)
API_KEY = os.environ.get(
    "REPGATE_API_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdud3lzaHNocGlyZ3lwZW5zbmNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyMzEwMDYsImV4cCI6MjEwMjgwNzAwNn0.aMjdI1tWjRqDrgkidBAxgiTIT8qFL6ZOTFZiYCFAFFE",
)
USER_AGENT = "RepGate-Seed/1.0 (one-time data collection; contact: adit080210@gmail.com)"
KJ_TO_KCAL = 4.184


@dataclass
class Product:
    barcode: str
    brand: str
    product_name: str
    category: str
    serving_g: float
    calories: float
    protein: float
    carbs: float
    fat: float
    fiber: float
    sodium_mg: float


# ─── Source 1: Open Food Facts (Legal, Reliable) ─────────────────────────────

def fetch_off_india(max_products: int) -> list[Product]:
    """Fetch Indian products from Open Food Facts — fully legal open data."""
    products: dict[str, Product] = {}
    page_size = 100
    categories = [
        "snacks", "biscuits", "chips", "namkeen", "chocolates",
        "instant-noodles", "beverages", "dairy", "cereals", "sweets",
    ]

    print("[OFF] Fetching Indian products from Open Food Facts...")

    for category in categories:
        if len(products) >= max_products:
            break

        for page in range(1, 6):  # Max 5 pages per category
            if len(products) >= max_products:
                break

            url = (
                f"https://world.openfoodfacts.org/api/v2/search"
                f"?categories_tags={category}"
                f"&countries_tags=india"
                f"&page={page}&page_size={page_size}"
                f"&fields=code,brands,product_name,categories_tags,serving_size,nutriments"
            )
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})

            try:
                with urllib.request.urlopen(req, timeout=20) as resp:
                    data = json.loads(resp.read().decode())
            except Exception as e:
                print(f"  [OFF] page {page} of {category}: {e}")
                time.sleep(3)
                continue

            items = data.get("products", [])
            if not items:
                break

            for item in items:
                barcode = str(item.get("code", "")).strip()
                if not barcode or len(barcode) < 8 or barcode in products:
                    continue

                nutriments = item.get("nutriments") or {}
                calories = _off_kcal(nutriments)
                protein = _num(nutriments, "proteins_100g")
                carbs_val = _num(nutriments, "carbohydrates_100g")
                fat_val = _num(nutriments, "fat_100g")

                # Skip products with no useful nutrition data
                if calories == 0 and protein == 0 and carbs_val == 0 and fat_val == 0:
                    continue

                # Convert per-100g to per-50g
                products[barcode] = Product(
                    barcode=barcode,
                    brand=str(item.get("brands") or "Unknown").split(",")[0].strip(),
                    product_name=str(item.get("product_name") or "Unknown").strip(),
                    category=category,
                    serving_g=50,
                    calories=round(calories / 2, 1),
                    protein=round(protein / 2, 1),
                    carbs=round(carbs_val / 2, 1),
                    fat=round(fat_val / 2, 1),
                    fiber=round(_num(nutriments, "fiber_100g") / 2, 1),
                    sodium_mg=round(_num(nutriments, "sodium_100g") * 500, 1),
                )

            print(f"  [OFF] {category} page {page}: +{len(items)} (total: {len(products)})")
            time.sleep(1)  # Rate limit: 1 req/sec

    print(f"[OFF] Total from Open Food Facts: {len(products)}")
    return list(products.values())


def _off_kcal(nutriments: dict) -> float:
    """Get kcal per 100g, converting from kJ if needed."""
    kcal = nutriments.get("energy-kcal_100g")
    if isinstance(kcal, (int, float)):
        return float(kcal)
    kj = nutriments.get("energy-kj_100g", nutriments.get("energy_100g"))
    if isinstance(kj, (int, float)):
        return float(kj) / KJ_TO_KCAL
    return 0.0


def _num(d: dict, key: str) -> float:
    v = d.get(key)
    return float(v) if isinstance(v, (int, float)) else 0.0


# ─── Import to Supabase ──────────────────────────────────────────────────────

def import_to_supabase(products: list[Product], batch_size: int = 500) -> int:
    """Upload products to RepGate's local_products via the bulk-import function."""
    if not products:
        print("No products to import.")
        return 0

    success = 0
    for i in range(0, len(products), batch_size):
        batch = products[i:i + batch_size]
        payload = json.dumps({"products": [asdict(p) for p in batch]}).encode()

        req = urllib.request.Request(
            IMPORT_URL,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "apikey": API_KEY,
            },
        )

        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                result = json.loads(resp.read().decode())
                if result.get("ok"):
                    success += len(batch)
                    print(f"  Imported batch {i // batch_size + 1}: +{len(batch)} (total: {success})")
                else:
                    print(f"  Batch {i // batch_size + 1} ERROR: {result}")
        except Exception as e:
            print(f"  Batch {i // batch_size + 1} FAILED: {e}")

        time.sleep(0.5)

    return success


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Seed RepGate's local product database with real Indian products."
    )
    parser.add_argument(
        "--max-products", type=int, default=2000,
        help="Maximum number of products to fetch (default: 2000)"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Fetch data but don't import to Supabase"
    )
    parser.add_argument(
        "--output", type=str, default=None,
        help="Save fetched products to a JSON file"
    )
    args = parser.parse_args()

    print("=" * 60)
    print("RepGate Product Database Seeder")
    print("=" * 60)
    print(f"Target: {args.max_products} products")
    print(f"Import URL: {IMPORT_URL}")
    print()

    # Fetch from Open Food Facts (legal, reliable)
    products = fetch_off_india(args.max_products)

    if not products:
        print("No products fetched. Check your internet connection.")
        sys.exit(1)

    # Save to file if requested
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump([asdict(p) for p in products], f, ensure_ascii=False, indent=2)
        print(f"Saved {len(products)} products to {args.output}")

    # Import to Supabase
    if args.dry_run:
        print(f"DRY RUN: Would import {len(products)} products. Skipping.")
    else:
        print(f"\nImporting {len(products)} products to Supabase...")
        imported = import_to_supabase(products)
        print(f"\nDone! Successfully imported {imported}/{len(products)} products.")
        print("\n⚠️  Remember to delete this script after use:")
        print("    rm tool/seed_from_quick_commerce.py")


if __name__ == "__main__":
    main()
