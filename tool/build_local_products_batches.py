#!/usr/bin/env python3
"""Transform the 50k Indian snacks SQL dump into local_products INSERT batches.

Source table `snacks` columns:
  barcode, brand, product_name, category, serving_size_g,
  calories_kcal, protein_g, carbohydrates_g, fat_g, fiber_g, sodium_mg

Target `public.local_products` columns:
  barcode, brand, product_name, category, serving_g,
  calories, protein, carbs, fat, fiber, sodium_mg, search_key, source

Output: batched multi-row INSERT statements under tool/lp_batches/, each with
an ON CONFLICT DO NOTHING so re-runs are idempotent (barcode is de-duped by a
unique constraint we add before loading).
"""
import os
import re
import sys

SRC = "Indian_Snacks_Database_50000.sql"
OUT_DIR = "tool/lp_batches"
BATCH = 1000  # rows per INSERT statement

# Matches one VALUES tuple line, e.g.
# ('8904...', 'Haldiram''s', 'Bhujia Sev (Classic)', 'Namkeen', 50, 290.0, 6.5, 21.0, 20.5, 2.5, 380.0),
TUPLE_RE = re.compile(r"^\((.*)\)\s*,?\s*$")


def split_values(body: str):
    """Split a SQL tuple body on commas that are not inside single-quoted
    strings. SQL escapes a quote by doubling it ('') which we preserve."""
    parts, buf, i, n, in_str = [], [], 0, len(body), False
    while i < n:
        c = body[i]
        if c == "'":
            if in_str and i + 1 < n and body[i + 1] == "'":
                buf.append("''")
                i += 2
                continue
            in_str = not in_str
            buf.append(c)
        elif c == "," and not in_str:
            parts.append("".join(buf).strip())
            buf = []
        else:
            buf.append(c)
        i += 1
    if buf:
        parts.append("".join(buf).strip())
    return parts


def unquote(v: str) -> str:
    v = v.strip()
    if v.startswith("'") and v.endswith("'"):
        return v[1:-1].replace("''", "'")
    return v


def q(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def num(v: str, default: str = "0") -> str:
    v = v.strip()
    if v == "" or v.upper() == "NULL":
        return default
    try:
        float(v)
        return v
    except ValueError:
        return default


def main():
    if not os.path.exists(SRC):
        print(f"source not found: {SRC}", file=sys.stderr)
        sys.exit(1)
    os.makedirs(OUT_DIR, exist_ok=True)

    rows = []
    with open(SRC, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.startswith("('"):
                continue
            m = TUPLE_RE.match(line)
            if not m:
                continue
            cols = split_values(m.group(1))
            if len(cols) < 11:
                continue
            barcode = unquote(cols[0])
            brand = unquote(cols[1])
            product_name = unquote(cols[2])
            category = unquote(cols[3])
            serving_g = num(cols[4], "50")
            calories = num(cols[5])
            protein = num(cols[6])
            carbs = num(cols[7])
            fat = num(cols[8])
            fiber = num(cols[9])
            sodium = num(cols[10])
            search_key = f"{brand} {product_name}".strip().lower()
            rows.append(
                "(" + ", ".join([
                    q(barcode), q(brand), q(product_name), q(category),
                    serving_g, calories, protein, carbs, fat, fiber, sodium,
                    q(search_key), "'seed'",
                ]) + ")"
            )

    print(f"parsed rows: {len(rows)}")

    header = (
        "insert into public.local_products "
        "(barcode, brand, product_name, category, serving_g, calories, "
        "protein, carbs, fat, fiber, sodium_mg, search_key, source) values\n"
    )
    n_batches = 0
    for start in range(0, len(rows), BATCH):
        chunk = rows[start:start + BATCH]
        # Use bare ON CONFLICT DO NOTHING (no arbiter) so it works with the
        # partial unique index on barcode without predicate-matching issues.
        stmt = header + ",\n".join(chunk) + "\non conflict do nothing;\n"
        path = os.path.join(OUT_DIR, f"batch_{n_batches:04d}.sql")
        with open(path, "w", encoding="utf-8") as out:
            out.write(stmt)
        n_batches += 1
    print(f"wrote {n_batches} batches to {OUT_DIR}/ ({BATCH} rows each)")


if __name__ == "__main__":
    main()
