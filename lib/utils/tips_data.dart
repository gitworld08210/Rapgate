/// Health tips data and context-aware selection logic.

enum TipCategory { hydration, protein, streaks, pushups, wellness, scanning }

class HealthTip {
  final String emoji;
  final String title;
  final String body;
  final TipCategory category;

  const HealthTip({
    required this.emoji,
    required this.title,
    required this.body,
    required this.category,
  });
}

/// 54 tips distributed across all categories.
const List<HealthTip> allTips = [
  // ---- Hydration (9) ----
  HealthTip(
    emoji: '💧',
    title: 'Boost Your Metabolism',
    body: 'Water boosts metabolism by up to 30% for the next hour.',
    category: TipCategory.hydration,
  ),
  HealthTip(
    emoji: '🚰',
    title: 'Stay Sharp',
    body: 'Even mild dehydration reduces cognitive performance by 15%.',
    category: TipCategory.hydration,
  ),
  HealthTip(
    emoji: '💦',
    title: 'Performance Matters',
    body: 'Dehydration reduces exercise performance by 25%.',
    category: TipCategory.hydration,
  ),
  HealthTip(
    emoji: '🥤',
    title: 'Morning Hydration',
    body: 'Drinking water first thing kick-starts your organs after sleep.',
    category: TipCategory.hydration,
  ),
  HealthTip(
    emoji: '💧',
    title: 'Hunger vs Thirst',
    body: '75% of the time you feel hungry, your body is actually thirsty.',
    category: TipCategory.hydration,
  ),
  HealthTip(
    emoji: '🌊',
    title: 'Skin Glow',
    body: 'Proper hydration can improve skin elasticity within 2 weeks.',
    category: TipCategory.hydration,
  ),
  HealthTip(
    emoji: '💧',
    title: 'Headache Prevention',
    body: 'Most afternoon headaches are caused by dehydration, not stress.',
    category: TipCategory.hydration,
  ),
  HealthTip(
    emoji: '🧊',
    title: 'Cold Water Burn',
    body: 'Cold water burns a few extra calories as your body warms it up.',
    category: TipCategory.hydration,
  ),
  HealthTip(
    emoji: '🚿',
    title: 'Joint Health',
    body: 'Water helps lubricate joints and reduces post-workout stiffness.',
    category: TipCategory.hydration,
  ),

  // ---- Protein (9) ----
  HealthTip(
    emoji: '🍗',
    title: 'Post-Workout Window',
    body: 'Eating protein within 30 min of a workout maximizes muscle repair.',
    category: TipCategory.protein,
  ),
  HealthTip(
    emoji: '🥛',
    title: 'Greek Yogurt Power',
    body: 'Greek yogurt has 2x the protein of regular yogurt.',
    category: TipCategory.protein,
  ),
  HealthTip(
    emoji: '🥚',
    title: 'Complete Protein',
    body: 'Eggs contain all 9 essential amino acids your body needs.',
    category: TipCategory.protein,
  ),
  HealthTip(
    emoji: '🫘',
    title: 'Plant Protein',
    body: 'Lentils pack 18g of protein per cooked cup - more than most meats per calorie.',
    category: TipCategory.protein,
  ),
  HealthTip(
    emoji: '🍗',
    title: 'Thermic Effect',
    body: 'Protein burns 20-30% of its calories during digestion alone.',
    category: TipCategory.protein,
  ),
  HealthTip(
    emoji: '🧀',
    title: 'Paneer Power',
    body: 'Paneer has 18g protein per 100g - a great vegetarian option.',
    category: TipCategory.protein,
  ),
  HealthTip(
    emoji: '🐟',
    title: 'Omega-3 Bonus',
    body: 'Fish gives you protein plus omega-3 fats for brain health.',
    category: TipCategory.protein,
  ),
  HealthTip(
    emoji: '🥜',
    title: 'Snack Smart',
    body: 'A handful of almonds has 6g of protein and keeps hunger at bay.',
    category: TipCategory.protein,
  ),
  HealthTip(
    emoji: '🍳',
    title: 'Spread It Out',
    body: 'Spreading protein across meals improves absorption by up to 25%.',
    category: TipCategory.protein,
  ),

  // ---- Streaks (9) ----
  HealthTip(
    emoji: '🔥',
    title: 'Consistency Wins',
    body: 'Missing one day does not break progress - just do not miss two.',
    category: TipCategory.streaks,
  ),
  HealthTip(
    emoji: '📈',
    title: 'Habit Science',
    body: 'People with 21+ day streaks are 6x more likely to maintain habits.',
    category: TipCategory.streaks,
  ),
  HealthTip(
    emoji: '🏆',
    title: 'You Are Unstoppable',
    body: 'Your streak proves discipline is a muscle you have been building.',
    category: TipCategory.streaks,
  ),
  HealthTip(
    emoji: '⚡',
    title: 'Momentum Effect',
    body: 'Each day you show up, the next one becomes 4% easier.',
    category: TipCategory.streaks,
  ),
  HealthTip(
    emoji: '🎯',
    title: 'Identity Shift',
    body: 'After 30 days, a habit becomes part of your identity, not just a task.',
    category: TipCategory.streaks,
  ),
  HealthTip(
    emoji: '💪',
    title: 'Compound Growth',
    body: '1% better every day = 37x better in a year.',
    category: TipCategory.streaks,
  ),
  HealthTip(
    emoji: '🌟',
    title: 'Top Performer',
    body: 'You are in the top 5% of users who show up daily. Keep going!',
    category: TipCategory.streaks,
  ),
  HealthTip(
    emoji: '🔥',
    title: 'Streak Protection',
    body: 'Your future self will thank you for not breaking the chain today.',
    category: TipCategory.streaks,
  ),
  HealthTip(
    emoji: '🚀',
    title: 'Discipline > Motivation',
    body: 'Motivation fades. Your streak shows that discipline stays.',
    category: TipCategory.streaks,
  ),

  // ---- Push-ups (9) ----
  HealthTip(
    emoji: '💪',
    title: '200+ Muscles',
    body: 'Push-ups activate over 200 muscles simultaneously.',
    category: TipCategory.pushups,
  ),
  HealthTip(
    emoji: '❤️',
    title: 'Heart Health',
    body: 'Doing push-ups daily can reduce heart disease risk by 96%.',
    category: TipCategory.pushups,
  ),
  HealthTip(
    emoji: '🏋️',
    title: 'No Equipment Needed',
    body: 'Push-ups build chest, shoulders, triceps, and core without a gym.',
    category: TipCategory.pushups,
  ),
  HealthTip(
    emoji: '⏰',
    title: 'Quick Win',
    body: '10 push-ups take under 30 seconds but improve your whole day.',
    category: TipCategory.pushups,
  ),
  HealthTip(
    emoji: '🦴',
    title: 'Bone Density',
    body: 'Weight-bearing exercises like push-ups increase bone density.',
    category: TipCategory.pushups,
  ),
  HealthTip(
    emoji: '🧠',
    title: 'Mental Boost',
    body: 'Push-ups release endorphins that improve mood for hours.',
    category: TipCategory.pushups,
  ),
  HealthTip(
    emoji: '📐',
    title: 'Posture Fix',
    body: 'Regular push-ups strengthen the muscles that keep your back straight.',
    category: TipCategory.pushups,
  ),
  HealthTip(
    emoji: '🔄',
    title: 'Progressive Overload',
    body: 'Add 1 push-up per week and you will double your reps in months.',
    category: TipCategory.pushups,
  ),
  HealthTip(
    emoji: '💪',
    title: 'Evening Push-ups',
    body: 'Evening push-ups help burn off stress and improve sleep quality.',
    category: TipCategory.pushups,
  ),

  // ---- Wellness (9) ----
  HealthTip(
    emoji: '😴',
    title: 'Sleep Recovery',
    body: '7-9 hours of sleep is optimal for muscle recovery.',
    category: TipCategory.wellness,
  ),
  HealthTip(
    emoji: '🚶',
    title: 'Step It Up',
    body: 'Walking 10,000 steps burns roughly 400-500 calories.',
    category: TipCategory.wellness,
  ),
  HealthTip(
    emoji: '🧘',
    title: 'Stress Reduction',
    body: '5 minutes of deep breathing lowers cortisol by 20%.',
    category: TipCategory.wellness,
  ),
  HealthTip(
    emoji: '☀️',
    title: 'Morning Sunlight',
    body: '10 min of morning sun regulates circadian rhythm and boosts vitamin D.',
    category: TipCategory.wellness,
  ),
  HealthTip(
    emoji: '🍎',
    title: 'Fiber Matters',
    body: 'Eating 25g of fiber daily reduces disease risk by 30%.',
    category: TipCategory.wellness,
  ),
  HealthTip(
    emoji: '🪑',
    title: 'Move Every Hour',
    body: 'Standing up every 60 min reduces the health risks of sitting by 40%.',
    category: TipCategory.wellness,
  ),
  HealthTip(
    emoji: '🫁',
    title: 'Breathe Deep',
    body: 'Diaphragmatic breathing activates your parasympathetic nervous system.',
    category: TipCategory.wellness,
  ),
  HealthTip(
    emoji: '🥗',
    title: 'Eat the Rainbow',
    body: 'Colorful plates mean diverse micronutrients and antioxidants.',
    category: TipCategory.wellness,
  ),
  HealthTip(
    emoji: '📵',
    title: 'Screen Break',
    body: '20 min away from screens lowers eye strain and mental fatigue.',
    category: TipCategory.wellness,
  ),

  // ---- Scanning (9) ----
  HealthTip(
    emoji: '📸',
    title: 'Awareness Boost',
    body: 'Scanning food makes you 3x more aware of portion sizes.',
    category: TipCategory.scanning,
  ),
  HealthTip(
    emoji: '🍽️',
    title: 'Fullness Combo',
    body: 'Protein and fiber together keep you full the longest.',
    category: TipCategory.scanning,
  ),
  HealthTip(
    emoji: '📊',
    title: 'Track to Transform',
    body: 'People who log food lose 2x more weight than those who do not.',
    category: TipCategory.scanning,
  ),
  HealthTip(
    emoji: '🏷️',
    title: 'Label Literacy',
    body: 'Scanning reveals hidden sugars in "healthy" packaged foods.',
    category: TipCategory.scanning,
  ),
  HealthTip(
    emoji: '📱',
    title: 'Quick Scan',
    body: 'It takes 5 seconds to scan a meal and a lifetime to benefit from the data.',
    category: TipCategory.scanning,
  ),
  HealthTip(
    emoji: '🔍',
    title: 'Portion Truth',
    body: 'Most people underestimate calories by 40% without tracking.',
    category: TipCategory.scanning,
  ),
  HealthTip(
    emoji: '📈',
    title: 'Data-Driven Gains',
    body: 'After 7 days of scanning, you spot patterns that transform your diet.',
    category: TipCategory.scanning,
  ),
  HealthTip(
    emoji: '🎯',
    title: 'Accuracy Wins',
    body: 'Consistent scanning builds an accurate picture of your nutrition.',
    category: TipCategory.scanning,
  ),
  HealthTip(
    emoji: '🧮',
    title: 'Macro Mastery',
    body: 'Scanning teaches you to estimate macros by sight over time.',
    category: TipCategory.scanning,
  ),
];

