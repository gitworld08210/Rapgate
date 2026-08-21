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
    // Not a URL
  }

  const gs1Element = value.match(/(?:\]C1|\]Q3)?\s*\(?01\)?\s*(\d{14})/i);
  if (gs1Element) candidates.push(gs1Element[1]);

  for (const candidate of candidates) {
    const gtin = candidate.replace(/\D/g, "");
    if (hasValidCheckDigit(gtin)) return gtin;
  }
  return null;
}

type Nutriments = Record<string, unknown>;

/** A usable non-negative number, or null when the field is absent/unparsable. */
function num(nutriments: Nutriments, key: string): number | null {
  const value = Number(nutriments[key]);
  return Number.isFinite(value) && value >= 0 ? value : null;
}

/**
 * Read one nutrient within a single basis, falling back to the bare key that
 * Open Food Facts sometimes uses. Deliberately does NOT fall back to the other
 * basis: mixing per-serving and per-100 g numbers in one row silently reports
 * nutrition the package never stated.
 */
function nutrientInBasis(
  nutriments: Nutriments,
  base: string,
  basis: "serving" | "100g",
): number | null {
  return num(nutriments, `${base}_${basis}`) ?? num(nutriments, base);
}

/** Energy in kcal, converting from kJ when only kJ is published. */
function energyKcalInBasis(
  nutriments: Nutriments,
  basis: "serving" | "100g",
): number | null {
  const kcal = nutrientInBasis(nutriments, "energy-kcal", basis);
  if (kcal !== null) return kcal;
  const kj = nutrientInBasis(nutriments, "energy-kj", basis) ??
    nutrientInBasis(nutriments, "energy", basis);
  return kj === null ? null : kj / 4.184;
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
          headers: { "User-Agent": "RepGate/1.2 (food lookup)" },
          signal: controller.signal,
        },
      );
      // Open Food Facts answers 404 for a barcode it has never seen. That is a
      // normal "not found", not an outage, and many Indian retail products are
      // simply absent from the database.
      if (response.status === 404) {
        return {
          found: false,
          barcode,
          reason:
            "This product is not in Open Food Facts yet. Use Food Label mode to scan the nutrition panel.",
        };
      }
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
          nutriments?: Nutriments;
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
      const servingSize = product.serving_size?.trim() ?? "";

      // Pick a single basis and stay in it. Serving is only used when the
      // product states a serving size AND publishes energy for that serving,
      // otherwise everything is read per 100 g.
      const useServing = servingSize.length > 0 &&
        energyKcalInBasis(nutriments, "serving") !== null;
      const basis: "serving" | "100g" = useServing ? "serving" : "100g";

      const calories = energyKcalInBasis(nutriments, basis);
      const protein = nutrientInBasis(nutriments, "proteins", basis);
      const carbs = nutrientInBasis(nutriments, "carbohydrates", basis);
      const fat = nutrientInBasis(nutriments, "fat", basis);

      // A product can exist in Open Food Facts with an empty nutrition table.
      // Returning it as a found item logged an all-zero meal, so report it as
      // unusable and point the user at the label scanner instead.
      if (calories === null && protein === null && carbs === null && fat === null) {
        return {
          found: false,
          barcode,
          reason:
            "This product is listed but has no nutrition data. Use Food Label mode to scan the nutrition panel.",
        };
      }

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
        nutritionBasis: useServing ? servingSize : "100 g",
        item: {
          name: displayName.slice(0, 100),
          calories: clamp(calories ?? 0, 0, 5000),
          protein: clamp(protein ?? 0, 0, 500),
          carbs: clamp(carbs ?? 0, 0, 500),
          fat: clamp(fat ?? 0, 0, 500),
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
