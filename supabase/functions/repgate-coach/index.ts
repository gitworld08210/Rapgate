import {
  adminClient,
  body,
  clamp,
  FunctionError,
  invoke,
  requireUser,
} from "../_shared/common.ts";

function visionKey(): string {
  const key = Deno.env.get("VISION_API_KEY") ?? Deno.env.get("GEMINI_API_KEY") ?? "";
  if (!key) throw new FunctionError(500, "Gemini API key is not configured.");
  return key;
}

invoke(async (req) => {
  const user = await requireUser(req);
  const input = await body(req);

  const userMessage = typeof input.userMessage === "string" ? input.userMessage : "";
  const context = (input.userContext && typeof input.userContext === "object") ? input.userContext : {};

  if (!userMessage) {
    throw new FunctionError(400, "userMessage is required.");
  }

  const key = visionKey();
  const model = "gemini-2.0-flash";

  const systemPrompt = `You are RepGate Coach — India's premier conversational AI health, fitness, diet, and nutrition coach.
Tone: Energetic, friendly, motivating Hinglish (natural conversational mix of Hindi and English, like "Bhai", "Dost"). Keep advice realistic, science-backed, and practical for Indian daily routines.

CURRENT USER HEALTH CONTEXT:
${JSON.stringify(context, null, 2)}

CORE RESPONSIBILITIES:
1. Always refer to the user's REAL numbers and food items.
2. If asked about protein: calculate exact remaining deficit. Recommend Indian foods (Paneer, Soya chunks, Boiled eggs, Sattu, Sprouts, Greek yogurt, Chicken breast) with exact gram amounts and calories.
3. If asked for a diet plan: look at what was already eaten and suggest upcoming meals for today.
4. If asked about mistakes: point out high oil/tadka, excess sugar, low protein density, and suggest healthier Indian swaps.
5. If asked for progress report: give an emoji-rich scorecard and actionable next steps.
Keep formatting clean with markdown bullet points.`;

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(key)}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{
        role: "user",
        parts: [{ text: userMessage }],
      }],
      systemInstruction: { parts: [{ text: systemPrompt }] },
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 1000,
      },
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new FunctionError(res.status, `Gemini API error: ${errText}`);
  }

  const data = await res.json();
  const reply = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "Namaste! Main RepGate Coach hoon.";

  return { reply, userId: user.id };
});
