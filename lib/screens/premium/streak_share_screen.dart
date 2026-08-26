import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/health_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';

/// Screen that generates a shareable achievement card showing the user's
/// current streak, push-up target, and water intake for the day.
class StreakShareScreen extends StatelessWidget {
  const StreakShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final health = context.read<HealthProvider>();
    final user = userProvider.userModel;
    final streaks = userProvider.streaks;

    final currentStreak = streaks?.currentPushupStreak ?? 0;
    final pushupTarget = user?.pushupTarget ?? 10;
    final waterMl = health.todayWaterIntakeMl;
    final waterLitres = (waterMl / 1000).toStringAsFixed(1);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Top bar ----------
              Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    bordered: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Share Achievement',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ---------- Achievement card ----------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.ink, Color(0xFF1A2E1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // App branding
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.limeBright,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.fitness_center_rounded,
                            size: 16,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'RepGate',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Streak number
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.limeBright,
                          width: 3,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$currentStreak',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: AppColors.limeBright,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                          ),
                          Text(
                            'days',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.white60,
                                ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      currentStreak > 0
                          ? 'Push-up Streak!'
                          : 'Starting Fresh!',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),

                    const SizedBox(height: 24),

                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _statChip(
                            context,
                            icon: Icons.flag_rounded,
                            value: '$pushupTarget',
                            label: 'Target reps',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statChip(
                            context,
                            icon: Icons.water_drop_rounded,
                            value: '${waterLitres}L',
                            label: 'Water today',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Tagline
                    Text(
                      'Earn your screen time',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: Colors.white38,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ---------- Share button ----------
              PillButton(
                label: 'Share Achievement',
                variant: PillVariant.lime,
                icon: Icons.share_rounded,
                onPressed: () {
                  final shareText = "I've maintained a $currentStreak-day "
                      "push-up streak on RepGate! Join me in earning your "
                      "screen time. Download: https://repgate.app/invite";

                  Clipboard.setData(ClipboardData(text: shareText));

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Achievement copied to clipboard! Share it anywhere.',
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.md),

              // Hint
              Center(
                child: Text(
                  'Copied text can be shared on WhatsApp, Instagram, or any app',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.grey500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.limeBright),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white54,
                ),
          ),
        ],
      ),
    );
  }
}
