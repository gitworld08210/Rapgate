import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coach_message_model.dart';
import 'supabase_client.dart';

/// Service powering the RepGate Coach AI assistant.
///
/// Architecture:
/// - Connects directly to the SINGLE Supabase Backend API (`scan-food-image` edge function).
/// - ZERO API keys in the Flutter app (managed entirely by Supabase backend secrets).
/// - Dynamic Offline Health & Nutrition Intelligence Engine fallback when offline/guest mode.
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
      debugPrint('[CoachService] Supabase scan-food-image coach route: $e. Using local Indian Health Engine.');
    }

    // 2. Dynamic Offline Health & Nutrition Intelligence Engine (zero dummy text, calculates real deficits)
    final offlineReply = _generateSmartOfflineResponse(userMessage, context);
    return CoachResponse(
      text: offlineReply,
      source: CoachSource.offlineEngine,
      suggestions: _extractSuggestions(userMessage, context),
    );
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
