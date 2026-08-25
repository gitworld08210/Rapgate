import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/achievement_model.dart';
import '../../providers/health_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/achievement_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/soft_card.dart';

/// Screen displaying all achievements grouped by category.
///
/// Achievements are computed from existing provider data (streaks, food logs,
/// water logs, push-up sessions) so there is no extra database call.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 16,
            bordered: true,
            onTap: () => Navigator.pop(context),
          ),
        ),
        leadingWidth: 74,
        title: const Text('Achievements'),
      ),
      body: const _AchievementsBody(),
    );
  }
}

class _AchievementsBody extends StatelessWidget {
  const _AchievementsBody();

  @override
  Widget build(BuildContext context) {
    // Gather data from providers
    final streaks = context.select<UserProvider, ({int current, int longest})>(
      (p) => (
        current: p.streaks?.currentPushupStreak ?? 0,
        longest: p.streaks?.longestPushupStreak ?? 0,
      ),
    );

    final healthData = context.select<HealthProvider,
        ({int totalSessions, int totalReps, int foodLogDays, int foodScans, int waterStreak, int proteinDays})>(
      (p) => (
        totalSessions: p.totalVerifiedSessions,
        totalReps: p.totalVerifiedReps,
        foodLogDays: p.totalFoodLogDays,
        foodScans: p.totalFoodScans,
        waterStreak: p.currentWaterStreak,
        proteinDays: p.proteinTargetDays,
      ),
    );

    final achievements = AchievementService.computeAchievements(
      currentPushupStreak: streaks.current,
      longestPushupStreak: streaks.longest,
      totalVerifiedSessions: healthData.totalSessions,
      totalReps: healthData.totalReps,
      totalFoodLogDays: healthData.foodLogDays,
      totalFoodScans: healthData.foodScans,
      currentWaterStreak: healthData.waterStreak,
      proteinTargetDays: healthData.proteinDays,
    );

    final unlocked = AchievementService.countUnlocked(achievements);
    final total = achievements.length;
    final next = AchievementService.nextMilestone(achievements);

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // ---- Hero section ----
        Padding(
          padding: AppSpacing.page,
          child: _HeroCard(
            unlocked: unlocked,
            total: total,
            nextMilestone: next,
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // ---- Category sections ----
        ..._buildCategorySections(context, achievements),
      ],
    );
  }

  List<Widget> _buildCategorySections(
    BuildContext context,
    List<Achievement> achievements,
  ) {
    const categories = AchievementCategory.values;
    final widgets = <Widget>[];

    for (final category in categories) {
      final items =
          achievements.where((a) => a.category == category).toList();
      if (items.isEmpty) continue;

      widgets.add(
        Padding(
          padding: AppSpacing.page,
          child: SectionHeader(
            title: _categoryTitle(category),
          ),
        ),
      );

      for (final achievement in items) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: AppSpacing.md,
            ),
            child: _AchievementTile(achievement: achievement),
          ),
        );
      }

      widgets.add(const SizedBox(height: AppSpacing.lg));
    }

    return widgets;
  }

  String _categoryTitle(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.streak:
        return 'Streak Milestones';
      case AchievementCategory.fitness:
        return 'Fitness';
      case AchievementCategory.nutrition:
        return 'Nutrition';
      case AchievementCategory.hydration:
        return 'Hydration';
    }
  }
}

// ===========================================================================
// Hero card
// ===========================================================================

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.unlocked,
    required this.total,
    required this.nextMilestone,
  });

  final int unlocked;
  final int total;
  final Achievement? nextMilestone;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.limeSoft,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          const Text(
            '\u{1F3C6}', // trophy emoji
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$unlocked / $total Achievements',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (nextMilestone != null) ...[
            Text(
              'Next: ${nextMilestone!.title}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey700,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: nextMilestone!.progress,
                minHeight: 8,
                backgroundColor: AppColors.grey200,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.limeBright),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${(nextMilestone!.progress * 100).toStringAsFixed(0)}% complete',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else
            Text(
              'All achievements unlocked!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey700,
                    fontWeight: FontWeight.w600,
                  ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Achievement tile
// ===========================================================================

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;

    return SoftCard(
      color: isUnlocked ? AppColors.limeSoft : AppColors.grey100,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          // Emoji
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppColors.limeBright.withOpacity(0.3)
                  : AppColors.grey200,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              achievement.emoji,
              style: TextStyle(
                fontSize: 24,
                color: isUnlocked ? null : AppColors.grey500,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Title + description + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isUnlocked ? AppColors.ink : AppColors.grey700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey500,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: LinearProgressIndicator(
                    value: achievement.progress,
                    minHeight: 6,
                    backgroundColor: isUnlocked
                        ? AppColors.lime.withOpacity(0.3)
                        : AppColors.grey200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUnlocked ? AppColors.limeDeep : AppColors.grey300,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Status icon
          Icon(
            isUnlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
            size: 22,
            color: isUnlocked ? AppColors.limeDeep : AppColors.grey300,
          ),
        ],
      ),
    );
  }
}
