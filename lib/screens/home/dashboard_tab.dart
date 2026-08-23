import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../providers/health_provider.dart';
import '../../models/food_log_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/week_strip.dart';
import '../../widgets/calorie_gauge.dart';
import '../../widgets/macro_widgets.dart';
import '../../widgets/meal_widgets.dart';
import '../../widgets/floating_nav_bar.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/health_summary_model.dart';
import '../water/water_tracker_screen.dart';
import '../weight/weight_screen.dart';
import '../pushup/pushup_screen.dart';
import '../food/food_log_screen.dart';
import '../reports/weekly_summary_screen.dart';

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
                  onDateSelected: (d) => setState(() => _selectedDate = d),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            const Padding(
              padding: AppSpacing.page,
              child: _LockBanner(),
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
              child: _WeeklySummaryPreview(),
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

    return Row(
      children: [
        Expanded(child: GreetingHeader(name: name)),
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
// App lock status
// ===========================================================================

class _LockBanner extends StatelessWidget {
  const _LockBanner();

  @override
  Widget build(BuildContext context) {
    final lock = context
        .select<HealthProvider, ({bool unlocked, DateTime? until})>(
      (p) => (unlocked: p.isAppsUnlocked, until: p.unlockExpiresAt),
    );
    final target = context.select<UserProvider, int>(
      (p) => p.userModel?.pushupTarget ?? 10,
    );

    return LockStatusBanner(
      isUnlocked: lock.unlocked,
      unlockUntil: lock.until,
      requiredReps: target,
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PushupScreen()),
      ),
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
        .select<HealthProvider, double>((p) => p.todayTotalCalories);
    final target = context.select<UserProvider, double>(
      (p) => p.userModel?.dailyCalorieTarget ?? 2000,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Today', style: Theme.of(context).textTheme.titleMedium),
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
        carbs: p.todayTotalCarbs,
        protein: p.todayTotalProtein,
        fat: p.todayTotalFat,
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
    final streak = context.select<UserProvider, int>(
      (p) => p.streaks?.currentPushupStreak ?? 0,
    );

    return StreakBannerCard(
      streak: streak,
      subtitle: streak > 0 ? 'KEEP GOING' : 'START TODAY',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PushupScreen()),
      ),
    );
  }
}

// ===========================================================================
// Weekly Summary Preview
// ===========================================================================

class _WeeklySummaryPreview extends StatelessWidget {
  const _WeeklySummaryPreview();

  @override
  Widget build(BuildContext context) {
    final uid = context.select<UserProvider, String?>(
      (p) => p.userModel?.uid,
    );
    if (uid == null) return const SizedBox.shrink();

    return FutureBuilder<HealthSummaryModel?>(
      future: context.read<DatabaseService>().getLatestWeeklySummary(uid),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        if (summary == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const WeeklySummaryScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: AppRadius.card,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8FDF0),
                  Color(0xFFEFF8FF),
                ],
              ),
              border: Border.all(
                color: AppColors.limeBright.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.limeSoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Center(
                        child: Text('🧠', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Weekly Summary',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.grey300),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  summary.summaryText.length > 120
                      ? '${summary.summaryText.substring(0, 120)}...'
                      : summary.summaryText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Read full summary',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.limeDeep,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        );
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
      (p) => p.todayFoodLogs,
    );
    final calorieTarget = context.select<UserProvider, double>(
      (p) => p.userModel?.dailyCalorieTarget ?? 2000,
    );

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
