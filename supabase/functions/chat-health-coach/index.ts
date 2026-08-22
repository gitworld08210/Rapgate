import {
  adminClient,
  body,
  FunctionError,
  invoke,
  requireUser,
  round,
} from "../_shared/common.ts";

/**
 * chat-health-coach — AI nutrition coach grounded in the user's own data.
 *
 * The value of this feature is entirely in the context: a generic "eat more
 * protein" answer is worthless, but "you averaged 38g against a 100g target
 * this week, and your dinners are the gap" is actionable. So the function
 * assembles the user's profile, today's intake, and a 7-day rolling average
 * before the model ever sees the question.
 *
 * Model: gemini-3.6-flash. Chosen over Flash-Lite because coaching needs real
 * reasoning over the numbers, and over Pro because a chat turn must feel
 * instant. 3.6 also emits ~17% fewer output tokens than 3.5 for the same
 * answer quality, which matters when every turn resends the context.
 */

const MODEL = "gemini-3.6-flash";

interface MealSuggestion {
  name: string;
  protein: number;
  calories: number;
  note: string;
}

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    reply: { type: "STRING" },
    suggestions: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          name: { type: "STRING" },
          protein: { type: "NUMBER" },
          calories: { type: "NUMBER" },
          note: { type: "STRING" },
        },
        required: ["name", "protein", "calories", "note"],
      },
    },
  },
  required: ["reply", "suggestions"],
};

function systemPrompt(context: string): string {
  return `You are RepGate Coach, a friendly Indian nutrition and fitness coach inside a health-tracking app.

The user's real logged data is below. Ground every answer in these numbers — never invent intake figures, and never contradict the data.

${context}

How to reply:
- Open by referencing the user's actual numbers when they are relevant to the question.
- Keep the reply under 70 words. Short, warm, specific. No lecturing, no bullet lists.
- Natural Hinglish is welcome when it fits the user's tone, but stay easy to read.
- Prefer Indian foods the user can actually buy: dal, paneer, curd, eggs, soya chunks, sprouts, roti, chana, peanuts.
- Suggest 0 suggestions for greetings, thanks, or general chat. Suggest 2-3 only when the user asks what to eat or how to hit a target.
- Each suggestion needs a realistic per-serving protein and calorie figure and a short note naming the portion (for example "1 katori" or "100 g").

Safety:
- You are not a doctor. If the user mentions a medical condition, medication, pregnancy, an eating disorder, or asks about extreme restriction, say plainly that they should speak to a doctor or dietitian and do not give a plan.
- Never recommend under 1200 kcal per day.

Respond ONLY with {"reply":string,"suggestions":[{"name":string,"protein":number,"calories":number,"note":string}]}.`;
}

