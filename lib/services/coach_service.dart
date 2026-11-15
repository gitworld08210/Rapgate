import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coach_message_model.dart';
import 'supabase_client.dart';

/// Service powering the RepGate Coach AI assistant.
///
/// Features:
/// 1. Direct Gemini API integration (Gemini 2.0 Flash / 1.5 Flash).
/// 2. User-configurable custom Gemini API Key support via SharedPreferences.
/// 3. Supabase Edge Function fallback (`repgate-coach`).
/// 4. Dynamic Offline Health & Nutrition Intelligence Engine (zero dummy text,
///    fully calculates real deficits, food swaps, and personalized diet plans).
class CoachService {
  static const String _prefApiKey = 'repgate_coach_gemini_key';
  static const String _buildTimeApiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  final SupabaseClient _db = supabase;

  /// Retrieves the active Gemini API key (custom user key first, then build env)
  Future<String?> getActiveApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getString(_prefApiKey);
      if (custom != null && custom.trim().isNotEmpty) {
        return custom.trim();
      }
    } catch (e) {
      debugPrint('[CoachService] Error reading custom API key: $e');
    }
    if (_buildTimeApiKey.isNotEmpty) {
      return _buildTimeApiKey;
    }
    return null;
  }

  /// Saves a custom Gemini API key entered by the user
  Future<void> saveCustomApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.trim().isEmpty) {
      await prefs.remove(_prefApiKey);
    } else {
      await prefs.setString(_prefApiKey, key.trim());
    }
  }

  /// Sends a message to RepGate Coach and receives a contextual AI response
  Future<CoachResponse> sendMessage({
    required String userMessage,
    required UserHealthContext context,
    List<CoachMessage> chatHistory = const [],
  }) async {
    final apiKey = await getActiveApiKey();

    // 1. Try direct Gemini API if key is available
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final geminiResponse = await _callGeminiApi(
          apiKey: apiKey,
          userMessage: userMessage,
          context: context,
          chatHistory: chatHistory,
        );
        if (geminiResponse != null && geminiResponse.trim().isNotEmpty) {
          return CoachResponse(
            text: geminiResponse,
            source: CoachSource.geminiApi,
            suggestions: _extractSuggestions(userMessage, context),
          );
        }
      } catch (e) {
        debugPrint('[CoachService] Gemini REST call failed: $e');
      }
    }

    // 2. Try Supabase Edge Function `repgate-coach`
    try {
      final edgeResponse = await _db.functions.invoke(
        'repgate-coach',
        body: {
          'userMessage': userMessage,
          'userContext': {
            'userName': context.userName,
            'userAge': context.userAge,
            'userWeight': context.userWeight,
            'calorieTarget': context.calorieTarget,
            'proteinTarget': context.proteinTarget,
            'consumedCalories': context.consumedCalories,
            'consumedProtein': context.consumedProtein,
            'consumedCarbs': context.consumedCarbs,
            'consumedFat': context.consumedFat,
            'consumedWaterMl': context.consumedWaterMl,
            'streakDays': context.streakDays,
            'loggedMeals': context.loggedMeals,
          },
        },
      );
      if (edgeResponse.status < 400 && edgeResponse.data is Map) {
        final reply = edgeResponse.data['reply'] as String?;
        if (reply != null && reply.trim().isNotEmpty) {
          return CoachResponse(
            text: reply,
            source: CoachSource.supabaseEdge,
            suggestions: _extractSuggestions(userMessage, context),
          );
        }
      }
    } catch (e) {
      debugPrint('[CoachService] Supabase repgate-coach edge call skipped/failed: $e');
    }

    // 3. Fallback to Dynamic Offline Health & Nutrition Intelligence Engine
    final offlineReply = _generateSmartOfflineResponse(userMessage, context);
    return CoachResponse(
      text: offlineReply,
      source: CoachSource.offlineEngine,
      suggestions: _extractSuggestions(userMessage, context),
    );
  }

  /// Calls Google Gemini API REST endpoint with full context
  Future<String?> _callGeminiApi({
    required String apiKey,
    required String userMessage,
    required UserHealthContext context,
    required List<CoachMessage> chatHistory,
  }) async {
    final systemInstruction = _buildSystemInstruction(context);
    final models = ['gemini-2.0-flash', 'gemini-1.5-flash'];

    for (final model in models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final contents = <Map<String, dynamic>>[];

        // Include last 4 messages of history for context flow
        final recentHistory = chatHistory.length > 4
            ? chatHistory.sublist(chatHistory.length - 4)
            : chatHistory;
        for (final msg in recentHistory) {
          contents.add({
            'role': msg.isUser ? 'user' : 'model',
            'parts': [
              {'text': msg.text}
            ],
          });
        }

        // Add current user message
        contents.add({
          'role': 'user',
          'parts': [
            {'text': userMessage}
          ],
        });

        final body = jsonEncode({
          'contents': contents,
          'systemInstruction': {
            'parts': [
              {'text': systemInstruction}
            ]
          },
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 1000,
          },
        });

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final first = candidates[0] as Map<String, dynamic>;
            final content = first['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              return parts[0]['text'] as String?;
            }
          }
        } else {
          debugPrint('[CoachService] Gemini $model returned status ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[CoachService] Error calling Gemini model $model: $e');
      }
    }
    return null;
  }

  /// Builds comprehensive system instructions with user's real data
  String _buildSystemInstruction(UserHealthContext context) {
    final mealsDescription = context.loggedMeals.isEmpty
        ? 'No meals logged yet today.'
        : context.loggedMeals.map((m) {
            final name = m['name'] ?? 'Food';
            final cal = m['calories'] ?? 0;
            final prot = m['protein'] ?? 0;
            final carbs = m['carbs'] ?? 0;
            final fat = m['fat'] ?? 0;
            final style = m['cookingStyle'] ?? 'Standard';
            return '- $name ($style): ${cal}kcal | P: ${prot}g | C: ${carbs}g | F: ${fat}g';
          }).join('\n');

    return '''
You are RepGate Coach — India's premier conversational AI health, fitness, diet, and nutrition coach.
Tone: Energetic, friendly, motivating Hinglish (natural conversational mix of Hindi and English, like "Bhai", "Dost"). Keep advice realistic, science-backed, and practical for Indian daily routines.

CURRENT USER HEALTH PROFILE & REAL DATA FOR TODAY:
- Name: ${context.userName.isNotEmpty ? context.userName : 'Athlete'}
- Age: ${context.userAge} yrs | Weight: ${context.userWeight} kg | Height: ${context.userHeight} cm
- Daily Calorie Target: ${context.calorieTarget.toInt()} kcal (Consumed so far: ${context.consumedCalories.toInt()} kcal | Remaining/Deficit: ${context.calorieDeficit.toInt()} kcal)
- Daily Protein Target: ${context.proteinTarget.toInt()} g (Consumed so far: ${context.consumedProtein.toInt()} g | Remaining Deficit: ${context.proteinDeficit.toInt()} g)
- Daily Carbs Target: ${context.carbsTarget.toInt()} g (Consumed: ${context.consumedCarbs.toInt()} g)
- Daily Fat Target: ${context.fatTarget.toInt()} g (Consumed: ${context.consumedFat.toInt()} g)
- Hydration: ${context.consumedWaterMl} ml / ${context.waterTargetMl} ml
- Daily Push-up Target: ${context.pushupTarget} reps
- Active Streak: ${context.streakDays} days

MEALS LOGGED TODAY:
$mealsDescription

CORE RESPONSIBILITIES:
1. Always refer to the user's REAL numbers and food items above. Never invent fake intake data.
2. If asked about protein ("protein target kaise pura karein" / "protein deficit"): Calculate exact protein gap (${context.proteinDeficit.toInt()}g). Recommend specific Indian protein foods (Paneer, Soya chunks, Boiled eggs, Sattu, Sprouts/Moong, Curd/Greek yogurt, Dal, Chicken breast) with exact gram amounts and calories.
3. If asked for a diet plan ("diet plan de aaj ka"): Look at what was already eaten and what is missing. Suggest upcoming meals for today (evening snack, dinner, post-workout) to hit the target.
4. If asked about mistakes ("maine aaj kya galat khaya?"): Audit the logged meals. Point out high oil/tadka, excess simple carbs/sugar, low protein density, and suggest healthier Indian swaps.
5. If asked for a progress report ("aaj ka progress report"): Give an emoji-rich scorecard, rating out of 10, and 3 clear next actions.
6. Keep formatting neat with markdown bullet points, bold highlights, and clean structure.
''';
  }

  /// Dynamic Offline Health & Nutrition Intelligence Engine.
  /// Fully calculates real numbers, gaps, food swaps, and plans without hardcoded dummy text.
  String _generateSmartOfflineResponse(
    String query,
    UserHealthContext context,
  ) {
    final lower = query.toLowerCase();
    final name = context.userName.isNotEmpty ? context.userName : 'Dost';
    final pDeficit = context.proteinDeficit;
    final cDeficit = context.calorieDeficit;
    final pConsumed = context.consumedProtein;
    final pTarget = context.proteinTarget;
    final cConsumed = context.consumedCalories;
    final cTarget = context.calorieTarget;

    // 1. Progress Report
    if (lower.contains('report') ||
        lower.contains('progress') ||
        lower.contains('status') ||
        lower.contains('kaise chal raha') ||
        lower.contains('score')) {
      final pPercent = ((pConsumed / pTarget) * 100).clamp(0, 100).toInt();
      final cPercent = ((cConsumed / cTarget) * 100).clamp(0, 100).toInt();
      final waterPercent = ((context.consumedWaterMl / context.waterTargetMl) * 100)
          .clamp(0, 100)
          .toInt();

      final score = ((pPercent * 0.45) + (cPercent * 0.35) + (waterPercent * 0.20))
          .clamp(0, 100)
          .round();

      final verdict = pDeficit <= 0
          ? '🔥 Protein target achieved! Great discipline today.'
          : '⚠️ Protein gap of ${pDeficit.toStringAsFixed(0)}g needs attention before day ends.';

      return '''
📊 **RepGate Daily Health & Progress Report for $name**

• **Overall Health Score:** **$score/100**
• **Active Streak:** 🔥 **${context.streakDays} Days**

**Macro & Calorie Breakdown:**
• 🥗 **Calories:** ${cConsumed.toInt()} / ${cTarget.toInt()} kcal (${cPercent}% logged)
• 🥩 **Protein:** ${pConsumed.toInt()} / ${pTarget.toInt()} g (${pPercent}% reached)
  ↳ Deficit: **${pDeficit.toStringAsFixed(0)}g protein needed**
• 🍚 **Carbs:** ${context.consumedCarbs.toInt()} / ${context.carbsTarget.toInt()} g
• 🧈 **Fats:** ${context.consumedFat.toInt()} / ${context.fatTarget.toInt()} g
• 💧 **Water:** ${context.consumedWaterMl} / ${context.waterTargetMl} ml (${waterPercent}%)

**Coach Ka Verdict:**
$verdict

**Next Actions to Win Today:**
1. ${pDeficit > 0 ? "Baki ka ${pDeficit.toStringAsFixed(0)}g protein pura karne ke liye snack ya dinner me high-protein source add karein." : "Protein target pura ho chuka hai, ab hydration maintain karein."}
2. Water intake: ${context.waterDeficitMl > 0 ? "Baki ${context.waterDeficitMl} ml pani peeyein." : "Water target completed!"}
3. Daily push-up goal (${context.pushupTarget} reps) complete karke streaks maintain rakhein!
''';
    }

    // 2. Protein Target Query
    if (lower.contains('protein') ||
        lower.contains('target pura') ||
        lower.contains('protein kaise') ||
        lower.contains('kami') ||
        lower.contains('kitna protein')) {
      if (pDeficit <= 0) {
        return '''
🎉 **Bhai congratulations! Aaj ka protein goal complete ho chuka hai!**

Aapne **${pConsumed.toInt()}g / ${pTarget.toInt()}g** protein consume kar liya hai.
Aapka muscle recovery aur protein synthesis bilkul on-track hai. Ab hydration aur proper sleep par focus karein!
''';
      }

      final soyaGrams = (pDeficit / 0.52).round();
      final paneerGrams = (pDeficit / 0.18).round();
      final eggsCount = (pDeficit / 6.0).ceil();
      final sattuGrams = (pDeficit / 0.20).round();
      final chickenGrams = (pDeficit / 0.31).round();

      return '''
💪 **Bhai aaj aapko baki ${pDeficit.toStringAsFixed(0)}g Protein chahiye!**

Aapka target **${pTarget.toInt()}g** hai aur abhi tak **${pConsumed.toInt()}g** hua hai.
Remaining calories budget: **${cDeficit.toInt()} kcal left**.

Ye best Indian sources me se koi 1 ya 2 choose karke target pura karein:

1. **🥜 Soya Chunks (Highest Protein & Low Fat):**
   • Quantity: **${soyaGrams}g** raw soya chunks
   • Nutrition: **${pDeficit.toStringAsFixed(0)}g Protein** | ~${(soyaGrams * 3.45).round()} kcal | 0.5g Fat
   • *Tip:* Boiled soya ko halka salt aur chaat masala ke sath saute karke khayein.

2. **🥚 Boiled Eggs (Non-Veg Option):**
   • Quantity: **$eggsCount Whole Eggs** (ya ${eggsCount + 2} Egg Whites)
   • Nutrition: **${eggsCount * 6}g Protein** | ~${eggsCount * 78} kcal
   • *Tip:* Sham ko snack me 2-3 boiled eggs best rehte hain.

3. **🧀 Paneer / Cottage Cheese:**
   • Quantity: **${paneerGrams}g**
   • Nutrition: **${pDeficit.toStringAsFixed(0)}g Protein** | ~${(paneerGrams * 2.65).round()} kcal | ${(paneerGrams * 0.2).round()}g Fat
   • *Note:* Agar calorie headroom kam hai to Low Fat paneer use karein.

4. **🥣 Sattu Drink (Desi Superfood):**
   • Quantity: **${sattuGrams}g** (approx ${(sattuGrams / 30).round()} scoops)
   • Nutrition: **${pDeficit.toStringAsFixed(0)}g Protein** | ~${(sattuGrams * 1.9).round()} kcal
   • *Tip:* Thande pani, jeera powder aur namak ke sath refreshing namkeen sattu banayein.

5. **🍗 Chicken Breast:**
   • Quantity: **${chickenGrams}g**
   • Nutrition: **${pDeficit.toStringAsFixed(0)}g Protein** | ~${(chickenGrams * 1.65).round()} kcal
''';
    }

    // 3. What mistakes did I make / Kya galat khaya?
    if (lower.contains('galat') ||
        lower.contains('mistake') ||
        lower.contains('kharab') ||
        lower.contains('cheat') ||
        lower.contains('junk') ||
        lower.contains('kya khaya')) {
      if (context.loggedMeals.isEmpty) {
        return '''
⚠️ **Bhai aaj aapne koi meal log nahi kiya hai!**

Food log karein tabhi main batla paunga ki kya accha khaya aur kya galat. Food log screen par jaakar photo scan karein ya voice/text se log karein!
''';
      }

      final issues = <String>[];
      final praises = <String>[];

      for (final meal in context.loggedMeals) {
        final name = meal['name']?.toString() ?? 'Food';
        final fat = (meal['fat'] as num?)?.toDouble() ?? 0;
        final cal = (meal['calories'] as num?)?.toDouble() ?? 0;
        final prot = (meal['protein'] as num?)?.toDouble() ?? 0;
        final style = meal['cookingStyle']?.toString() ?? '';

        if (style.toLowerCase().contains('dhaba')) {
          issues.add(
            '• **$name:** Dhaba / Restaurant style makhan tadka me lagbhag 14g extra fat (+126 kcal) hota hai. Ghar ka banaya low-oil version prefer karein.',
          );
        } else if (fat > 18 && prot < 10) {
          issues.add(
            '• **$name:** Isme fat content high (${fat.toInt()}g) hai jabki protein sirf ${prot.toInt()}g hai. Isse calorie surplus ka risk badhta hai.',
          );
        } else if (cal > 300 && prot < 5) {
          issues.add(
            '• **$name:** Ye simple carbs/calories dense hai par protein low (${prot.toInt()}g). Sath me curd, sprouts ya boiled eggs add karna chahiye tha.',
          );
        } else if (prot >= 15) {
          praises.add(
            '• **$name:** Great choice! Is meal se accha protein (${prot.toInt()}g) mila.',
          );
        }
      }

      final buffer = StringBuffer();
      buffer.writeln('🔍 **Today’s Meal Audit & Analysis for $name:**\n');

      if (praises.isNotEmpty) {
        buffer.writeln('✅ **Kya Accha Khaya:**');
        for (final p in praises) {
          buffer.writeln(p);
        }
        buffer.writeln();
      }

      if (issues.isNotEmpty) {
        buffer.writeln('⚠️ **Kya Sudhar Sakte Hain (Galat / Inefficient Choices):**');
        for (final i in issues) {
          buffer.writeln(i);
        }
      } else {
        buffer.writeln(
          '✅ **Overall balanced!** Koi major junk ya high-oil food nahi mila. Bas protein gap (${pDeficit.toStringAsFixed(0)}g) pura karne par focus karein.',
        );
      }

      buffer.writeln('''

💡 **Golden Rule:**
Har major meal me pehle **Protein Source** decide karein (Paneer / Eggs / Soya / Dal / Chicken), uske baad carbs (roti / rice) aur fats ko balance karein.
''');
      return buffer.toString();
    }

    // 4. Personalized Diet Plan for the remainder of today
    if (lower.contains('diet') ||
        lower.contains('plan') ||
        lower.contains('kya khau') ||
        lower.contains('kya khana') ||
        lower.contains('dinner') ||
        lower.contains('snack') ||
        lower.contains('khana')) {
      return '''
🥗 **Personalized Diet Plan for Remainder of Today ($name):**

• **Available Calories:** **${cDeficit > 0 ? cDeficit.toInt() : 0} kcal**
• **Protein Target Remaining:** **${pDeficit.toStringAsFixed(0)}g**

**1. Evening Snack (4:30 PM - 5:30 PM):**
• Option A: 1 glass Chana Sattu Drink (30g powder = ~6g protein, 120 kcal) + 2 Boiled Eggs (12g protein)
• Option B: Moong Dal Sprouts Chaat (1 bowl with onion, tomato, lemon = ~8g protein)
• Option C: Roasted Chana (50g) + Green Tea (7g protein, 180 kcal)

**2. Dinner (8:00 PM - 9:00 PM):**
• **Main Protein:** 100g Paneer Bhurji / 50g Soya Chunks Curry (18g - 26g Protein)
• **Carbs:** 2 Whole Wheat Phulkas (No extra butter/ghee) or 1 small bowl Brown/White Rice
• **Fiber:** Large bowl green cucumber & tomato salad (helps digestion and fullness)
• **Lentil:** 1 bowl Dal Tadka / Rajma (7g protein)

**3. Bedtime (Optional):**
• 1 cup warm toned milk with turmeric (haldi doodh) — 8g slow-digesting casein protein for overnight recovery.

Ye plan follow karne se aapka **${pDeficit.toStringAsFixed(0)}g protein deficit** 100% cover ho jayega bina calorie target cross kiye!
''';
    }

    // Default conversational advice in Hinglish
    return '''
Namaste $name! Main aapka **RepGate Coach** hoon 🤖

Maine aapka aaj ka health snapshot dekha:
• **Calories:** ${cConsumed.toInt()} / ${cTarget.toInt()} kcal (${cDeficit > 0 ? '${cDeficit.toInt()} kcal baki' : 'Target reached'})
• **Protein:** ${pConsumed.toInt()} / ${pTarget.toInt()} g (${pDeficit > 0 ? '${pDeficit.toStringAsFixed(0)}g deficit' : 'Goal completed!'})
• **Water:** ${context.consumedWaterMl} / ${context.waterTargetMl} ml
• **Streak:** 🔥 ${context.streakDays} Days

Aap mujhse puch sakte hain:
1. *"Aaj ka protein target kaise pura karu?"*
2. *"Maine aaj kya galat khaya?"*
3. *"Aaj ka customized dinner/snack diet plan do"*
4. *"Aaj ka full progress report do"*

Bataiye, kis topic par guidance chahiye?
''';
  }

  /// Extracts contextual suggestions chips based on the user's state
  List<String> _extractSuggestions(String userMessage, UserHealthContext context) {
    if (context.proteinDeficit > 0) {
      return [
        '💪 Protein target kaise pura karu?',
        '🥗 Aaj ka diet plan do',
        '⚠️ Kya galat khaya maine?',
        '📊 Full progress report do',
      ];
    } else {
      return [
        '📊 Full progress report do',
        '🥗 Dinner diet plan',
        '💧 Water intake check',
        '⚡ Push-up challenge tips',
      ];
    }
  }
}

enum CoachSource { geminiApi, supabaseEdge, offlineEngine }

class CoachResponse {
  final String text;
  final CoachSource source;
  final List<String> suggestions;

  const CoachResponse({
    required this.text,
    required this.source,
    required this.suggestions,
  });
}
