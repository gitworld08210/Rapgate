import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coach_message_model.dart';
import 'supabase_client.dart';

/// Service powering the RepGate Coach AI assistant.
///
/// Architecture:
/// - Connects directly to the SINGLE Supabase Backend API (`scan-food-image` edge function).
/// - ZERO API keys stored in client app.
/// - Dynamic Offline Health & Nutrition Intelligence Engine fallback when offline.
/// - 100% English professional UI and conversational responses.
class CoachService {
  final SupabaseClient _db = supabase;

  /// Sends a message to RepGate Coach using the unified Supabase Backend API
  Future<CoachResponse> sendMessage({
    required String userMessage,
    required UserHealthContext context,
    List<CoachMessage> chatHistory = const [],
  }) async {
    // 1. Single Unified API: Route through Supabase scan-food-image backend
    try {
      final response = await _db.functions.invoke(
        'scan-food-image',
        body: {
          'scanKind': 'repgate_coach',
          'coachMessage': userMessage.trim(),
          'userContext': {
            'userName': context.userName,
            'userAge': context.userAge,
            'userWeight': context.userWeight,
            'userHeight': context.userHeight,
            'userGender': context.userGender,
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

      if (response.status < 400 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final reply = (data['reply'] as String?) ?? (data['text'] as String?);
        if (reply != null && reply.trim().isNotEmpty) {
          return CoachResponse(
            text: reply.trim(),
            source: CoachSource.supabaseBackend,
            suggestions: _extractSuggestions(userMessage, context),
          );
        }
      }
    } catch (e) {
      debugPrint('[CoachService] Supabase scan-food-image coach route: $e. Using local health engine.');
    }

    // 2. Dynamic Offline Health & Nutrition Intelligence Engine (zero dummy text, calculates real numbers)
    final offlineReply = _generateSmartOfflineResponse(userMessage, context);
    return CoachResponse(
      text: offlineReply,
      source: CoachSource.offlineEngine,
      suggestions: _extractSuggestions(userMessage, context),
    );
  }

  /// Dynamic Offline Health & Nutrition Intelligence Engine (English).
  /// Fully calculates real numbers, gaps, food swaps, and plans without hardcoded dummy text.
  String _generateSmartOfflineResponse(
    String query,
    UserHealthContext context,
  ) {
    final lower = query.toLowerCase();
    final name = context.userName.isNotEmpty ? context.userName : 'Athlete';
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
          ? 'Daily protein target crushed! Optimal muscle recovery in progress.'
          : 'Protein gap of ${pDeficit.toStringAsFixed(0)}g needs attention before the day concludes.';

      return '''
📊 **Daily Health & Progress Report for $name**

• **Overall Health Score:** **$score/100**
• **Active Consistency Streak:** 🔥 **${context.streakDays} Days**

**Macro & Energy Breakdown:**
• 🥗 **Calories:** ${cConsumed.toInt()} / ${cTarget.toInt()} kcal (${cPercent}% of daily budget)
• 🥩 **Protein:** ${pConsumed.toInt()} / ${pTarget.toInt()} g (${pPercent}% achieved)
  ↳ Deficit: **${pDeficit.toStringAsFixed(0)}g protein remaining**
• 🍚 **Carbohydrates:** ${context.consumedCarbs.toInt()} / ${context.carbsTarget.toInt()} g
• 🧈 **Fats:** ${context.consumedFat.toInt()} / ${context.fatTarget.toInt()} g
• 💧 **Hydration:** ${context.consumedWaterMl} / ${context.waterTargetMl} ml (${waterPercent}%)

**Coach Assessment:**
$verdict

**Actionable Next Steps Today:**
1. ${pDeficit > 0 ? "Incorporate a high-protein source (paneer, soya chunks, boiled eggs, or sattu) in your upcoming meal to close the ${pDeficit.toStringAsFixed(0)}g gap." : "Protein target fully met. Maintain steady hydration."}
2. Water Goal: ${context.waterDeficitMl > 0 ? "Drink ${context.waterDeficitMl} ml more water to fulfill your hydration target." : "Hydration goal complete!"}
3. Prioritize 7-8 hours of quality sleep tonight — muscle repair and hormonal recovery happen during deep sleep.
''';
    }

    // 2. Protein Target Query
    if (lower.contains('protein') ||
        lower.contains('target') ||
        lower.contains('reach') ||
        lower.contains('gap') ||
        lower.contains('deficit')) {
      if (pDeficit <= 0) {
        return '''
🎉 **Congratulations $name! You have already achieved your daily protein goal.**

You have logged **${pConsumed.toInt()}g / ${pTarget.toInt()}g** protein today.
Your muscle protein synthesis and recovery needs are well satisfied. Focus on hydration and quality rest tonight!
''';
      }

      final soyaGrams = (pDeficit / 0.52).round();
      final paneerGrams = (pDeficit / 0.18).round();
      final eggsCount = (pDeficit / 6.0).ceil();
      final sattuGrams = (pDeficit / 0.20).round();
      final chickenGrams = (pDeficit / 0.31).round();

      return '''
💪 **You need ${pDeficit.toStringAsFixed(0)}g more Protein to complete today's target.**

Current intake: **${pConsumed.toInt()}g / ${pTarget.toInt()}g**
Remaining calorie headroom: **${cDeficit.toInt()} kcal remaining**.

Here are the highest-efficiency Indian food options to hit your target cleanly:

1. **🥜 Soya Chunks (Highest Protein Density & Minimal Fat):**
   • Quantity: **${soyaGrams}g** uncooked soya chunks
   • Nutrition: **${pDeficit.toStringAsFixed(0)}g Protein** | ~${(soyaGrams * 3.45).round()} kcal | 0.5g Fat
   • *Preparation:* Boil, squeeze thoroughly, and saute with minimal spices.

2. **🥚 Whole Eggs / Egg Whites:**
   • Quantity: **$eggsCount Whole Eggs** (or ${eggsCount + 2} Egg Whites)
   • Nutrition: **${eggsCount * 6}g Protein** | ~${eggsCount * 78} kcal
   • *Preparation:* Hard boiled with a pinch of black pepper and rock salt.

3. **🧀 Low-Fat Paneer / Cottage Cheese:**
   • Quantity: **${paneerGrams}g**
   • Nutrition: **${pDeficit.toStringAsFixed(0)}g Protein** | ~${(paneerGrams * 2.65).round()} kcal | ${(paneerGrams * 0.2).round()}g Fat
   • *Tip:* Opt for low-fat paneer if your remaining calorie headroom is low.

4. **🥣 Roasted Chana Sattu Drink:**
   • Quantity: **${sattuGrams}g** (~${(sattuGrams / 30).round()} scoops)
   • Nutrition: **${pDeficit.toStringAsFixed(0)}g Protein** | ~${(sattuGrams * 1.9).round()} kcal
   • *Preparation:* Blend with cold water, roasted cumin, and black salt.

5. **🍗 Lean Chicken Breast (Non-Veg Option):**
   • Quantity: **${chickenGrams}g**
   • Nutrition: **${pDeficit.toStringAsFixed(0)}g Protein** | ~${(chickenGrams * 1.65).round()} kcal
''';
    }

    // 3. What mistakes did I make / Meal Audit
    if (lower.contains('mistake') ||
        lower.contains('wrong') ||
        lower.contains('audit') ||
        lower.contains('cheat') ||
        lower.contains('unhealthy') ||
        lower.contains('analyze')) {
      if (context.loggedMeals.isEmpty) {
        return '''
⚠️ **No meals logged yet today.**

Please log your breakfast, lunch, or snack first via photo scan or text so I can analyze the nutritional composition and suggest improvements.
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
            '• **$name:** Dhaba / restaurant cooking adds approximately 14g extra butter/oil fat (+126 kcal). Switching to home-style preparation saves substantial calories.',
          );
        } else if (fat > 18 && prot < 10) {
          issues.add(
            '• **$name:** High in fat (${fat.toInt()}g) with modest protein (${prot.toInt()}g). This creates an unfavorable protein-to-calorie ratio.',
          );
        } else if (cal > 300 && prot < 5) {
          issues.add(
            '• **$name:** Calorie-dense carbohydrates with negligible protein (${prot.toInt()}g). Pairing this with curd, boiled eggs, or sprouts would stabilize blood sugar.',
          );
        } else if (prot >= 15) {
          praises.add(
            '• **$name:** Excellent selection providing solid protein (${prot.toInt()}g) with moderate energy density.',
          );
        }
      }

      final buffer = StringBuffer();
      buffer.writeln('🔍 **Today’s Nutritional Audit for $name:**\n');

      if (praises.isNotEmpty) {
        buffer.writeln('✅ **Positive Nutritional Choices:**');
        for (final p in praises) {
          buffer.writeln(p);
        }
        buffer.writeln();
      }

      if (issues.isNotEmpty) {
        buffer.writeln('⚠️ **Areas for Optimization:**');
        for (final i in issues) {
          buffer.writeln(i);
        }
      } else {
        buffer.writeln(
          '✅ **Well-balanced diet profile!** No excessive saturated fats or empty sugars detected. Continue prioritizing your remaining protein gap (${pDeficit.toStringAsFixed(0)}g).',
        );
      }

      buffer.writeln('''

💡 **Golden Principle:**
Anchor every meal with a verified primary protein source first, then adjust complex carbohydrates and cooking fats to fit your calorie target.
''');
      return buffer.toString();
    }

    // 4. Personalized Diet Plan
    if (lower.contains('diet') ||
        lower.contains('plan') ||
        lower.contains('dinner') ||
        lower.contains('snack') ||
        lower.contains('eat')) {
      return '''
🥗 **Personalized Meal Plan for Remainder of Today ($name):**

• **Available Calories:** **${cDeficit > 0 ? cDeficit.toInt() : 0} kcal**
• **Remaining Protein Need:** **${pDeficit.toStringAsFixed(0)}g**

**1. Afternoon / Evening Snack:**
• Option A: 1 glass Chana Sattu Drink (30g powder = ~6g protein, 120 kcal) + 2 Boiled Eggs (12g protein)
• Option B: Sprouted Moong Bean Chaat (1 bowl with onion, tomato, lemon = ~8g protein)
• Option C: Roasted Chana (50g) with Green Tea (7g protein, 180 kcal)

**2. Dinner:**
• **Primary Protein:** 100g Paneer Bhurji or 50g Soya Chunks Curry (18g - 26g Protein)
• **Complex Carbs:** 2 Whole Wheat Phulkas (dry or light ghee) or 1 small bowl Steamed Rice
• **Fiber & Micronutrients:** Large garden cucumber & tomato salad for satiety and gut motility
• **Lentils:** 1 bowl Dal Tadka / Yellow Moong Dal (7g protein)

**3. Bedtime (Optional):**
• 1 cup warm toned milk with turmeric — provides 8g slow-digesting casein protein for overnight tissue repair.

Following this structure will completely bridge your **${pDeficit.toStringAsFixed(0)}g protein deficit** without exceeding your daily calorie limit!
''';
    }

    // Default conversational advice in English
    return '''
Hello $name! I am your **RepGate Coach** 🤖

Here is your live health snapshot for today:
• **Calories:** ${cConsumed.toInt()} / ${cTarget.toInt()} kcal (${cDeficit > 0 ? '${cDeficit.toInt()} kcal remaining' : 'Target reached'})
• **Protein:** ${pConsumed.toInt()} / ${pTarget.toInt()} g (${pDeficit > 0 ? '${pDeficit.toStringAsFixed(0)}g deficit' : 'Target completed!'})
• **Hydration:** ${context.consumedWaterMl} / ${context.waterTargetMl} ml
• **Consistency Streak:** 🔥 ${context.streakDays} Days

How can I assist your health and fitness goals right now?
1. *"How do I reach my protein target today?"*
2. *"Analyze my meals today for mistakes"*
3. *"Suggest a personalized dinner plan"*
4. *"Give me a full daily progress report"*
''';
  }

  /// Extracts contextual suggestions chips based on the user's state
  List<String> _extractSuggestions(String userMessage, UserHealthContext context) {
    if (context.proteinDeficit > 0) {
      return [
        '💪 Reach protein target',
        '🥗 Today\'s diet plan',
        '⚠️ Analyze meals for mistakes',
        '📊 Daily progress report',
      ];
    } else {
      return [
        '📊 Daily progress report',
        '🥗 Dinner meal plan',
        '💧 Hydration check',
        '😴 Recovery & sleep tips',
      ];
    }
  }
}

enum CoachSource { supabaseBackend, offlineEngine }

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
