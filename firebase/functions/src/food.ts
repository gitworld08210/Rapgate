import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";

import {
  FieldValue,
  Timestamp,
  RUNTIME,
  paths,
  db,
  startOfLocalDay,
} from "./config";

/** Set with: firebase functions:secrets:set VISION_API_KEY
 *  OR put it in .env (gitignored) for emulator/dev use. */
const VISION_API_KEY = defineSecret("VISION_API_KEY");

/** Resolve the API key: prefer the Firebase secret, fall back to .env */
function getVisionApiKey(): string {
  try {
    const secretVal = VISION_API_KEY.value();
    if (secretVal && secretVal.length > 10) return secretVal;
  } catch {
    // Secret not available (e.g. emulator) — fall through to env
  }
  const envVal = process.env.VISION_API_KEY ?? "";
  if (!envVal) {
    throw new Error("VISION_API_KEY not configured. Set it as a Firebase secret or in .env");
  }
  return envVal;
}

interface DetectedItem {
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  confidence: number;
}

const SYSTEM_PROMPT = `You are a nutrition estimation assistant.
Identify each distinct food item in the image and estimate its nutrition for the
portion actually visible.

Respond with ONLY a JSON object, no prose, in exactly this shape:
{"items":[{"name":string,"calories":number,"protein":number,"carbs":number,"fat":number,"confidence":number}]}

Rules:
- confidence is 0..1 reflecting how sure you are of the identification.
- Estimate for the VISIBLE PORTION, not a generic serving.
- Use grams for protein/carbs/fat and kcal for calories.
- Prefer Indian dish names where applicable (e.g. "dal tadka", "roti").
- If no food is visible, return {"items":[]}.`;

/**
 * Estimates nutrition from a food photo using a vision model, writes the log,
 * and returns the parsed items.
 *
 * The estimate is explicitly approximate — the client surfaces an
 * "AI-estimated, not medical advice" disclaimer alongside these numbers.
 */
export const scanFoodImage = onCall(
  { ...RUNTIME, secrets: [VISION_API_KEY], timeoutSeconds: 120 },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

    const imageBase64 = String(request.data?.imageBase64 ?? "");
    const mealType = String(request.data?.mealType ?? "snack");

    if (!imageBase64) {
      throw new HttpsError("invalid-argument", "imageBase64 is required.");
    }
    // ~8 MB of base64 ≈ 6 MB binary.
    if (imageBase64.length > 11_000_000) {
      throw new HttpsError("invalid-argument", "Image is too large.");
    }
    if (!["breakfast", "lunch", "dinner", "snack"].includes(mealType)) {
      throw new HttpsError("invalid-argument", "Unknown mealType.");
    }

    let items: DetectedItem[];
    try {
      items = await callVisionModel(imageBase64, getVisionApiKey());
    } catch (e) {
      logger.error("Vision call failed", { uid, error: String(e) });
      throw new HttpsError(
        "internal",
        "Could not analyse the photo. Try again, or enter the food manually."
      );
    }

    const totalCalories = round(sum(items.map((i) => i.calories)));
    const totalProtein = round(sum(items.map((i) => i.protein)));

    // Persist the log server-side so the daily totals cannot drift from what
    // the model actually returned.
    await paths.foodLogs(uid).add({
      imageUrl: null, // the client uploads the photo and may patch this in
      detectedItems: items,
      mealType,
      loggedAt: FieldValue.serverTimestamp(),
      source: "ai_scan",
    });

    await bumpFoodLogStreak(uid);

    logger.info("Food scanned", { uid, itemCount: items.length, totalCalories });

    return {
      detectedItems: items,
      totalCalories,
      totalProtein,
      totalCarbs: round(sum(items.map((i) => i.carbs))),
      totalFat: round(sum(items.map((i) => i.fat))),
    };
  }
);

async function callVisionModel(
  imageBase64: string,
  apiKey: string
): Promise<DetectedItem[]> {
  const provider = process.env.VISION_API_PROVIDER ?? "gemini";
  const model = process.env.VISION_MODEL ?? "gemini-2.0-flash";

  if (provider === "gemini") {
    return callGemini(imageBase64, apiKey, model);
  }
  // Fallback: OpenRouter (supports Claude, GPT, etc.)
  return callOpenRouter(imageBase64, apiKey, model);
}

