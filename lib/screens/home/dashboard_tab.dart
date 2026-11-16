import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../providers/health_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/food_log_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/week_strip.dart';
import '../../widgets/calorie_gauge.dart';
import '../../widgets/macro_widgets.dart';
import '../../widgets/meal_widgets.dart';
import '../water/water_tracker_screen.dart';
import '../weight/weight_screen.dart';
import '../food/food_log_screen.dart';
import '../coach/repgate_coach_screen.dart';
import '../../services/fasting_service.dart';

/// Dashboard.
///
/// PERFORMANCE NOTE — why this file is split into many small widgets:
///
/// HealthProvider drives six concurrent Firestore listeners (food, water,
/// weight, push-up session, blocked-apps config, fines) and calls
/// notifyListeners() on every tick of any of them. This screen previously did
/// `context.watch<HealthProvider>()` at the top of build(), so logging a single
/// glass of water rebuilt the entire dashboard — including the CalorieGauge,
/// which is a CustomPaint and therefore repaints.
///
/// Each section below now does its own narrow `context.select`, returning a
/// *record* of scalars. Dart records have structural equality, so a section
/// only rebuilds when the specific numbers it renders actually change.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // Deliberately no context.watch here — see the class doc above.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            const Padding(
              padding: AppSpacing.page,
              child: _GreetingRow(),
            ),

            const SizedBox(height: AppSpacing.xxl),

            Padding(
              padding: AppSpacing.page,
              child: SoftCard(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: WeekStrip(
                  selectedDate: _selectedDate,
                  showMonthHeader: true,
                  onDateSelected: (d) {
                    setState(() => _selectedDate = d);
                    context.read<HealthProvider>().setSelectedDate(d);
                  },
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            const Padding(
              padding: AppSpacing.page,
              child: _NutritionCard(),
            ),

            const SizedBox(height: AppSpacing.lg),

            const Padding(
              padding: AppSpacing.page,
              child: _QuickStats(),
            ),

            const SizedBox(height: AppSpacing.lg),

            const Padding(
              padding: AppSpacing.page,
              child: _StreakCard(),
            ),

            const SizedBox(height: AppSpacing.lg),

            const Padding(
              padding: AppSpacing.page,
              child: _FastingTrackerCard(),
            ),

            const SizedBox(height: AppSpacing.lg),

            const Padding(
              padding: AppSpacing.page,
              child: _RepGateCoachCard(),
            ),

            const SizedBox(height: AppSpacing.xxl),

            Padding(
              padding: AppSpacing.page,
              child: SectionHeader(
                title: "Today's Meals",
                actionLabel: 'See all',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoodLogScreen()),
                ),
              ),
            ),

            const _MealGroups(),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Header
// ===========================================================================

class _GreetingRow extends StatelessWidget {
  const _GreetingRow();

  @override
  Widget build(BuildContext context) {
    final name = context.select<UserProvider, String>(
      (p) => p.userModel?.name ?? '',
    );
    // Select the boolean, not the list — otherwise every fines snapshot
    // would rebuild this row even when the badge state is unchanged.
    final hasFines = context.select<HealthProvider, bool>(
      (p) => p.outstandingFines.isNotEmpty,
    );
    final foodStreak = context.select<UserProvider, int>(
      (p) => p.streaks?.currentFoodLogStreak ?? 0,
    );
    final pushupStreak = context.select<UserProvider, int>(
      (p) => p.streaks?.currentPushupStreak ?? 0,
    );
    final streak = foodStreak > 0 ? foodStreak : pushupStreak;
    final isDark = AppColors.isDark(context);

    return Row(
      children: [
        Expanded(child: GreetingHeader(name: name)),
        if (streak > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.limeWash,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lime),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.limeBright : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        CircleIconButton(
          icon: Icons.notifications_none_rounded,
          showBadge: hasFines,
          bordered: true,
          onTap: () {},
        ),
      ],
    );
  }
}

// ===========================================================================
// Nutrition card — three independently-rebuilding sections
// ===========================================================================

class _NutritionCard extends StatelessWidget {
  const _NutritionCard();

  @override
  Widget build(BuildContext context) {
    return const SoftCard(
      padding: EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        children: [
          _CalorieSection(),
          SizedBox(height: 20),
          _MacroSection(),
          SizedBox(height: 18),
          _HealthScoreSection(),
        ],
      ),
    );
  }
}

