import {
  body,
  clamp,
  FunctionError,
  invoke,
  isOwnedStoragePath,
  requireUser,
  round,
} from "../_shared/common.ts";

interface DetectedItem {
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  confidence: number;
}
type ScanKind = "food" | "nutrition_label";

const SYSTEM_PROMPT =
  `You are a careful food-vision and nutrition estimation assistant.

Rules:
- Identify only food that is clearly visible. Do not guess from colour or shape alone. In particular, never call an item Apple unless an apple or apple pieces are clearly visible.
- Return one row per distinct food. Never repeat a food using a translation, spelling variant, or alias (for example Apple and Seb are the same item).
- Use short, consistent English display names. Common Indian dish names such as roti, dal, paneer, poha, idli, and biryani are valid English display names.
- Estimate nutrition for the visible edible portion, not automatically per 100 g.
- confidence must be between 0 and 1 and should reflect visual certainty.
- If no recognizable food is visible, return an empty items array.

Respond ONLY with {"items":[{"name":string,"calories":number,"protein":number,"carbs":number,"fat":number,"confidence":number}]}. Calories are kcal and macros are grams.`;

const SCAN_INSTRUCTIONS: Record<ScanKind, string> = {
  food:
    "Identify every clearly visible food on the plate and estimate nutrition for each visible portion.",
  nutrition_label:
    "This is a packaged-food or nutrition-label photo. Read the printed Nutritional Facts table carefully and transcribe the real printed numbers. Return one item. If the table states values per serving, use one serving. If it only states per 100 g or per 100 ml, use those values and append (per 100 g) to the product name. Read the product name from the packaging when visible. Never return zero for a nutrient whose value is printed and legible; only use 0 when the label genuinely states 0. If the table is unreadable, return an empty items array instead of guessing.",
};

// Structured output: removes markdown fences and retry-on-malformed-text, and
// lets the model stop as soon as the object closes.
const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    items: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          name: { type: "STRING" },
          calories: { type: "NUMBER" },
          protein: { type: "NUMBER" },
          carbs: { type: "NUMBER" },
          fat: { type: "NUMBER" },
          confidence: { type: "NUMBER" },
        },
        required: ["name", "calories", "protein", "carbs", "fat", "confidence"],
      },
    },
  },
  required: ["items"],
};

function visionKey(): string {
  const key = Deno.env.get("VISION_API_KEY") ?? "";
  if (!key) throw new FunctionError(500, "Vision analysis is not configured.");
  return key;
}

function normalizeFoodName(
  value: unknown,
): { key: string; name: string } | null {
  const cleaned = String(value ?? "")
    .normalize("NFKC")
    .replace(/[\u0000-\u001F\u007F]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 80);
  if (!cleaned) return null;

  const simplified = cleaned
    .toLocaleLowerCase("en")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
  const aliases: Record<string, { key: string; name: string }> = {
    seb: { key: "apple", name: "Apple" },
    seeb: { key: "apple", name: "Apple" },
    "apple fruit": { key: "apple", name: "Apple" },
  };
  return aliases[simplified] ?? { key: simplified, name: cleaned };
}

function parseItems(raw: string): DetectedItem[] {
  const match = raw.match(/\{[\s\S]*\}/);
  if (!match) return [];
  let value: unknown;
  try {
    value = JSON.parse(match[0]);
  } catch {
    return [];
  }
  const rows = value && typeof value === "object" &&
      Array.isArray((value as { items?: unknown }).items)
    ? (value as { items: unknown[] }).items
    : [];

  const unique = new Map<string, DetectedItem>();
  for (const value of rows) {
    const row = (value && typeof value === "object" ? value : {}) as Record<
      string,
      unknown
    >;
    const normalized = normalizeFoodName(row.name);
    if (!normalized) continue;
    const item: DetectedItem = {
      name: normalized.name,
      calories: clamp(row.calories, 0, 5000),
      protein: clamp(row.protein, 0, 500),
      carbs: clamp(row.carbs, 0, 500),
      fat: clamp(row.fat, 0, 500),
      confidence: clamp(row.confidence, 0, 1),
    };
    const previous = unique.get(normalized.key);
    if (!previous || item.confidence > previous.confidence) {
      unique.set(normalized.key, item);
    }
  }
  return [...unique.values()].slice(0, 30);
}

