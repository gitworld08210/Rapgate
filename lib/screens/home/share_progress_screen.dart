import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/health_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/pill_button.dart';
import '../../utils/health_score.dart';
import '../../widgets/share_progress_card.dart';

/// Screen that displays a preview of the user's daily stats and allows
/// sharing them as formatted text copied to the clipboard.
class ShareProgressScreen extends StatelessWidget {
  const ShareProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final streak = context.select<UserProvider, int>(
      (p) => p.streaks?.currentPushupStreak ?? 0,
    );
    final calories = context.select<HealthProvider, double>(
      (p) => p.todayTotalCalories,
    );
    final calorieTarget = context.select<UserProvider, double>(
      (p) => p.userModel?.dailyCalorieTarget ?? 2000,
    );
    final waterMl = context.select<HealthProvider, int>(
      (p) => p.todayWaterIntakeMl,
    );
    final protein = context.select<HealthProvider, double>(
      (p) => p.todayTotalProtein,
    );
    final proteinTarget = context.select<UserProvider, double>(
      (p) => p.userModel?.dailyProteinTarget ?? 100,
    );
    final isUnlocked = context.select<HealthProvider, bool>(
      (p) => p.isAppsUnlocked,
    );

    final healthScore = computeHealthScore(
      calories: calories,
      calorieTarget: calorieTarget,
      protein: protein,
      proteinTarget: proteinTarget,
      waterMl: waterMl,
      pushupsDone: isUnlocked,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Share Progress')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                'Your daily snapshot',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Share your progress with friends and challenge them!',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Progress card preview
              ShareProgressCard(
                streak: streak,
                healthScore: healthScore,
                caloriesEaten: calories,
                calorieTarget: calorieTarget,
                waterMl: waterMl,
                waterTargetMl: AppConstants.dailyWaterTargetMl,
              ),

              const Spacer(),

              // Share button
              PillButton(
                label: 'Copy & Share',
                icon: Icons.copy_rounded,
                variant: PillVariant.dark,
                onPressed: () => _copyToClipboard(
                  context,
                  streak: streak,
                  healthScore: healthScore,
                  calories: calories,
                  calorieTarget: calorieTarget,
                  waterMl: waterMl,
                  waterTargetMl: AppConstants.dailyWaterTargetMl,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Stats will be copied as text for sharing anywhere',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(
    BuildContext context, {
    required int streak,
    required double healthScore,
    required double calories,
    required double calorieTarget,
    required int waterMl,
    required int waterTargetMl,
  }) {
    final text = _buildShareText(
      streak: streak,
      healthScore: healthScore,
      calories: calories,
      calorieTarget: calorieTarget,
      waterMl: waterMl,
      waterTargetMl: waterTargetMl,
    );

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard! Share it anywhere.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _buildShareText({
    required int streak,
    required double healthScore,
    required double calories,
    required double calorieTarget,
    required int waterMl,
    required int waterTargetMl,
  }) {
    final waterL = (waterMl / 1000).toStringAsFixed(1);
    final waterTargetL = (waterTargetMl / 1000).toStringAsFixed(1);

    return '''
My HealthPush Daily Stats:

Streak: $streak day${streak == 1 ? '' : 's'}
Health Score: ${healthScore.toStringAsFixed(1)}/10
Calories: ${calories.toStringAsFixed(0)}/${calorieTarget.toStringAsFixed(0)} kcal
Water: ${waterL}L / ${waterTargetL}L

HealthPush - Earn your screen time
#HealthPush #FitnessChallenge''';
  }
}
