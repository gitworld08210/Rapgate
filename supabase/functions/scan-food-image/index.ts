import { adminClient, FunctionError, invoke, body, requireUser, clamp, round, isOwnedStoragePath } from "../_shared/common.ts";

interface DetectedItem { name: string; calories: number; protein: number; carbs: number; fat: number; confidence: number; }
const SYSTEM_PROMPT = `You are a nutrition estimation assistant. Identify each distinct food item in the image and estimate nutrition for the visible portion. Respond ONLY with {"items":[{"name":string,"calories":number,"protein":number,"carbs":number,"fat":number,"confidence":number}]}. Use kcal for calories, grams for macros, prefer Indian dish names, and return {"items":[]} if no food is visible.`;

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
  return items.slice(0, 30).map((item) => {
    const row = (item && typeof item === "object" ? item : {}) as Record<string, unknown>;
    return { name: String(row.name ?? "Unknown").slice(0, 80), calories: clamp(row.calories, 0, 5000), protein: clamp(row.protein, 0, 500), carbs: clamp(row.carbs, 0, 500), fat: clamp(row.fat, 0, 500), confidence: clamp(row.confidence, 0, 1) };
  }).filter((item) => item.name.length > 0);
}

async function callVision(imageBase64: string): Promise<DetectedItem[]> {
  const provider = Deno.env.get("VISION_API_PROVIDER") ?? "gemini";
  const model = Deno.env.get("VISION_MODEL") ?? "gemini-2.0-flash";
  const key = visionKey();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 120_000);
  try {
    if (provider === "gemini") {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(key)}`;
      const response = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, signal: controller.signal, body: JSON.stringify({ contents: [{ parts: [{ text: `${SYSTEM_PROMPT}\n\nIdentify the food and estimate nutrition.` }, { inlineData: { mimeType: "image/jpeg", data: imageBase64 } }] }], generationConfig: { temperature: 0.3, maxOutputTokens: 1200, responseMimeType: "text/plain" } }) });
      if (!response.ok) throw new Error(`Gemini ${response.status}`);
      const payload = await response.json() as { candidates?: { content?: { parts?: { text?: string }[] } }[] };
      return parseItems(payload.candidates?.[0]?.content?.parts?.[0]?.text ?? "");
    }
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", { method: "POST", headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" }, signal: controller.signal, body: JSON.stringify({ model, max_tokens: 1200, messages: [{ role: "system", content: SYSTEM_PROMPT }, { role: "user", content: [{ type: "text", text: "Identify the food and estimate nutrition." }, { type: "image_url", image_url: { url: `data:image/jpeg;base64,${imageBase64}` } }] }] }) });
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
  let items: DetectedItem[];
  try { items = await callVision(imageBase64); } catch (error) { console.error("Vision call failed", error); throw new FunctionError(502, "Could not analyse the photo. Try again, or enter the food manually."); }
  const { error } = await adminClient.rpc("insert_food_log_and_bump", { p_user_id: user.id, p_image_path: imagePath, p_detected_items: items, p_meal_type: mealType, p_source: "ai_scan" });
  if (error) throw new FunctionError(500, "Could not save the food log.");
  return { detectedItems: items, totalCalories: round(items.reduce((sum, item) => sum + item.calories, 0)), totalProtein: round(items.reduce((sum, item) => sum + item.protein, 0)), totalCarbs: round(items.reduce((sum, item) => sum + item.carbs, 0)), totalFat: round(items.reduce((sum, item) => sum + item.fat, 0)) };
}));