function supportsThinkingToggle(model: string): boolean {
  return /flash/i.test(model);
}

async function callGemini(
  model: string,
  key: string,
  imageBase64: string,
  instruction: string,
  signal: AbortSignal,
  withThinkingConfig: boolean,
): Promise<Response> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent?key=${encodeURIComponent(key)}`;
  const generationConfig: Record<string, unknown> = {
    temperature: 0.2,
    maxOutputTokens: 500,
    responseMimeType: "application/json",
    responseSchema: RESPONSE_SCHEMA,
  };
  if (withThinkingConfig) {
    generationConfig.thinkingConfig = { thinkingBudget: 0 };
  }

  return await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    signal,
    body: JSON.stringify({
      contents: [{
        parts: [{ text: instruction }, {
          inlineData: { mimeType: "image/jpeg", data: imageBase64 },
        }],
      }],
      systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
      generationConfig,
    }),
  });
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * A 429 (rate limited) or 503 (overloaded) from Gemini is transient, not a
 * bad image, and previously turned into an immediate hard failure with no
 * retry. Two short backoff attempts absorb normal API pressure so a busy
 * moment does not fail every scan for the rest of the request budget.
 */
async function callGeminiWithRetry(
  model: string,
  key: string,
  imageBase64: string,
  instruction: string,
  signal: AbortSignal,
  withThinkingConfig: boolean,
): Promise<Response> {
  const delaysMs = [600, 1500];
  let response = await callGemini(
    model,
    key,
    imageBase64,
    instruction,
    signal,
    withThinkingConfig,
  );
  for (const delay of delaysMs) {
    if (response.status !== 429 && response.status !== 503) break;
    console.warn(`Gemini ${response.status}; retrying in ${delay}ms`, model);
    await sleep(delay);
    response = await callGemini(
      model,
      key,
      imageBase64,
      instruction,
      signal,
      withThinkingConfig,
    );
  }
  return response;
}

async function callVision(
  imageBase64: string,
  scanKind: ScanKind,
): Promise<DetectedItem[]> {
  const provider = Deno.env.get("VISION_API_PROVIDER") ?? "gemini";
  // Flash-Lite is the lowest-latency stable vision model for plate recognition.
  // Reading a printed nutrition table needs more capability, so label scans
  // use full Flash unless VISION_MODEL overrides both.
  const configuredModel = Deno.env.get("VISION_MODEL");
  const model = configuredModel ??
    (scanKind === "nutrition_label"
      ? "gemini-2.5-flash"
      : "gemini-2.5-flash-lite");
  const key = visionKey();
  const instruction = SCAN_INSTRUCTIONS[scanKind];
  const controller = new AbortController();
  // 120s was inherited from Firebase and is far longer than the platform
  // allows; failing fast lets the user retry instead of watching a spinner.
  const timeout = setTimeout(() => controller.abort(), 45_000);
  try {
    if (provider === "gemini") {
      let wantThinkingOff = supportsThinkingToggle(model);
      let response = await callGeminiWithRetry(
        model,
        key,
        imageBase64,
        instruction,
        controller.signal,
        wantThinkingOff,
      );

      // Some model revisions reject thinkingConfig with a 400. Retry once
      // without it rather than surfacing a spurious failure.
      if (!response.ok && wantThinkingOff && response.status === 400) {
        const detail = await response.text();
        if (/thinking/i.test(detail)) {
          console.warn(
            "Model rejected thinkingConfig; retrying without it",
            model,
          );
          wantThinkingOff = false;
          response = await callGeminiWithRetry(
            model,
            key,
            imageBase64,
            instruction,
            controller.signal,
            false,
          );
        } else {
          throw new Error(`Gemini 400: ${detail.slice(0, 200)}`);
        }
      }

      // Gemini occasionally answers "unable to process input image" on an
      // otherwise valid JPEG — a transient decode hiccup on Google's side.
      // One retry recovers most of these without the user re-taking the photo.
      if (!response.ok && response.status === 400) {
        const detail = await response.text();
        if (/unable to process input image/i.test(detail)) {
          console.warn("Gemini image decode hiccup; retrying once", model);
          await sleep(400);
          response = await callGeminiWithRetry(
            model,
            key,
            imageBase64,
            instruction,
            controller.signal,
            wantThinkingOff,
          );
        } else {
          throw new Error(`Gemini 400: ${detail.slice(0, 200)}`);
        }
      }

      if (!response.ok) throw new Error(`Gemini ${response.status}`);
      const payload = await response.json() as {
        candidates?: { content?: { parts?: { text?: string }[] } }[];
      };
      return parseItems(
        payload.candidates?.[0]?.content?.parts?.[0]?.text ?? "",
      );
    }
    const response = await fetch(
      "https://openrouter.ai/api/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json",
        },
        signal: controller.signal,
        body: JSON.stringify({
          model,
          max_tokens: 500,
          response_format: { type: "json_object" },
          messages: [{ role: "system", content: SYSTEM_PROMPT }, {
            role: "user",
            content: [{ type: "text", text: instruction }, {
              type: "image_url",
              image_url: { url: `data:image/jpeg;base64,${imageBase64}` },
            }],
          }],
        }),
      },
    );
    if (!response.ok) throw new Error(`OpenRouter ${response.status}`);
    const payload = await response.json() as {
      choices?: { message?: { content?: string } }[];
    };
    return parseItems(payload.choices?.[0]?.message?.content ?? "");
  } finally {
    clearTimeout(timeout);
  }
}

Deno.serve((req) =>
  invoke("scan-food-image", req, async (request) => {
    const { user } = await requireUser(request);
    const input = await body(request);
    const imageBase64 = typeof input.imageBase64 === "string"
      ? input.imageBase64
      : "";
    const mealType = typeof input.mealType === "string"
      ? input.mealType
      : "snack";
    const scanKind: ScanKind = input.scanKind === "nutrition_label"
      ? "nutrition_label"
      : "food";
    const imagePath = typeof input.imagePath === "string"
      ? input.imagePath
      : null;
    if (!imageBase64) throw new FunctionError(400, "imageBase64 is required.");
    if (imageBase64.length > 11_000_000) {
      throw new FunctionError(400, "Image is too large.");
    }
    if (
      !["breakfast", "lunch", "dinner", "snack"].includes(mealType)
    ) {
      throw new FunctionError(400, "Unknown mealType.");
    }
    if (
      imagePath && !isOwnedStoragePath(imagePath, user.id)
    ) throw new FunctionError(400, "Invalid image path.");
    if (imagePath && !imagePath.startsWith(`${user.id}/food_images/`)) {
      throw new FunctionError(
        400,
        "Use a food-images storage path owned by your account.",
      );
    }
    const startedAt = Date.now();
    let items: DetectedItem[];
    try {
      items = await callVision(imageBase64, scanKind);
    } catch (error) {
      console.error("Vision call failed", error);
      if (error instanceof Error && error.name === "AbortError") {
        throw new FunctionError(
          504,
          "The photo took too long to analyse. Try again with better light, or enter the food manually.",
        );
      }
      if (error instanceof Error && /Gemini 429/.test(error.message)) {
        throw new FunctionError(
          503,
          "The AI scanner is busy right now. Please try again in a few seconds.",
        );
      }
      throw new FunctionError(
        502,
        "Could not analyse the photo. Try again, or enter the food manually.",
      );
    }
    console.log(
      `[scan-food-image] vision completed in ${
        Date.now() - startedAt
      }ms, ${items.length} item(s)`,
    );
    return {
      detectedItems: items,
      totalCalories: round(items.reduce((sum, item) => sum + item.calories, 0)),
      totalProtein: round(items.reduce((sum, item) => sum + item.protein, 0)),
      totalCarbs: round(items.reduce((sum, item) => sum + item.carbs, 0)),
      totalFat: round(items.reduce((sum, item) => sum + item.fat, 0)),
    };
  })
);
