import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/pill_button.dart';

/// Shows the streak sharing bottom sheet.
///
/// Call this from any screen that has access to the user's current streak.
void showStreakShareSheet(
  BuildContext context, {
  required int currentStreak,
  required int longestStreak,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StreakShareSheet(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
    ),
  );
}

/// A modal bottom sheet widget that displays a shareable streak card with
/// branding and a copy-to-clipboard action for viral sharing.
class StreakShareSheet extends StatelessWidget {
  const StreakShareSheet({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
  });

  final int currentStreak;
  final int longestStreak;

  String get _shareText =>
      '\u{1F525} I just hit a $currentStreak-day push-up streak on RepGate! '
      'My apps stay unlocked because I show up daily. \u{1F4AA}\n\n'
      'Download RepGate and earn your screen time!';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorder : AppColors.grey200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Share your streak',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 20),

          // Shareable streak card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              children: [
                // Streak number (big hero text)
                Text(
                  '$currentStreak',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.limeBright,
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DAY STREAK',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),

                // Longest streak
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Longest: $longestStreak days',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey300,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 16),

                // Motivational message
                Text(
                  getStreakMessage(currentStreak),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                ),
                const SizedBox(height: 24),

                // Branding
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fitness_center_rounded,
                        size: 16,
                        color: AppColors.limeBright,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RepGate - Earn Your Screen Time',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.limeBright,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Copy to clipboard button
          PillButton(
            label: 'Copy to clipboard',
            icon: Icons.copy_rounded,
            variant: PillVariant.lime,
            onPressed: () => _copyToClipboard(context),
          ),
          const SizedBox(height: 12),

          // Close button
          PillButton(
            label: 'Close',
            variant: PillVariant.outline,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _shareText));
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'Copied! Paste it anywhere to share your streak \u{1F525}',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
