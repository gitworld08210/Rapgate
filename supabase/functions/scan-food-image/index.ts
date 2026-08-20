import { adminClient, FunctionError, invoke, body, requireUser, clamp, round, isOwnedStoragePath } from "../_shared/common.ts";

interface DetectedItem { name: string; calories: number; protein: number; carbs: number; fat: number; confidence: number; }
const SYSTEM_PROMPT = `You are a nutrition estimation assistant. Identify each distinct food item in the image and estimate nutrition for the visible portion. Respond ONLY with {"items":[{"name":string,"calories":number,"protein":number,"carbs":number,"fat":number,"confidence":number}]}. Use kcal for calories, grams for macros, prefer Indian dish names, list each distinct dish only once, and return {"items":[]} if no food is visible.`;

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
        required: ["name", "calories", "protein", "carbs", "fat"],
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

function parseItems(raw: string): DetectedItem[] {
  const match = raw.match(/\{[\s\S]*\}/);
  if (!match) return [];
  let value: unknown;
  try { value = JSON.parse(match[0]); } catch { return []; }
  const items = value && typeof value === "object" && Array.isArray((value as { items?: unknown }).items) ? (value as { items: unknown[] }).items : [];
  const seen = new Set<string>();
  return items.slice(0, 30).map((item) => {
    const row = (item && typeof item === "object" ? item : {}) as Record<string, unknown>;
    return { name: String(row.name ?? "Unknown").slice(0, 80), calories: clamp(row.calories, 0, 5000), protein: clamp(row.protein, 0, 500), carbs: clamp(row.carbs, 0, 500), fat: clamp(row.fat, 0, 500), confidence: clamp(row.confidence, 0, 1) };
  }).filter((item) => {
    if (item.name.length === 0) return false;
    // The model occasionally repeats the same dish ("Seb", "Apple", "Seb").
    const key = item.name.trim().toLowerCase();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/**
 * Gemini 2.5 models reason before answering, which dominates latency for a
 * simple recognition task. thinkingBudget: 0 turns that off on the Flash
 * variants. Pro cannot disable it, and some models reject the field outright,
 * so it is only sent for Flash and the call transparently retries without it.
 */
function supportsThinkingToggle(model: string): boolean {
  return /flash/i.test(model);
}

async function callGemini(model: string, key: string, imageBase64: string, signal: AbortSignal, withThinkingConfig: boolean): Promise<Response> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(key)}`;
  const generationConfig: Record<string, unknown> = {
    temperature: 0.2,
    maxOutputTokens: 800,
    responseMimeType: "application/json",
    responseSchema: RESPONSE_SCHEMA,
  };
  if (withThinkingConfig) generationConfig.thinkingConfig = { thinkingBudget: 0 };

  return await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    signal,
    body: JSON.stringify({
      contents: [{ parts: [{ text: "Identify the food and estimate nutrition." }, { inlineData: { mimeType: "image/jpeg", data: imageBase64 } }] }],
      systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
      generationConfig,
    }),
  });
}

async function callVision(imageBase64: string): Promise<DetectedItem[]> {
  const provider = Deno.env.get("VISION_API_PROVIDER") ?? "gemini";
  const model = Deno.env.get("VISION_MODEL") ?? "gemini-2.5-flash";
  const key = visionKey();
  const controller = new AbortController();
  // 120s was inherited from Firebase and is far longer than the platform
  // allows; failing fast lets the user retry instead of watching a spinner.
  const timeout = setTimeout(() => controller.abort(), 45_000);
  try {
    if (provider === "gemini") {
      let wantThinkingOff = supportsThinkingToggle(model);
      let response = await callGemini(model, key, imageBase64, controller.signal, wantThinkingOff);

      // Some model revisions reject thinkingConfig with a 400. Retry once
      // without it rather than surfacing a spurious failure.
      if (!response.ok && wantThinkingOff && response.status === 400) {
        const detail = await response.text();
        if (/thinking/i.test(detail)) {
          console.warn("Model rejected thinkingConfig; retrying without it", model);
          wantThinkingOff = false;
          response = await callGemini(model, key, imageBase64, controller.signal, false);
        } else {
          throw new Error(`Gemini 400: ${detail.slice(0, 200)}`);
        }
      }
      if (!response.ok) throw new Error(`Gemini ${response.status}`);
      const payload = await response.json() as { candidates?: { content?: { parts?: { text?: string }[] } }[] };
      return parseItems(payload.candidates?.[0]?.content?.parts?.[0]?.text ?? "");
    }
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", { method: "POST", headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" }, signal: controller.signal, body: JSON.stringify({ model, max_tokens: 800, response_format: { type: "json_object" }, messages: [{ role: "system", content: SYSTEM_PROMPT }, { role: "user", content: [{ type: "text", text: "Identify the food and estimate nutrition." }, { type: "image_url", image_url: { url: `data:image/jpeg;base64,${imageBase64}` } }] }] }) });
    if (!response.ok) throw new Error(`OpenRouter ${response.status}`);
    const payload = await response.json() as { choices?: { message?: { content?: string } }[] };
    return parseItems(payload.choices?.[0]?.message?.content ?? "");
  } finally { clearTimeout(timeout); }
}

Deno.serve((req) => invoke("scan-food-image", req, async (request) => {
  const { user } = await requireUser(request);
  const input = await body(request);
  const imageBase64 = typeof input.imageBase64 === "string" ? input.imageBase64 : "";
  const mealType = typeof input.mealType === "string" ? input.mealType : "snack";
  const imagePath = typeof input.imagePath === "string" ? input.imagePath : null;
  if (!imageBase64) throw new FunctionError(400, "imageBase64 is required.");
  if (imageBase64.length > 11_000_000) throw new FunctionError(400, "Image is too large.");
  if (!["breakfast", "lunch", "dinner", "snack"].includes(mealType)) throw new FunctionError(400, "Unknown mealType.");
  if (imagePath && !isOwnedStoragePath(imagePath, user.id)) throw new FunctionError(400, "Invalid image path.");
  if (imagePath && !imagePath.startsWith(`${user.id}/food_images/`)) throw new FunctionError(400, "Use a food-images storage path owned by your account.");
  const startedAt = Date.now();
  let items: DetectedItem[];
  try { items = await callVision(imageBase64); } catch (error) {
    console.error("Vision call failed", error);
    if (error instanceof Error && error.name === "AbortError") {
      throw new FunctionError(504, "The photo took too long to analyse. Try again with better light, or enter the food manually.");
    }
    throw new FunctionError(502, "Could not analyse the photo. Try again, or enter the food manually.");
  }
  console.log(`[scan-food-image] vision completed in ${Date.now() - startedAt}ms, ${items.length} item(s)`);
  const { error } = await adminClient.rpc("insert_food_log_and_bump", { p_user_id: user.id, p_image_path: imagePath, p_detected_items: items, p_meal_type: mealType, p_source: "ai_scan" });
  if (error) throw new FunctionError(500, "Could not save the food log.");
  return { detectedItems: items, totalCalories: round(items.reduce((sum, item) => sum + item.calories, 0)), totalProtein: round(items.reduce((sum, item) => sum + item.protein, 0)), totalCarbs: round(items.reduce((sum, item) => sum + item.carbs, 0)), totalFat: round(items.reduce((sum, item) => sum + item.fat, 0)) };
}));
