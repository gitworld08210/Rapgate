import { FunctionError, invoke, body, requireUser, requiredString, clamp } from "../_shared/common.ts";

Deno.serve((req) => invoke("search-food-by-barcode", req, async (request) => {
  await requireUser(request);
  const barcode = requiredString((await body(request)).barcode, "barcode");
  if (!/^\d{6,14}$/.test(barcode)) throw new FunctionError(400, "That barcode looks invalid.");
  try {
    const response = await fetch(`https://world.openfoodfacts.org/api/v2/product/${barcode}.json`, { headers: { "User-Agent": "HealthPush/1.0" } });
    if (!response.ok) return { found: false };
    const data = await response.json() as { status?: number; product?: { product_name?: string; nutriments?: Record<string, number> } };
    if (data.status !== 1 || !data.product) return { found: false };
    const n = data.product.nutriments ?? {};
    return { found: true, item: { name: data.product.product_name ?? "Packaged food", calories: clamp(n["energy-kcal_100g"], 0, 5000), protein: clamp(n.proteins_100g, 0, 500), carbs: clamp(n.carbohydrates_100g, 0, 500), fat: clamp(n.fat_100g, 0, 500), confidence: 0.95 } };
  } catch (error) { console.warn("Barcode lookup failed", barcode, error); return { found: false }; }
}));