/// Picks a context-aware tip based on the user's current health data.
///
/// Priority order:
/// 1. Hydration reminder if water < 50% and it is afternoon (>= 14:00)
/// 2. Protein tip if protein < 50% of target and it is past noon (>= 12:00)
/// 3. Streak encouragement if current streak > 7
/// 4. Push-up reminder if not done and it is evening (>= 18:00)
/// 5. Default: deterministic daily rotation based on day of year
HealthTip pickContextualTip({
  required double waterProgress,
  required double proteinProgress,
  required int currentStreak,
  required bool pushupsDone,
}) {
  final now = DateTime.now();
  final hour = now.hour;

  // Hydration nudge in the afternoon
  if (waterProgress < 0.5 && hour >= 14) {
    final hydrationTips =
        allTips.where((t) => t.category == TipCategory.hydration).toList();
    return hydrationTips[now.day % hydrationTips.length];
  }

  // Protein nudge past noon
  if (proteinProgress < 0.5 && hour >= 12) {
    final proteinTips =
        allTips.where((t) => t.category == TipCategory.protein).toList();
    return proteinTips[now.day % proteinTips.length];
  }

  // Streak encouragement
  if (currentStreak > 7) {
    final streakTips =
        allTips.where((t) => t.category == TipCategory.streaks).toList();
    return streakTips[now.day % streakTips.length];
  }

  // Push-up reminder in the evening
  if (!pushupsDone && hour >= 18) {
    final pushupTips =
        allTips.where((t) => t.category == TipCategory.pushups).toList();
    return pushupTips[now.day % pushupTips.length];
  }

  // Default: deterministic daily rotation
  final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
  return allTips[dayOfYear % allTips.length];
}
