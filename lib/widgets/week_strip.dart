import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';

/// Horizontal week strip with circular day selectors — active day is a
/// filled circle. Matches "S M T W T F S / 9 10 11 12 13 14 15".
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.completedDates = const {},
    this.showMonthHeader = false,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  /// Dates with a completed activity get a small dot indicator.
  final Set<DateTime> completedDates;
  final bool showMonthHeader;

  List<DateTime> get _week {
    // Week containing selectedDate, starting Sunday
    final start = selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    return List.generate(
      7,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = _week;
    final today = DateTime.now();

    return Column(
      children: [
        if (showMonthHeader)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(selectedDate),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    _navArrow(context, Icons.chevron_left_rounded, () {
                      onDateSelected(
                          selectedDate.subtract(const Duration(days: 7)));
                    }),
                    const SizedBox(width: 6),
                    _navArrow(context, Icons.chevron_right_rounded, () {
                      onDateSelected(selectedDate.add(const Duration(days: 7)));
                    }),
                  ],
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((day) {
            final selected = _isSameDay(day, selectedDate);
            final isToday = _isSameDay(day, today);
            final isFuture = day.isAfter(today);
            final hasActivity =
                completedDates.any((d) => _isSameDay(d, day));

            return Expanded(
              child: GestureDetector(
                onTap: isFuture ? null : () => onDateSelected(day),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(day).substring(0, 1),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: selected
                                ? (isDark ? AppColors.white : AppColors.ink)
                                : AppColors.grey500,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.limeBright
                            : (isDark
                                ? AppColors.darkCard
                                : AppColors.grey100),
                        shape: BoxShape.circle,
                        border: isToday && !selected
                            ? Border.all(
                                color: AppColors.limeBright, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: selected
                                    ? AppColors.ink
                                    : isFuture
                                        ? AppColors.grey300
                                        : (isDark
                                            ? AppColors.white
                                            : AppColors.ink),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: hasActivity
                            ? AppColors.carbs
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _navArrow(BuildContext context, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.grey100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 18, color: isDark ? AppColors.white : AppColors.ink),
      ),
    );
  }
}

/// Greeting header: "Good morning 👋 / Alex Jemison" + avatar + bell.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.name,
    this.avatarUrl,
    this.onNotificationTap,
    this.onAvatarTap,
    this.hasUnread = false,
  });

  final String name;
  final String? avatarUrl;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;
  final bool hasUnread;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _emoji {
    final h = DateTime.now().hour;
    if (h < 12) return '👋';
    if (h < 17) return '☀️';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();

    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.limeSoft,
              shape: BoxShape.circle,
              image: avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: avatarUrl == null
                ? Text(
                    initials,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting $_emoji',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                name.isEmpty ? 'there' : name,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
