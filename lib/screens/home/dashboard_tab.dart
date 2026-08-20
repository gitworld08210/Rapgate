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
import '../water/water_tracker_screen.dart';
import '../weight/weight_screen.dart';
import '../pushup/pushup_screen.dart';
import '../food/food_log_screen.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final health = context.watch<HealthProvider>();
    final user = userProvider.userModel;
    final streaks = userProvider.streaks;

    // Explicit `double` annotations matter here: `?? 2000` would otherwise
    // infer as `num`, which Dart will not implicitly downcast to `double`.
    final double calorieTarget = user?.dailyCalorieTarget ?? 2000;
    final double proteinTarget = user?.dailyProteinTarget ?? 100;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 600));
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              // ---------- Header ----------
              Padding(
                padding: AppSpacing.page,
                child: Row(
                  children: [
                    Expanded(
                      child: GreetingHeader(
                        name: user?.name ?? '',
                        onAvatarTap: () {},
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.notifications_none_rounded,
                      showBadge: health.outstandingFines.isNotEmpty,
                      bordered: true,
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ---------- Week strip ----------
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

              // ---------- App lock status ----------
              Padding(
                padding: AppSpacing.page,
                child: LockStatusBanner(
                  isUnlocked: health.isAppsUnlocked,
                  unlockUntil: health.unlockExpiresAt,
                  requiredReps: user?.pushupTarget ?? 10,
                  onAction: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PushupScreen()),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ---------- Calorie gauge ----------
              Padding(
                padding: AppSpacing.page,
                child: SoftCard(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Today',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          Text(
                            '${health.todayTotalCalories.toStringAsFixed(0)} / ${calorieTarget.toStringAsFixed(0)} kcal',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: CalorieGauge(
                          consumed: health.todayTotalCalories,
                          target: calorieTarget,
                          size: 210,
                        ),
                      ),
                      const SizedBox(height: 14),
                      CalorieStatRow(
                        eaten: health.todayTotalCalories,
                        target: calorieTarget,
                        burned: 0,
                      ),
                      const SizedBox(height: 20),
                      MacroRow(
                        carbs: health.todayTotalCarbs,
                        protein: health.todayTotalProtein,
                        fat: health.todayTotalFat,
                      ),
                      const SizedBox(height: 18),
                      HealthScoreBar(
                        score: _healthScore(
                          calories: health.todayTotalCalories,
                          calorieTarget: calorieTarget,
                          protein: health.todayTotalProtein,
                          proteinTarget: proteinTarget,
                          waterMl: health.todayWaterIntakeMl,
                          pushupsDone: health.isAppsUnlocked,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ---------- Quick stats ----------
              Padding(
                padding: AppSpacing.page,
                child: Row(
                  children: [
                    Expanded(
                      child: QuickStatTile(
                        label: 'Drink water',
                        value: (health.todayWaterIntakeMl / 1000)
                            .toStringAsFixed(1),
                        unit: 'L',
                        icon: Icons.water_drop_rounded,
                        tint: AppColors.water,
                        progress: health.waterProgress,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WaterTrackerScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: QuickStatTile(
                        label: 'Weight',
                        value: health.weightLogs.isEmpty
                            ? (user?.weight ?? 0).toStringAsFixed(1)
                            : health.weightLogs.first.weightKg
                                .toStringAsFixed(1),
                        unit: 'kg',
                        icon: Icons.monitor_weight_rounded,
                        tint: AppColors.protein,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WeightScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ---------- Streak ----------
              Padding(
                padding: AppSpacing.page,
                child: StreakBannerCard(
                  streak: streaks?.currentPushupStreak ?? 0,
                  subtitle: (streaks?.currentPushupStreak ?? 0) > 0
                      ? 'KEEP GOING'
                      : 'START TODAY',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PushupScreen()),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ---------- Today's meals ----------
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

              ..._mealGroups(context, health, calorieTarget),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _mealGroups(
      BuildContext context, HealthProvider health, double calorieTarget) {
    // Distribution of the daily target across meals
    const split = {
      MealType.breakfast: 0.25,
      MealType.lunch: 0.35,
      MealType.dinner: 0.30,
      MealType.snack: 0.10,
    };

    return MealType.values.map((meal) {
      final logs =
          health.todayFoodLogs.where((l) => l.mealType == meal).toList();
      final consumed = logs.fold<double>(0, (s, l) => s + l.totalCalories);
      final items = logs.expand((l) => l.detectedItems).toList();

      return Padding(
        padding: const EdgeInsets.only(
            left: 20, right: 20, bottom: AppSpacing.md),
        child: MealGroupCard(
          mealName: _mealLabel(meal),
          consumed: consumed,
          target: calorieTarget * split[meal]!,
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
    }).toList();
  }

  String _mealLabel(MealType m) => switch (m) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch => 'Lunch',
        MealType.dinner => 'Dinner',
        MealType.snack => 'Snacks',
      };

  /// Composite 0–10 daily health score across nutrition, hydration, activity.
  double _healthScore({
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
}
