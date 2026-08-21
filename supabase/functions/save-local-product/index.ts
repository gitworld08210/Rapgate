import {
  adminClient,
  body,
  FunctionError,
  invoke,
  requireUser,
} from "../_shared/common.ts";

/**
 * save-local-product — Server-side product save for crowdsource mechanism.
 *
 * Previously the client inserted directly into local_products, which allowed
 * any authenticated user to write arbitrary nutrition values. This Edge Function
 * validates the input, checks for duplicates, and marks the source properly.
 *
 * Accepts:
 *   barcode?: string       — GTIN barcode (for barcode→label crowdsource)
 *   brand?: string         — Product brand
 *   productName: string    — Product name (required)
 *   calories: number       — kcal
 *   protein: number        — grams
 *   carbs: number          — grams
 *   fat: number            — grams
 *   servingG?: number      — Serving size in grams (default 50)
 *   source: string         — 'label_scan' | 'user_correction'
 */

function clampNum(value: unknown, min: number, max: number): number {
  const n = Number(value);
  if (!Number.isFinite(n)) return 0;
  return Math.max(min, Math.min(max, n));
}

function sanitizeString(value: unknown, maxLen: number): string {
  return String(value ?? "")
    .normalize("NFKC")
    .replace(/[\u0000-\u001F\u007F]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLen);
}

Deno.serve((req) =>
  invoke("save-local-product", req, async (request) => {
    const { user } = await requireUser(request);
    const input = await body(request);

    // ─── Validate inputs ─────────────────────────────────────────────────
    const productName = sanitizeString(input.productName, 100);
    if (!productName) {
      throw new FunctionError(400, "productName is required.");
    }

    const brand = sanitizeString(input.brand, 80);
    const barcode = sanitizeString(input.barcode, 20);
    const source = input.source === "user_correction"
      ? "user_correction"
      : "label_scan";

    const calories = clampNum(input.calories, 0, 5000);
    const protein = clampNum(input.protein, 0, 500);
    const carbs = clampNum(input.carbs, 0, 500);
    const fat = clampNum(input.fat, 0, 500);
    const servingG = clampNum(input.servingG || 50, 1, 5000);

    // Basic sanity: at least one macro should be non-zero
    if (calories === 0 && protein === 0 && carbs === 0 && fat === 0) {
      throw new FunctionError(
        400,
        "All nutrition values are zero. Please check the label values.",
      );
    }

    // ─── Duplicate check ─────────────────────────────────────────────────
    // If a barcode is provided, check if a verified product already exists
    if (barcode) {
      const { data: existing } = await adminClient
        .from("local_products")
        .select("id, verified")
        .eq("barcode", barcode)
        .maybeSingle();

      if (existing?.verified) {
        // Already have a verified product for this barcode — skip
        console.log(
          `[save-product] Barcode ${barcode} already verified, skipping`,
        );
        return { saved: false, reason: "Product already exists and is verified." };
      }

      // If unverified exists, update it with the new (presumably better) data
      if (existing) {
        const { error } = await adminClient
          .from("local_products")
          .update({
            brand,
            product_name: productName,
            calories,
            protein,
            carbs,
            fat,
            serving_g: servingG,
            source,
            confidence: source === "label_scan" ? 0.9 : 0.85,
            verified: source === "label_scan", // Label scans are more reliable
            verified_by: source === "label_scan" ? user.id : null,
            verified_at: source === "label_scan" ? new Date().toISOString() : null,
            added_by: user.id,
            search_key: (brand + " " + productName).toLowerCase().trim(),
          })
          .eq("id", existing.id);

        if (error) {
          console.warn("[save-product] Update failed:", error.message);
          throw new FunctionError(500, "Could not update product.");
        }

        console.log(`[save-product] Updated barcode ${barcode}: ${productName}`);
        return { saved: true, updated: true };
      }
    }

    // ─── Check for name-based duplicates ─────────────────────────────────
    const searchKey = (brand + " " + productName).toLowerCase().trim();
    if (!barcode) {
      const { data: nameMatch } = await adminClient.rpc(
        "match_product_by_name",
        { search_text: searchKey },
      );

      if (
        Array.isArray(nameMatch) && nameMatch.length > 0 &&
        nameMatch[0].verified
      ) {
        console.log(
          `[save-product] Name match already verified: "${searchKey}"`,
        );
        return {
          saved: false,
          reason: "A verified product with a similar name already exists.",
        };
      }
    }

    // ─── Insert new product ──────────────────────────────────────────────
    const { error } = await adminClient.from("local_products").insert({
      barcode: barcode || null,
      brand,
      product_name: productName,
      category: "",
      serving_g: servingG,
      calories,
      protein,
      carbs,
      fat,
      fiber: 0,
      sodium_mg: 0,
      search_key: searchKey,
      source,
      confidence: source === "label_scan" ? 0.9 : 0.85,
      // Label scans directly from the nutrition table are trustworthy
      verified: source === "label_scan",
      verified_by: source === "label_scan" ? user.id : null,
      verified_at: source === "label_scan" ? new Date().toISOString() : null,
      added_by: user.id,
    });

    if (error) {
      console.warn("[save-product] Insert failed:", error.message);
      // Duplicate barcode constraint might fire — treat as non-fatal
      if (/duplicate|unique/i.test(error.message)) {
        return { saved: false, reason: "Product already exists." };
      }
      throw new FunctionError(500, "Could not save product.");
    }

    console.log(
      `[save-product] Saved: ${brand} ${productName} (barcode: ${barcode || "none"}, source: ${source})`,
    );
    return { saved: true, updated: false };
  })
);
