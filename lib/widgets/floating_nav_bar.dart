import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Floating bottom navigation with a raised center action button —
/// the nav treatment used across the reference screens.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.onCenterTap,
    this.centerIcon = Icons.center_focus_strong_rounded,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Exactly 4 items; the center FAB is inserted between index 1 and 2.
  final List<({IconData icon, IconData activeIcon, String label})> items;
  final VoidCallback? onCenterTap;
  final IconData centerIcon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // The Scaffold uses extendBody: true, so this bar draws *over* the system
    // navigation area and must lift itself clear of it. Previously this
    // collapsed to a flat 8px whenever an inset existed, which let Android's
    // back/home/recents buttons sit on top of the nav items.
    final systemInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: systemInset > 0 ? systemInset + 8 : 14,
        top: 6,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            height: 66,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              boxShadow: AppShadows.floating,
              border: isDark
                  ? Border.all(color: AppColors.darkBorder)
                  : null,
            ),
            child: Row(
              children: [
                Expanded(child: _navItem(context, 0)),
                Expanded(child: _navItem(context, 1)),
                const SizedBox(width: 62), // gap for the FAB
                Expanded(child: _navItem(context, 2)),
                Expanded(child: _navItem(context, 3)),
              ],
            ),
          ),

          // Center raised FAB
          Positioned(
            top: -12,
            child: GestureDetector(
              onTap: onCenterTap,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.limeBright : AppColors.ink,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? AppColors.limeBright : AppColors.ink)
                          .withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? AppColors.darkBg : AppColors.white,
                    width: 4,
                  ),
                ),
                child: Icon(
                  centerIcon,
                  size: 25,
                  color: isDark ? AppColors.ink : AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = currentIndex == index;
    final item = items[index];

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? (isDark
                      ? AppColors.limeBright.withValues(alpha: 0.18)
                      : AppColors.limeSoft)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: selected
                  ? (isDark ? AppColors.limeBright : AppColors.ink)
                  : AppColors.grey500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected
                  ? (isDark ? AppColors.white : AppColors.ink)
                  : AppColors.grey500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lock-status banner shown at the top of the dashboard: communicates
/// whether blocked apps are currently unlocked and for how long.
class LockStatusBanner extends StatelessWidget {
  const LockStatusBanner({
    super.key,
    required this.isUnlocked,
    this.unlockUntil,
    required this.requiredReps,
    this.onAction,
  });

  final bool isUnlocked;
  final DateTime? unlockUntil;
  final int requiredReps;
  final VoidCallback? onAction;

  String get _timeLeft {
    if (unlockUntil == null) return '';
    final diff = unlockUntil!.difference(DateTime.now());
    if (diff.isNegative) return 'expired';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m left';
    return '${m}m left';
  }

  @override
  Widget build(BuildContext context) {
    final bg = isUnlocked ? AppColors.ink : AppColors.danger;
    final accent = isUnlocked ? AppColors.limeBright : AppColors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isUnlocked ? 0.18 : 0.22),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 21,
              color: accent,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUnlocked ? 'Apps unlocked' : 'Apps locked',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  isUnlocked
                      ? _timeLeft
                      : '$requiredReps push-ups to unlock',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent.withValues(alpha: 0.85),
                      ),
                ),
              ],
            ),
          ),
          if (onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: AppRadius.chip,
                ),
                child: Text(
                  isUnlocked ? 'Details' : 'Start',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isUnlocked ? AppColors.ink : AppColors.danger,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