/// Owns the CustomPaint gauge, so it is isolated to just calories + target.
class _CalorieSection extends StatelessWidget {
  const _CalorieSection();

  @override
  Widget build(BuildContext context) {
    final cal = context
        .select<HealthProvider, double>((p) => p.currentCalories);
    final isToday = context
        .select<HealthProvider, bool>((p) => p.isSelectedDateToday);
    final target = context.select<UserProvider, double>(
      (p) => p.userModel?.dailyCalorieTarget ?? 2000,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isToday ? 'Today' : 'Selected Date',
                style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${cal.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} kcal',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Center(child: CalorieGauge(consumed: cal, target: target, size: 210)),
        const SizedBox(height: 14),
        CalorieStatRow(eaten: cal, target: target, burned: 0),
      ],
    );
  }
}

class _MacroSection extends StatelessWidget {
  const _MacroSection();

  @override
  Widget build(BuildContext context) {
    final macros = context
        .select<HealthProvider, ({double carbs, double protein, double fat})>(
      (p) => (
        carbs: p.currentCarbs,
        protein: p.currentProtein,
        fat: p.currentFat,
      ),
    );

    return MacroRow(
      carbs: macros.carbs,
      protein: macros.protein,
      fat: macros.fat,
    );
  }
}

class _HealthScoreSection extends StatelessWidget {
  const _HealthScoreSection();

  @override
  Widget build(BuildContext context) {
    final d = context.select<HealthProvider,
        ({double cal, double protein, int water, bool unlocked})>(
      (p) => (
        cal: p.todayTotalCalories,
        protein: p.todayTotalProtein,
        water: p.todayWaterIntakeMl,
        unlocked: p.isAppsUnlocked,
      ),
    );
    final t = context
        .select<UserProvider, ({double cal, double protein})>(
      (p) => (
        cal: p.userModel?.dailyCalorieTarget ?? 2000,
        protein: p.userModel?.dailyProteinTarget ?? 100,
      ),
    );

    return HealthScoreBar(
      score: computeHealthScore(
        calories: d.cal,
        calorieTarget: t.cal,
        protein: d.protein,
        proteinTarget: t.protein,
        waterMl: d.water,
        pushupsDone: d.unlocked,
      ),
    );
  }
}

// ===========================================================================
// Quick stats
// ===========================================================================

class _QuickStats extends StatelessWidget {
  const _QuickStats();

