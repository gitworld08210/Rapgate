import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/health_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/macro_widgets.dart';
import '../../widgets/meal_widgets.dart';
import '../blocked_apps/blocked_apps_screen.dart';
import 'pushup_session_screen.dart';
import 'rest_day_pass_sheet.dart';
import 'emergency_unlock_sheet.dart';

class PushupScreen extends StatelessWidget {
  const PushupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.userModel;
    final streaks = userProvider.streaks;

    final target = user?.pushupTarget ?? 10;
    final unlocked = health.isAppsUnlocked;
    final blockedCount =
        health.blockedAppsConfig?.blockedPackages.length ?? 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            Padding(
              padding: AppSpacing.page,
              child: Row(
                children: [
                  Expanded(
                    child: Text('Push-ups',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  CircleIconButton(
                    icon: Icons.apps_rounded,
                    bordered: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BlockedAppsScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---------- Big status hero ----------
            Padding(
              padding: AppSpacing.page,
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: unlocked ? AppColors.ink : AppColors.danger,
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        unlocked
                            ? Icons.lock_open_rounded
                            : Icons.lock_rounded,
                        size: 36,
                        color: unlocked
                            ? AppColors.limeBright
                            : AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      unlocked ? 'Apps Unlocked' : 'Apps Locked',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: AppColors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      unlocked
                          ? _timeLeftText(health.unlockExpiresAt)
                          : 'Complete $target push-ups for ${_tierLabel(target)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.75),
                          ),
                    ),
                    const SizedBox(height: 22),
                    if (!unlocked)
                      PillButton(
                        label: 'Start Session',
                        icon: Icons.play_arrow_rounded,
                        variant: PillVariant.lime,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PushupSessionScreen(),
                          ),
                        ),
                      )
                    else
                      PillButton(
                        label: 'Do extra push-ups',
                        icon: Icons.add_rounded,
                        variant: PillVariant.outline,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PushupSessionScreen(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ---------- Tiered unlock info ----------
            Padding(
              padding: AppSpacing.page,
              child: SoftCard(
                color: AppColors.pastelGreen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_rounded,
                            size: 18, color: AppColors.limeDeep),
                        const SizedBox(width: 9),
                        Text('Unlock tiers',
                            style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...AppConstants.unlockDurationTiers.reversed.map((tier) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.limeDeep,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${tier['reps']}+ reps',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const Spacer(),
                            Text(
                              '${tier['hours']}h unlock',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ---------- Premium actions (only when locked) ----------
            if (!unlocked) ...[
              Padding(
                padding: AppSpacing.page,
                child: Row(
                  children: [
                    // Rest Day Pass card
                    Expanded(
                      child: _PremiumActionCard(
                        icon: Icons.shield_rounded,
                        label: 'Rest Day Pass',
                        sublabel: '${streaks?.restDayPasses ?? 0} available',
                        badgeCount: streaks?.restDayPasses ?? 0,
                        gradient: const [
                          Color(0xFF34C759),
                          Color(0xFF28A745),
                        ],
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const RestDayPassSheet(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Emergency Unlock card
                    Expanded(
                      child: _PremiumActionCard(
                        icon: Icons.lock_open_rounded,
                        label: 'Emergency',
                        sublabel: 'Unlock now',
                        gradient: const [
                          Color(0xFFFF6B6B),
                          Color(0xFFFF3B30),
                        ],
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          final db = context.read<DatabaseService>();
                          final uid = userProvider.uid;
                          int usedThisWeek = 0;
                          if (uid != null) {
                            try {
                              usedThisWeek =
                                  await db.getEmergencyUnlocksThisWeek(uid);
                            } catch (_) {}
                          }
                          if (!context.mounted) return;
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => EmergencyUnlockSheet(
                              usedThisWeek: usedThisWeek,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ---------- Today's target ----------
            Padding(
              padding: AppSpacing.page,
              child: Row(
                children: [
                  Expanded(
                    child: QuickStatTile(
                      label: "Today's target",
                      value: '$target',
                      unit: 'reps',
                      icon: Icons.flag_rounded,
                      tint: AppColors.limeDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: QuickStatTile(
                      label: 'Blocked apps',
                      value: '$blockedCount',
                      unit: 'apps',
                      icon: Icons.block_rounded,
                      tint: AppColors.danger,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BlockedAppsScreen()),
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
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---------- How verification works ----------
            Padding(
              padding: AppSpacing.page,
              child: SectionHeader(title: 'How verification works'),
            ),
            Padding(
              padding: AppSpacing.page,
              child: SoftCard(
                child: Column(
                  children: [
                    _rule(context, Icons.camera_front_rounded,
                        'Front camera required',
                        'Your face must stay visible for most of the session.'),
                    const Divider(height: 22),
                    _rule(context, Icons.architecture_rounded,
                        'Full range of motion',
                        'Arms must go from extended to flexed and back each rep.'),
                    const Divider(height: 22),
                    _rule(context, Icons.speed_rounded, 'Human-paced reps',
                        'Reps that are too fast or too slow are rejected.'),
                    const Divider(height: 22),
                    _rule(context, Icons.cloud_done_rounded,
                        'Server-verified count',
                        'The server recounts reps independently — the app never self-reports.'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ---------- Privacy note ----------
            Padding(
              padding: AppSpacing.page,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.pastelGreen,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 18, color: AppColors.limeDeep),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Video never leaves your phone. Only anonymised pose angles are sent for verification.',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.grey700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rule(
      BuildContext context, IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.limeSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: AppColors.limeDeep),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  String _timeLeftText(DateTime? until) {
    if (until == null) return '';
    final diff = until.difference(DateTime.now());
    if (diff.isNegative) return 'Unlock expired';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return h > 0
        ? 'Unlocked for ${h}h ${m}m more'
        : 'Unlocked for ${m}m more';
  }

  /// Returns a short label describing the unlock reward for a given target.
  String _tierLabel(int target) {
    for (final tier in AppConstants.unlockDurationTiers) {
      if (target >= tier['reps']!) {
        return '${tier['hours']}h unlock - do more for longer!';
      }
    }
    return '4h unlock - do more for up to 24h!';
  }
}

/// A premium gradient action card used for rest day pass and emergency unlock.
class _PremiumActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final int? badgeCount;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _PremiumActionCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradient[0].withOpacity(0.12),
                gradient[1].withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: gradient[0].withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: gradient[0].withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: gradient[0]),
                  ),
                  const Spacer(),
                  if (badgeCount != null && badgeCount! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: gradient[0],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
