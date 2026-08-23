import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';

/// Premium bottom sheet for using a rest day pass (streak shield).
///
/// Shows the available passes with a polished shield visual, explains the
/// mechanics, and provides a "Use Pass" button with haptic feedback.
class RestDayPassSheet extends StatefulWidget {
  const RestDayPassSheet({super.key});

  @override
  State<RestDayPassSheet> createState() => _RestDayPassSheetState();
}

class _RestDayPassSheetState extends State<RestDayPassSheet>
    with SingleTickerProviderStateMixin {
  bool _isUsing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final streaks = userProvider.streaks;
    final passes = streaks?.restDayPasses ?? 0;
    final currentStreak = streaks?.currentPushupStreak ?? 0;
    final daysUntilNext = currentStreak > 0 ? 7 - (currentStreak % 7) : 7;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Animated shield icon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.limeBright.withOpacity(0.25),
                    AppColors.limeDeep.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.limeBright.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_rounded,
                size: 40,
                color: AppColors.limeDeep,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Rest Day Pass',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Protect your streak without doing push-ups today',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),

          const SizedBox(height: 24),

          // Passes count
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: passes > 0
                  ? AppColors.pastelGreen
                  : AppColors.grey100,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: passes > 0
                  ? Border.all(
                      color: AppColors.limeDeep.withOpacity(0.3), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                // Shield badges
                Row(
                  children: List.generate(3, (index) {
                    final isActive = index < passes;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.shield_rounded,
                        size: 24,
                        color: isActive
                            ? AppColors.limeDeep
                            : AppColors.grey300,
                      ),
                    );
                  }),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$passes / 3',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.limeDeep,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'passes available',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Next pass progress
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up_rounded,
                    size: 18, color: AppColors.grey500),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        daysUntilNext == 7 && currentStreak == 0
                            ? 'Start a streak to earn passes'
                            : 'Next pass in $daysUntilNext day${daysUntilNext == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Earn 1 pass for every 7-day streak (max 3)',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Use pass button
          if (passes > 0)
            PillButton(
              label: _isUsing ? 'Using pass...' : 'Use Rest Day Pass',
              icon: Icons.shield_rounded,
              variant: PillVariant.lime,
              onPressed: _isUsing ? null : () => _usePass(context),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 16, color: AppColors.grey500),
                  const SizedBox(width: 8),
                  Text(
                    'No passes available',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.grey500,
                        ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _usePass(BuildContext context) async {
    setState(() => _isUsing = true);
    HapticFeedback.heavyImpact();

    try {
      final db = context.read<DatabaseService>();
      await db.useRestDayPass();
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rest day pass used! Your streak is safe.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUsing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}
