import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/health_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/macro_widgets.dart';

class WaterTrackerScreen extends StatelessWidget {
  const WaterTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final total = health.todayWaterIntakeMl;
    final progress = health.waterProgress;
    final glasses = (total / 250).floor();

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
        title: const Text('Water Intake'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ---------- Hero bottle visual ----------
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: Column(
              children: [
                // Fill visual
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 116,
                      height: 190,
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        width: 116,
                        height: (190 * progress.clamp(0.0, 1.0)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.water,
                              AppColors.water.withOpacity(0.55),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 68,
                      child: Column(
                        children: [
                          Text(
                            '${(progress * 100).clamp(0, 999).toStringAsFixed(0)}%',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: progress > 0.45
                                      ? Colors.white
                                      : AppColors.ink,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  formatWaterMl(total),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'of ${formatWaterMl(AppConstants.dailyWaterTargetMl)} target  ·  $glasses glasses',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                SoftProgressBar(
                  progress: progress,
                  height: 10,
                  color: AppColors.water,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ---------- Motivational message ----------
          SoftCard(
            color: progress >= 1.0
                ? AppColors.pastelGreen
                : AppColors.water.withOpacity(0.08),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            child: Row(
              children: [
                Icon(
                  progress >= 1.0
                      ? Icons.emoji_events_rounded
                      : Icons.local_drink_rounded,
                  color: progress >= 1.0
                      ? const Color(0xFF4CAF50)
                      : AppColors.water,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _motivationalMessage(progress),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ---------- Quick add ----------
          SectionHeader(title: 'Quick add'),
          Row(
            children: AppConstants.waterQuickAddOptions.map((ml) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: ml == AppConstants.waterQuickAddOptions.last ? 0 : 10,
                  ),
                  child: SoftCard(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    onTap: () async {
                      await health.addWater(ml);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('+${ml}ml logged 💧')),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.water.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.water_drop_rounded,
                              color: AppColors.water, size: 19),
                        ),
                        const SizedBox(height: 8),
                        Text('+$ml',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text('ml',
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ---------- Today's log ----------
          SectionHeader(title: "Today's log"),
          if (health.todayWaterLogs.isEmpty)
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Text('💧', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text('No water logged yet',
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            )
          else
            SoftCard(
              child: Column(
                children: [
                  for (var i = 0; i < health.todayWaterLogs.length; i++) ...[
                    if (i > 0) const Divider(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.water.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.water_drop_rounded,
                              size: 17, color: AppColors.water),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            formatWaterMl(health.todayWaterLogs[i].amountMl),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          formatTime(health.todayWaterLogs[i].loggedAt),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _motivationalMessage(double progress) {
  if (progress >= 1.0) {
    return 'Goal reached! Great job staying hydrated today! 🎉';
  } else if (progress >= 0.75) {
    return 'Almost there! Just a bit more to hit your goal. 🎯';
  } else if (progress >= 0.5) {
    return 'Halfway there! You are doing great. 🌊';
  } else if (progress >= 0.25) {
    return 'Good start! Keep sipping throughout the day. 👍';
  } else {
    return 'Start your hydration! Every glass counts. 💧';
  }
}