/** Formats the user's own data into the block the model reasons over. */
async function buildContext(userId: string): Promise<string> {
  const lines: string[] = [];

  const { data: profile } = await adminClient
    .from("users")
    .select(
      "name, age, weight, height, gender, daily_calorie_target, daily_protein_target, pushup_target",
    )
    .eq("id", userId)
    .maybeSingle();

  if (profile) {
    const parts: string[] = [];
    if (profile.age) parts.push(`age ${profile.age}`);
    if (profile.gender) parts.push(String(profile.gender));
    if (profile.weight) parts.push(`${profile.weight} kg`);
    if (profile.height) parts.push(`${profile.height} cm`);
    lines.push(`PROFILE: ${parts.join(", ") || "not set"}`);
    lines.push(
      `DAILY TARGETS: ${profile.daily_calorie_target ?? 2000} kcal, ${
        profile.daily_protein_target ?? 100
      } g protein`,
    );
  } else {
    lines.push("PROFILE: not set up yet");
  }

  // Asia/Kolkata day boundary — the rest of the app buckets days in IST, and a
  // UTC boundary would silently drop or double-count evening meals.
  const nowIst = new Date(Date.now() + 5.5 * 60 * 60 * 1000);
  const todayIst = nowIst.toISOString().slice(0, 10);
  const startOfToday = new Date(`${todayIst}T00:00:00+05:30`).toISOString();
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    .toISOString();

  const { data: todayLogs } = await adminClient
    .from("food_logs")
    .select("detected_items, meal_type")
    .eq("user_id", userId)
    .gte("logged_at", startOfToday)
    .limit(60);

  const sumItems = (rows: { detected_items?: unknown }[] | null) => {
    let calories = 0, protein = 0, carbs = 0, fat = 0;
    for (const row of rows ?? []) {
      const items = Array.isArray(row.detected_items) ? row.detected_items : [];
      for (const raw of items) {
        const item = (raw ?? {}) as Record<string, unknown>;
        calories += Number(item.calories) || 0;
        protein += Number(item.protein) || 0;
        carbs += Number(item.carbs) || 0;
        fat += Number(item.fat) || 0;
      }
    }
    return { calories, protein, carbs, fat };
  };

  const today = sumItems(todayLogs);
  if ((todayLogs?.length ?? 0) === 0) {
    lines.push("TODAY: nothing logged yet");
  } else {
    lines.push(
      `TODAY SO FAR: ${round(today.calories)} kcal, ${
        round(today.protein)
      } g protein, ${round(today.carbs)} g carbs, ${round(today.fat)} g fat`,
    );
    const meals = [
      ...new Set((todayLogs ?? []).map((row) => String(row.meal_type))),
    ];
    lines.push(`MEALS LOGGED TODAY: ${meals.join(", ")}`);
  }

  const { data: weekLogs } = await adminClient
    .from("food_logs")
    .select("detected_items, logged_at")
    .eq("user_id", userId)
    .gte("logged_at", sevenDaysAgo)
    .limit(400);

  if (weekLogs && weekLogs.length > 0) {
    const week = sumItems(weekLogs);
    const activeDays = new Set(
      weekLogs.map((row) => String(row.logged_at).slice(0, 10)),
    ).size;
    const days = Math.max(activeDays, 1);
    lines.push(
      `7-DAY AVERAGE (over ${activeDays} logged day${
        activeDays === 1 ? "" : "s"
      }): ${round(week.calories / days)} kcal, ${
        round(week.protein / days)
      } g protein per day`,
    );
  }

  const { data: streak } = await adminClient
    .from("streaks")
    .select("current_pushup_streak, current_food_log_streak")
    .eq("user_id", userId)
    .maybeSingle();

  if (streak) {
    lines.push(
      `STREAKS: ${streak.current_pushup_streak ?? 0}-day push-up, ${
        streak.current_food_log_streak ?? 0
      }-day food logging`,
    );
  }

  const { data: weights } = await adminClient
    .from("weight_logs")
    .select("weight_kg, logged_at")
    .eq("user_id", userId)
    .order("logged_at", { ascending: false })
    .limit(2);

  if (weights && weights.length === 2) {
    const delta = Number(weights[0].weight_kg) - Number(weights[1].weight_kg);
    const direction = delta > 0 ? "up" : "down";
    lines.push(
      `WEIGHT: ${weights[0].weight_kg} kg, ${direction} ${
        round(Math.abs(delta))
      } kg since last entry`,
    );
  } else if (weights && weights.length === 1) {
    lines.push(`WEIGHT: ${weights[0].weight_kg} kg`);
  }

  return lines.join("\n");
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

interface Turn {
  role: "user" | "model";
  text: string;
}

/** Sanitises client-supplied history so it cannot inject roles or bloat context. */
function parseHistory(value: unknown): Turn[] {
  if (!Array.isArray(value)) return [];
  const turns: Turn[] = [];
  // Only the last 8 turns are kept: enough for the model to follow a thread,
  // bounded so a long-running chat cannot grow the prompt without limit.
  for (const raw of value.slice(-8)) {
    const row = (raw ?? {}) as Record<string, unknown>;
    const text = String(row.text ?? "").trim().slice(0, 600);
    if (!text) continue;
    turns.push({ role: row.role === "model" ? "model" : "user", text });
  }
  return turns;
}

async function callGemini(
  key: string,
  context: string,
  history: Turn[],
  message: string,
): Promise<{ reply: string; suggestions: MealSuggestion[] }> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(MODEL)
  }:generateContent?key=${encodeURIComponent(key)}`;

  const buildPayload = (withThinkingConfig: boolean) => {
    const generationConfig: Record<string, unknown> = {
      temperature: 0.7,
      maxOutputTokens: 700,
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
    };
    // Thinking is disabled to keep a chat turn snappy. Some model revisions
    // reject the field outright, which is handled below.
    if (withThinkingConfig) {
      generationConfig.thinkingConfig = { thinkingBudget: 0 };
    }
    return JSON.stringify({
      contents: [
        ...history.map((turn) => ({
          role: turn.role,
          parts: [{ text: turn.text }],
        })),
        { role: "user", parts: [{ text: message }] },
      ],
      systemInstruction: { parts: [{ text: systemPrompt(context) }] },
      generationConfig,
    });
  };

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 25_000);
  try {
    let payload = buildPayload(true);
    const post = () =>
      fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        signal: controller.signal,
        body: payload,
      });

    let response = await post();

    // A model revision that rejects thinkingConfig fails every request with a
    // 400, so retry once without it rather than breaking the whole feature.
    if (response.status === 400) {
      const detail = await response.text();
      if (/thinking/i.test(detail)) {
        console.warn("[coach] model rejected thinkingConfig; retrying without");
        payload = buildPayload(false);
        response = await post();
      } else {
        console.error(`[coach] Gemini 400: ${detail.slice(0, 300)}`);
        throw new FunctionError(
          502,
          "The coach could not answer. Please retry.",
        );
      }
    }

    // 429/503 are transient capacity signals, not bad input.
    for (const delay of [600, 1500]) {
      if (response.status !== 429 && response.status !== 503) break;
      console.warn(`[coach] ${response.status}; retrying in ${delay}ms`);
      await sleep(delay);
      response = await post();
    }

    if (response.status === 429 || response.status === 503) {
      throw new FunctionError(
        503,
        "The coach is busy right now. Please try again in a few seconds.",
      );
    }
    if (!response.ok) {
      const detail = await response.text();
      console.error(`[coach] Gemini ${response.status}: ${detail.slice(0, 300)}`);
      throw new FunctionError(502, "The coach could not answer. Please retry.");
    }

    const data = await response.json() as {
      candidates?: {
        content?: { parts?: { text?: string }[] };
        finishReason?: string;
      }[];
    };
    const candidate = data.candidates?.[0];

    // A SAFETY finish reason returns no usable parts; a generic parse failure
    // here would read as a server bug, so it is surfaced distinctly.
    if (candidate?.finishReason === "SAFETY") {
      return {
        reply:
          "I can't help with that one. For anything medical, please talk to a doctor or a registered dietitian.",
        suggestions: [],
      };
    }

    const text = candidate?.content?.parts?.[0]?.text ?? "";
    if (!text) throw new FunctionError(502, "The coach returned no answer.");

    let parsed: { reply?: unknown; suggestions?: unknown };
    try {
      parsed = JSON.parse(text);
    } catch {
      console.warn("[coach] unparsable response:", text.slice(0, 200));
      throw new FunctionError(502, "The coach returned an unreadable answer.");
    }

    const reply = String(parsed.reply ?? "").trim();
    if (!reply) throw new FunctionError(502, "The coach returned no answer.");

    const suggestions: MealSuggestion[] = [];
    if (Array.isArray(parsed.suggestions)) {
      for (const raw of parsed.suggestions.slice(0, 3)) {
        const row = (raw ?? {}) as Record<string, unknown>;
        const name = String(row.name ?? "").trim().slice(0, 60);
        if (!name) continue;
        suggestions.push({
          name,
          protein: Math.max(0, Math.min(200, Number(row.protein) || 0)),
          calories: Math.max(0, Math.min(2000, Number(row.calories) || 0)),
          note: String(row.note ?? "").trim().slice(0, 40),
        });
      }
    }

    return { reply, suggestions };
  } catch (error) {
    if (error instanceof FunctionError) throw error;
    if (error instanceof Error && error.name === "AbortError") {
      throw new FunctionError(
        504,
        "The coach took too long to answer. Please try again.",
      );
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

Deno.serve((req) =>
  invoke("chat-health-coach", req, async (request) => {
    const { user } = await requireUser(request);
    const input = await body(request);

    const message = String(input.message ?? "").trim().slice(0, 600);
    if (!message) throw new FunctionError(400, "message is required.");

    const key = Deno.env.get("VISION_API_KEY") ?? "";
    if (!key) throw new FunctionError(500, "The coach is not configured.");

    const history = parseHistory(input.history);
    const context = await buildContext(user.id);
    const startedAt = Date.now();

    const { reply, suggestions } = await callGemini(
      key,
      context,
      history,
      message,
    );

    console.log(
      `[coach] answered in ${Date.now() - startedAt}ms, ${suggestions.length} suggestion(s)`,
    );

    // Persistence must not fail the turn the user is waiting on.
    adminClient.from("coach_messages").insert([
      { user_id: user.id, role: "user", text: message },
      {
        user_id: user.id,
        role: "model",
        text: reply,
        suggestions,
      },
    ]).then(({ error }) => {
      if (error) console.warn("[coach] history save failed:", error.message);
    });

    return { reply, suggestions };
  })
);