  @override
  Widget build(BuildContext context) {
    final water = context
        .select<HealthProvider, ({int ml, double progress})>(
      (p) => (ml: p.todayWaterIntakeMl, progress: p.waterProgress),
    );
    // Resolve the displayed weight to a double in the selector so this tile
    // doesn't rebuild just because the weight-log list was replaced.
    final weightKg = context.select<HealthProvider, double?>(
      (p) => p.weightLogs.isEmpty ? null : p.weightLogs.first.weightKg,
    );
    final profileWeight = context.select<UserProvider, double>(
      (p) => p.userModel?.weight ?? 0,
    );

    return Row(
      children: [
        Expanded(
          child: QuickStatTile(
            label: 'Drink water',
            value: (water.ml / 1000).toStringAsFixed(1),
            unit: 'L',
            icon: Icons.water_drop_rounded,
            tint: AppColors.water,
            progress: water.progress,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WaterTrackerScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: QuickStatTile(
            label: 'Weight',
            value: (weightKg ?? profileWeight).toStringAsFixed(1),
            unit: 'kg',
            icon: Icons.monitor_weight_rounded,
            tint: AppColors.protein,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeightScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Streak
// ===========================================================================

class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    final foodStreak = context.select<UserProvider, int>(
      (p) => p.streaks?.currentFoodLogStreak ?? 0,
    );
    final pushupStreak = context.select<UserProvider, int>(
      (p) => p.streaks?.currentPushupStreak ?? 0,
    );
    final streak = foodStreak > 0 ? foodStreak : pushupStreak;
    final isFood = foodStreak > 0;

    return Column(
      children: [
        StreakBannerCard(
          streak: streak,
          subtitle: streak > 0
              ? (isFood ? 'FOOD LOGGING STREAK 🔥' : 'ACTIVE STREAK 🔥')
              : 'START YOUR STREAK TODAY',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FoodLogScreen()),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _showShareStoryModal(context, streak),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2640), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.limeDeep.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.share_rounded,
                    color: AppColors.limeBright, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Share Daily Streak & Macro Story',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.limeBright,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'WhatsApp / Insta',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showShareStoryModal(BuildContext context, int streak) {
    final health = context.read<HealthProvider>();
    final user = context.read<UserProvider>().userModel;
    final target = user?.dailyCalorieTarget ?? 2000;
    final eaten = health.todayTotalCalories;
    final protein = health.todayTotalProtein;
    final carbs = health.todayTotalCarbs;
    final fat = health.todayTotalFat;
    final water = health.todayWaterIntakeMl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.limeBright.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.limeDeep.withOpacity(0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.limeBright,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: AppColors.ink, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'RepGate | Cal AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    '${streak > 0 ? streak : 1} DAY STREAK',
                    style: const TextStyle(
                      color: AppColors.limeBright,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '${eaten.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} Kcal',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${((eaten / target) * 100).clamp(0, 150).toStringAsFixed(0)}% of Daily Target Achieved',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _storyMacroBadge('🥩 Protein', '${protein.toStringAsFixed(0)}g', AppColors.protein),
                const SizedBox(width: 8),
                _storyMacroBadge('🍚 Carbs', '${carbs.toStringAsFixed(0)}g', AppColors.carbs),
                const SizedBox(width: 8),
                _storyMacroBadge('🥑 Fat', '${fat.toStringAsFixed(0)}g', AppColors.fat),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.water_drop_rounded, color: AppColors.water, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Hydration: ${(water / 1000).toStringAsFixed(1)}L Logged Today',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PillButton(
              label: 'Copy Story for WhatsApp & Insta 📲',
              onPressed: () {
                final shareText = '''
⚡ RepGate Daily Fitness Story ⚡
🔥 Streak: ${streak > 0 ? streak : 1} Days Active
🥗 Calories: ${eaten.toInt()} / ${target.toInt()} kcal
🥩 Protein: ${protein.toInt()}g
🍚 Carbs: ${carbs.toInt()}g
🥑 Fat: ${fat.toInt()}g
💧 Water: ${(water / 1000).toStringAsFixed(1)}L
✨ Tracked with RepGate AI (Cal AI India)
''';
                Clipboard.setData(ClipboardData(text: shareText.trim()));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Fitness card copied! Ready to paste in WhatsApp & Instagram story! 🚀',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _storyMacroBadge(String title, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(val, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// RepGate Coach (Gemini AI Conversational Health & Diet Coach)
// ===========================================================================

class _RepGateCoachCard extends StatelessWidget {
  const _RepGateCoachCard();

  @override
  Widget build(BuildContext context) {
    final proteinTarget = context.select<UserProvider, double>(
      (p) => p.userModel?.dailyProteinTarget ?? 100,
    );
    final proteinConsumed = context.select<HealthProvider, double>(
      (p) => p.currentProtein,
    );
    final deficit = (proteinTarget - proteinConsumed).clamp(0.0, proteinTarget);
    final isDone = deficit <= 0;
    final isDark = AppColors.isDark(context);

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDone
                          ? (isDark ? const Color(0xFF1B3820) : AppColors.limeSoft)
                          : (isDark ? const Color(0xFF3E2723) : const Color(0xFFFFF3E0)),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        isDone ? '🎯' : '🤖',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.limeBright,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceBg(context), width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'RepGate Coach',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.pastelGreen,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.limeDeep.withOpacity(0.5)),
                          ),
                          child: Text(
                            'Gemini AI ⚡',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.limeBright : AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDone
                          ? '100% of protein target achieved! 🎉'
                          : '${deficit.toStringAsFixed(0)}g protein needed (${proteinConsumed.toStringAsFixed(0)}g / ${proteinTarget.toStringAsFixed(0)}g)',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isDone ? AppColors.limeDeep : (isDark ? const Color(0xFFFF8A65) : AppColors.burned),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              if (!isDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.ink,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Text(
                    '${((proteinConsumed / proteinTarget) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppColors.limeBright,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          // Quick Prompt Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickPromptChip(
                  context: context,
                  label: '📊 Progress Report',
                  query: 'Daily progress report',
                ),
                const SizedBox(width: 8),
                _quickPromptChip(
                  context: context,
                  label: '💪 Protein Target',
                  query: 'How to hit my protein target today?',
                ),
                const SizedBox(width: 8),
                _quickPromptChip(
                  context: context,
                  label: '⚠️ Meal Audit',
                  query: 'Analyze today\'s meals for mistakes',
                ),
                const SizedBox(width: 8),
                _quickPromptChip(
                  context: context,
                  label: '🥗 Diet Plan',
                  query: 'Suggest a personalized dinner diet plan',
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Main CTA Button
          PillButton(
            label: 'Chat with RepGate Coach 🤖',
            variant: PillVariant.dark,
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RepGateCoachScreen(),
                ),
              );
            },
          ),

          if (!isDone) ...[
            const SizedBox(height: 16),
            Divider(color: AppColors.border(context), height: 1),
            const SizedBox(height: 12),
            Text(
              '1-Tap Indian Protein Boosters:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 10),
            _proteinFoodRow(
              context: context,
              emoji: '🧀',
              name: 'Paneer',
              qty: '${(deficit / 0.18).round()}g',
              proteinGrams: deficit,
              itemToAdd: FoodItem(
                name: 'Paneer (${(deficit / 0.18).round()}g)',
                calories: (deficit / 0.18) * 2.65,
                protein: deficit,
                carbs: (deficit / 0.18) * 0.035,
                fat: (deficit / 0.18) * 0.208,
              ),
            ),
            const SizedBox(height: 8),
            _proteinFoodRow(
              context: context,
              emoji: '🥜',
              name: 'Soya Chunks',
              qty: '${(deficit / 0.52).round()}g',
              proteinGrams: deficit,
              itemToAdd: FoodItem(
                name: 'Soya Chunks (${(deficit / 0.52).round()}g)',
                calories: (deficit / 0.52) * 3.45,
                protein: deficit,
                carbs: (deficit / 0.52) * 0.33,
                fat: (deficit / 0.52) * 0.005,
              ),
            ),
            const SizedBox(height: 8),
            _proteinFoodRow(
              context: context,
              emoji: '🥚',
              name: 'Boiled Eggs',
              qty: '${(deficit / 6.0).ceil()} eggs',
              proteinGrams: (deficit / 6.0).ceil() * 6.0,
              itemToAdd: FoodItem(
                name: 'Boiled Eggs (x${(deficit / 6.0).ceil()})',
                calories: (deficit / 6.0).ceil() * 78.0,
                protein: (deficit / 6.0).ceil() * 6.0,
                carbs: (deficit / 6.0).ceil() * 0.6,
                fat: (deficit / 6.0).ceil() * 5.0,
              ),
            ),
            const SizedBox(height: 8),
            _proteinFoodRow(
              context: context,
              emoji: '🥣',
              name: 'Sattu Drink',
              qty: '${(deficit / 0.20).round()}g',
              proteinGrams: deficit,
              itemToAdd: FoodItem(
                name: 'Sattu Shake (${(deficit / 0.20).round()}g)',
                calories: (deficit / 0.20) * 1.9,
                protein: deficit,
                carbs: (deficit / 0.20) * 0.28,
                fat: (deficit / 0.20) * 0.03,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickPromptChip({
    required BuildContext context,
    required String label,
    required String query,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RepGateCoachScreen(initialQuery: query),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.subtleFill(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _proteinFoodRow({
    required BuildContext context,
    required String emoji,
    required String name,
    required String qty,
    required double proteinGrams,
    required FoodItem itemToAdd,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.subtleFill(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name ($qty)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Text(
                  '+${proteinGrams.toStringAsFixed(0)}g high-quality protein',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () async {
              final uid = context.read<UserProvider>().uid;
              if (uid == null) return;
              await context.read<FirestoreService>().addFoodLog(
                    uid,
                    FoodLogModel(
                      id: '',
                      detectedItems: [itemToAdd],
                      mealType: MealType.snack,
                      loggedAt: DateTime.now(),
                      source: FoodLogSource.manual,
                    ),
                  );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Logged ${itemToAdd.name} (+${proteinGrams.toStringAsFixed(0)}g protein) ✅'),
                ),
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.buttonPrimaryBg(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 14, color: AppColors.buttonPrimaryFg(context)),
                  const SizedBox(width: 2),
                  Text(
                    'Quick Log',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.buttonPrimaryFg(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Intermittent Fasting (16:8 / 14:10 / 12:12 Tracker)
// ===========================================================================

class _FastingTrackerCard extends StatelessWidget {
  const _FastingTrackerCard();

  @override
  Widget build(BuildContext context) {
    final fastingService = context.watch<FastingService>();
    final state = fastingService.getCurrentState();
    final isDark = AppColors.isDark(context);

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: state.isActive
                      ? (state.isGoalReached
                          ? (isDark ? const Color(0xFF1B3820) : AppColors.limeSoft)
                          : (isDark ? const Color(0xFF3E2723) : const Color(0xFFFFF3E0)))
                      : AppColors.subtleFill(context),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  state.isActive ? (state.isGoalReached ? '🎉' : '⏳') : '⏱️',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Intermittent Fasting (${state.targetHours}:${24 - state.targetHours})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      state.isActive
                          ? (state.isGoalReached
                              ? 'Fast complete! Eating window is open.'
                              : '${(state.elapsed.inMinutes / 60).floor()}h ${state.elapsed.inMinutes % 60}m elapsed (${(state.remaining.inMinutes / 60).floor()}h ${state.remaining.inMinutes % 60}m left)')
                          : 'No active fast. Track your fasting & eating windows.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: state.isActive
                            ? (state.isGoalReached ? AppColors.limeDeep : (isDark ? const Color(0xFFFF8A65) : AppColors.burned))
                            : AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (state.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: state.isGoalReached
                        ? AppColors.limeDeep
                        : (isDark ? AppColors.darkSurface : AppColors.ink),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Text(
                    state.isGoalReached ? 'READY' : '${(state.progress * 100).toInt()}%',
                    style: TextStyle(
                      color: state.isGoalReached ? AppColors.ink : AppColors.limeBright,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (state.isActive) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 8,
                backgroundColor: AppColors.border(context),
                valueColor: AlwaysStoppedAnimation<Color>(
                  state.isGoalReached ? AppColors.limeDeep : AppColors.limeBright,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: AppColors.border(context)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showProtocolPicker(context, fastingService),
                    child: Text('Protocol (${state.targetHours}h)',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary(context))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonPrimaryBg(context),
                      foregroundColor: AppColors.buttonPrimaryFg(context),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async => await fastingService.endFast(),
                    child: const Text('End Fast', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Start 16:8 Fast',
                    variant: PillVariant.dark,
                    fontSize: 13,
                    onPressed: () async => await fastingService.startFast(targetHours: 16),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    side: BorderSide(color: AppColors.border(context)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => _showProtocolPicker(context, fastingService),
                  child: Text('Change Goal', style: TextStyle(fontSize: 12, color: AppColors.textPrimary(context))),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showProtocolPicker(BuildContext context, FastingService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceBg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Fasting Protocol',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
            const SizedBox(height: 14),
            _protocolTile(ctx, service, 16, '16:8 Protocol (Most Popular)', '16h fast, 8h eating window. Ideal for fat loss.'),
            _protocolTile(ctx, service, 14, '14:10 Protocol (Beginner Friendly)', '14h fast, 10h eating window. Easy daily routine.'),
            _protocolTile(ctx, service, 12, '12:12 Protocol (Circadian Reset)', '12h fast, 12h eating window. Great for beginners.'),
          ],
        ),
      ),
    );
  }

  Widget _protocolTile(BuildContext ctx, FastingService service, int hours, String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.timer_outlined, color: AppColors.textPrimary(ctx)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary(ctx))),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textSecondary(ctx))),
      onTap: () async {
        if (service.isActive) {
          await service.updateTargetHours(hours);
        } else {
          await service.startFast(targetHours: hours);
        }
        if (ctx.mounted) Navigator.pop(ctx);
      },
    );
  }
}

// ===========================================================================
// Meals
// ===========================================================================

class _MealGroups extends StatelessWidget {
  const _MealGroups();

  /// Share of the daily calorie target allocated to each meal.
  static const _split = {
    MealType.breakfast: 0.25,
    MealType.lunch: 0.35,
    MealType.dinner: 0.30,
    MealType.snack: 0.10,
  };

  static String _label(MealType m) => switch (m) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch => 'Lunch',
        MealType.dinner => 'Dinner',
        MealType.snack => 'Snacks',
      };

  @override
  Widget build(BuildContext context) {
    // Selecting the list means this subtree rebuilds when food changes, but
    // NOT when water/weight/fines tick.
    final logs = context.select<HealthProvider, List<FoodLogModel>>(
      (p) => p.currentFoodLogs,
    );
    final calorieTarget = context.select<UserProvider, double>(
      (p) => p.userModel?.dailyCalorieTarget ?? 2000,
    );
    final isDark = AppColors.isDark(context);

    if (logs.isEmpty) {
      return Padding(
        padding: AppSpacing.page,
        child: SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.limeWash,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lime),
                ),
                child: const Center(
                  child: Text('🥗', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No Meals Logged Today',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Snap a food photo or search to track calories & macros automatically.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              PillButton(
                label: '+ Log Your First Meal',
                variant: PillVariant.dark,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoodLogScreen()),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: MealType.values.map((meal) {
        final mealLogs = logs.where((l) => l.mealType == meal).toList();
        final consumed =
            mealLogs.fold<double>(0, (s, l) => s + l.totalCalories);
        final items = mealLogs.expand((l) => l.detectedItems).toList();

        return Padding(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: AppSpacing.md,
          ),
          child: MealGroupCard(
            mealName: _label(meal),
            consumed: consumed,
            target: calorieTarget * _split[meal]!,
            itemCount: items.length,
            onAdd: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FoodLogScreen(initialMeal: meal),
              ),
            ),
            children: items.take(3).map((item) {
              return MealLogRow(
                name: item.name,
                kcal: item.calories,
                subtitle:
                    '${item.calories.toStringAsFixed(0)} Cal · ${item.protein.toStringAsFixed(0)}g protein',
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

// ===========================================================================
// Scoring
// ===========================================================================

/// Composite 0–10 daily health score across nutrition, hydration and activity.
///
/// Top-level so the small widget above can call it without holding state.
double computeHealthScore({
  required double calories,
  required double calorieTarget,
  required double protein,
  required double proteinTarget,
  required int waterMl,
  required bool pushupsDone,
}) {
  double score = 0;

  // Calories within ±15% of target = full marks (3 pts)
  if (calorieTarget > 0) {
    final ratio = calories / calorieTarget;
    if (ratio >= 0.85 && ratio <= 1.15) {
      score += 3;
    } else if (ratio >= 0.6 && ratio <= 1.4) {
      score += 1.5;
    } else if (calories > 0) {
      score += 0.5;
    }
  }

  // Protein (3 pts)
  if (proteinTarget > 0) {
    score += (protein / proteinTarget).clamp(0.0, 1.0) * 3;
  }

  // Hydration (2 pts)
  score += (waterMl / AppConstants.dailyWaterTargetMl).clamp(0.0, 1.0) * 2;

  // Push-ups verified (2 pts)
  if (pushupsDone) score += 2;

  return score.clamp(0, 10);
}
