import {
  body,
  clamp,
  FunctionError,
  invoke,
  requiredString,
  requireUser,
} from "../_shared/common.ts";

const GTIN_LENGTHS = new Set([8, 12, 13, 14]);

function hasValidCheckDigit(gtin: string): boolean {
  if (!GTIN_LENGTHS.has(gtin.length) || !/^\d+$/.test(gtin)) return false;
  const expected = Number(gtin.at(-1));
  let sum = 0;
  for (
    let index = gtin.length - 2, position = 1;
    index >= 0;
    index--, position++
  ) {
    sum += Number(gtin[index]) * (position % 2 === 1 ? 3 : 1);
  }
  return (10 - (sum % 10)) % 10 === expected;
}

/**
 * Accept retail EAN/UPC/GTIN values plus common QR forms used on packaging:
 * GS1 Digital Link URLs, GS1 element strings, and Open Food Facts product URLs.
 * Arbitrary QR links/text are rejected instead of being sent as a barcode.
 */
function extractGtin(payload: string): string | null {
  const value = payload.trim();
  const candidates: string[] = [];

  if (/^\d+$/.test(value)) candidates.push(value);

  try {
    const uri = new URL(value);
    const queryGtin = uri.searchParams.get("gtin") ??
      uri.searchParams.get("barcode") ??
      uri.searchParams.get("01");
    if (queryGtin) candidates.push(queryGtin);

    const gs1Path = uri.pathname.match(/(?:^|\/)01\/(\d{14})(?:\/|$)/);
    if (gs1Path) candidates.push(gs1Path[1]);

    const productPath = uri.pathname.match(/\/product\/(\d{8,14})(?:[\/-]|$)/);
    if (productPath) candidates.push(productPath[1]);
  } catch {
    // Not a URL; GS1 element strings are checked below.
  }

  const gs1Element = value.match(/(?:\]C1|\]Q3)?\s*\(?01\)?\s*(\d{14})/i);
  if (gs1Element) candidates.push(gs1Element[1]);

  for (const candidate of candidates) {
    const gtin = candidate.replace(/\D/g, "");
    if (hasValidCheckDigit(gtin)) return gtin;
  }
  return null;
}

function finiteNutrition(
  nutriments: Record<string, unknown>,
  key: string,
): boolean {
  const value = Number(nutriments[key]);
  return Number.isFinite(value) && value >= 0;
}

function nutritionValue(
  nutriments: Record<string, unknown>,
  key: string,
): number {
  return clamp(nutriments[key], 0, 5000);
}

Deno.serve((req) =>
  invoke("search-food-by-barcode", req, async (request) => {
    await requireUser(request);
    const payload = requiredString((await body(request)).barcode, "barcode");
    const barcode = extractGtin(payload);
    if (!barcode) {
      throw new FunctionError(
        400,
        "Scan a valid EAN, UPC, GTIN, GS1 QR, or Open Food Facts QR code.",
      );
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12_000);
    try {
      const fields =
        "product_name,product_name_en,generic_name,brands,serving_size,nutrition_data_per,nutriments";
      const response = await fetch(
        `https://world.openfoodfacts.org/api/v2/product/${
          encodeURIComponent(barcode)
        }.json?fields=${fields}`,
        {
          headers: { "User-Agent": "HealthPush/1.1 (food lookup)" },
          signal: controller.signal,
        },
      );
      if (!response.ok) {
        throw new FunctionError(
          502,
          "The product database is temporarily unavailable.",
        );
      }

      const data = await response.json() as {
        status?: number;
        product?: {
          product_name?: string;
          product_name_en?: string;
          generic_name?: string;
          brands?: string;
          serving_size?: string;
          nutrition_data_per?: string;
          nutriments?: Record<string, unknown>;
        };
      };
      if (data.status !== 1 || !data.product) {
        return {
          found: false,
          reason: "This product is not in Open Food Facts yet.",
          barcode,
        };
      }

      const product = data.product;
      const nutriments = product.nutriments ?? {};
      const servingKeys = [
        "energy-kcal_serving",
        "proteins_serving",
        "carbohydrates_serving",
        "fat_serving",
      ];
      const useServing = Boolean(product.serving_size?.trim()) &&
        servingKeys.some((key) => finiteNutrition(nutriments, key));
      const suffix = useServing ? "serving" : "100g";
      const basis = useServing ? product.serving_size!.trim() : "100 g";

      const rawName = [
        product.product_name_en,
        product.product_name,
        product.generic_name,
        product.brands,
      ].find((value) => typeof value === "string" && value.trim().length > 0);
      const productName = rawName?.trim() ?? "Packaged food";
      const displayName = useServing
        ? productName
        : `${productName} (per 100 g)`;

      return {
        found: true,
        barcode,
        nutritionBasis: basis,
        item: {
          name: displayName.slice(0, 100),
          calories: nutritionValue(nutriments, `energy-kcal_${suffix}`),
          protein: nutritionValue(nutriments, `proteins_${suffix}`),
          carbs: nutritionValue(nutriments, `carbohydrates_${suffix}`),
          fat: nutritionValue(nutriments, `fat_${suffix}`),
          confidence: 0.95,
        },
      };
    } catch (error) {
      if (error instanceof FunctionError) throw error;
      console.warn("Barcode lookup failed", barcode, error);
      if (error instanceof Error && error.name === "AbortError") {
        throw new FunctionError(
          504,
          "Product lookup timed out. Please try again.",
        );
      }
      throw new FunctionError(
        502,
        "Could not check the product database. Please try again.",
      );
    } finally {
      clearTimeout(timeout);
    }
  })
);