/** Calls Google Gemini (generativelanguage.googleapis.com) */
async function callGemini(
  imageBase64: string,
  apiKey: string,
  model: string
): Promise<DetectedItem[]> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [
        {
          parts: [
            { text: SYSTEM_PROMPT + "\n\nIdentify the food and estimate nutrition." },
            {
              inlineData: {
                mimeType: "image/jpeg",
                data: imageBase64,
              },
            },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 1200,
        responseMimeType: "text/plain",
      },
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Gemini API ${response.status}: ${errorBody}`);
  }

  const payload = (await response.json()) as {
    candidates?: { content?: { parts?: { text?: string }[] } }[];
  };

  const raw = payload.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  return parseItems(raw);
}

/** Calls OpenRouter (supports Claude, GPT, etc.) — kept as fallback */
async function callOpenRouter(
  imageBase64: string,
  apiKey: string,
  model: string
): Promise<DetectedItem[]> {
  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      max_tokens: 1200,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: [
            { type: "text", text: "Identify the food and estimate nutrition." },
            {
              type: "image_url",
              image_url: { url: `data:image/jpeg;base64,${imageBase64}` },
            },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`OpenRouter ${response.status}: ${await response.text()}`);
  }

  const payload = (await response.json()) as {
    choices?: { message?: { content?: string } }[];
  };
  const raw = payload.choices?.[0]?.message?.content ?? "";
  return parseItems(raw);
}

/** Tolerantly extracts the JSON payload the model returned. */
export function parseItems(raw: string): DetectedItem[] {
  // Models sometimes wrap JSON in ```json fences or add a sentence.
  const match = raw.match(/\{[\s\S]*\}/);
  if (!match) return [];

  let parsed: unknown;
  try {
    parsed = JSON.parse(match[0]);
  } catch {
    return [];
  }

  const rawItems = (parsed as { items?: unknown }).items;
  if (!Array.isArray(rawItems)) return [];

  return rawItems
    .slice(0, 30)
    .map((i) => {
      const o = i as Record<string, unknown>;
      return {
        name: String(o.name ?? "Unknown").slice(0, 80),
        calories: clampNum(o.calories, 0, 5000),
        protein: clampNum(o.protein, 0, 500),
        carbs: clampNum(o.carbs, 0, 500),
        fat: clampNum(o.fat, 0, 500),
        confidence: clampNum(o.confidence, 0, 1),
      };
    })
    .filter((i) => i.name.length > 0);
}

/** Barcode lookup via Open Food Facts — no API key required. */
export const searchFoodByBarcode = onCall(RUNTIME, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }

  const barcode = String(request.data?.barcode ?? "").trim();
  if (!/^\d{6,14}$/.test(barcode)) {
    throw new HttpsError("invalid-argument", "That barcode looks invalid.");
  }

  try {
    const res = await fetch(
      `https://world.openfoodfacts.org/api/v2/product/${barcode}.json`,
      { headers: { "User-Agent": "HealthPush/1.0" } }
    );
    if (!res.ok) return { found: false };

    const data = (await res.json()) as {
      status?: number;
      product?: { product_name?: string; nutriments?: Record<string, number> };
    };
    if (data.status !== 1 || !data.product) return { found: false };

    const n = data.product.nutriments ?? {};
    return {
      found: true,
      item: {
        name: data.product.product_name ?? "Packaged food",
        // Open Food Facts reports per 100 g.
        calories: clampNum(n["energy-kcal_100g"], 0, 5000),
        protein: clampNum(n["proteins_100g"], 0, 500),
        carbs: clampNum(n["carbohydrates_100g"], 0, 500),
        fat: clampNum(n["fat_100g"], 0, 500),
        confidence: 0.95, // label data, far more reliable than a photo
      },
    };
  } catch (e) {
    logger.warn("Barcode lookup failed", { barcode, error: String(e) });
    return { found: false };
  }
});

async function bumpFoodLogStreak(uid: string): Promise<void> {
  const ref = paths.streaks(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const today = startOfLocalDay(new Date());

    const lastRaw = snap.get("lastFoodLogDate") as
      | { toDate?: () => Date }
      | undefined;
    const last = lastRaw?.toDate?.();

    if (last && startOfLocalDay(last).getTime() === today.getTime()) return;

    const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);
    const continued =
      last && startOfLocalDay(last).getTime() === yesterday.getTime();

    tx.set(
      ref,
      {
        currentFoodLogStreak: continued
          ? ((snap.get("currentFoodLogStreak") as number) ?? 0) + 1
          : 1,
        lastFoodLogDate: Timestamp.fromDate(new Date()),
      },
      { merge: true }
    );
  });
}

// ---------------- small helpers ----------------

function sum(xs: number[]): number {
  return xs.reduce((a, b) => a + b, 0);
}

function round(n: number): number {
  return Math.round(n * 10) / 10;
}

function clampNum(v: unknown, min: number, max: number): number {
  const n = Number(v);
  if (!Number.isFinite(n)) return 0;
  return Math.min(Math.max(n, min), max);
}
