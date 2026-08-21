#!/usr/bin/env python3
"""
Builds a local reference dataset of Indian packaged snacks from Open Food
Facts, normalized to a 50 g portion (RepGate's default packaged-food
portion size — see lib/screens/food/food_details_screen.dart).

This is adapted from a user-supplied script with two real bugs fixed:

1. Wrong endpoint. `in.openfoodfacts.org/category/snacks.json` is the
   HTML site's category page, not a stable JSON API — it returned HTTP
   503 with an HTML "temporarily unavailable" page in testing, not JSON.
   The documented JSON search API lives on `world.openfoodfacts.org`,
   filtered with `countries_tags=india`.

2. Silent zero-calorie bug. `nutriments.get("energy-kcal_100g", 0)`
   defaults to 0 whenever a product only publishes energy in kJ (no kcal
   field) — 2 of 50 sampled India-snacks products hit this, including
   "POTATO WAFERS" and "Oreo choco". This is the exact bug class already
   fixed server-side in supabase/functions/search-food-by-barcode: it
   silently records a real food as 0 kcal instead of converting kJ to
   kcal (÷4.184). Fixed the same way here for consistency.

Usage:  python3 tool/fetch_indian_snacks.py [--pages 20] [--page-size 100]
"""

from __future__ import annotations

import argparse
import csv
import json
import time
import urllib.error
import urllib.request

API_URL = "https://world.openfoodfacts.org/api/v2/search"
FIELDS = "code,brands,product_name,nutriments"
USER_AGENT = "RepGate-DataTool/1.0 (contact: adit080210@gmail.com)"
KJ_TO_KCAL = 4.184


def fetch_page(page: int, page_size: int) -> list[dict]:
    """One page of India-tagged snacks, with retry on the API's frequent 503s."""
    query = (
        f"{API_URL}?categories_tags=snacks&countries_tags=india"
        f"&page={page}&page_size={page_size}&fields={FIELDS}"
    )
    request = urllib.request.Request(query, headers={"User-Agent": USER_AGENT})

    delays = (1, 3, 6)
    for attempt, delay in enumerate((0, *delays)):
        if delay:
            time.sleep(delay)
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return json.loads(response.read().decode()).get("products", [])
        except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError) as error:
            print(f"  page {page}: attempt {attempt + 1} failed ({error}); retrying")
    print(f"  page {page}: giving up after {len(delays) + 1} attempts")
    return []


def energy_kcal_100g(nutriments: dict) -> float:
    """kcal per 100 g, converting from kJ when only kJ is published."""
    kcal = nutriments.get("energy-kcal_100g")
    if isinstance(kcal, (int, float)):
        return float(kcal)
    kj = nutriments.get("energy-kj_100g", nutriments.get("energy_100g"))
    return round(float(kj) / KJ_TO_KCAL, 1) if isinstance(kj, (int, float)) else 0.0


def to_50g_row(product: dict) -> dict:
    nutriments = product.get("nutriments", {}) or {}

    def scaled(key: str) -> float:
        value = nutriments.get(key)
        return round(float(value) / 2, 1) if isinstance(value, (int, float)) else 0.0

    return {
        "barcode": product.get("code", ""),
        "brand": product.get("brands") or "Unknown",
        "product_name": product.get("product_name") or "Unknown",
        "serving_size_g": 50,
        "calories_kcal": round(energy_kcal_100g(nutriments) / 2, 1),
        "protein_g": scaled("proteins_100g"),
        "carbs_g": scaled("carbohydrates_100g"),
        "fat_g": scaled("fat_100g"),
        "fiber_g": scaled("fiber_100g"),
        # sodium_100g is published in grams per 100 g, so *1000 (g -> mg) * 0.5
        # (100 g -> 50 g) collapses to *500 — same result as the source script.
        "sodium_mg": round(float(nutriments.get("sodium_100g", 0) or 0) * 500, 1),
    }


def fetch_indian_snacks(page_count: int, page_size: int, out_path: str) -> None:
    rows: dict[str, dict] = {}  # keyed by barcode to drop duplicates across pages
    for page in range(1, page_count + 1):
        products = fetch_page(page, page_size)
        if not products:
            print(f"page {page}: 0 products (rate-limited or end of results)")
            continue
        for product in products:
            row = to_50g_row(product)
            key = row["barcode"] or f"unbarcoded-{len(rows)}"
            rows.setdefault(key, row)
        print(f"page {page}: +{len(products)} (total so far {len(rows)})")
        time.sleep(1)  # be a polite API citizen; OFF rate-limits aggressively

    with open(out_path, "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=list(next(iter(rows.values())).keys()) if rows else [])
        writer.writeheader()
        writer.writerows(rows.values())

    zero_calorie = sum(1 for row in rows.values() if row["calories_kcal"] == 0)
    print(f"Exported {len(rows)} unique products to {out_path}")
    if zero_calorie:
        print(
            f"Note: {zero_calorie} product(s) have 0 kcal because Open Food Facts "
            "has no energy data for them at all (not a bug — genuinely missing)."
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pages", type=int, default=20)
    parser.add_argument("--page-size", type=int, default=100)
    parser.add_argument("--out", default="indian_snacks_database.csv")
    args = parser.parse_args()
    fetch_indian_snacks(args.pages, args.page_size, args.out)
