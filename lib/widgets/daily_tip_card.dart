import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/tips_data.dart';
import 'soft_card.dart';

/// Tracks the date (year + month + day) when the tip was last dismissed.
/// Survives widget disposal within the same app session. Resets on new day
/// or app restart, which is the intended behavior (show one tip per day).
final ValueNotifier<DateTime?> _dismissedDate = ValueNotifier<DateTime?>(null);

/// Whether the tip card has been dismissed today.
bool _isDismissedToday() {
  final dismissed = _dismissedDate.value;
  if (dismissed == null) return false;
  final now = DateTime.now();
  return dismissed.year == now.year &&
      dismissed.month == now.month &&
      dismissed.day == now.day;
}

/// A visually distinct card that shows a contextual daily health tip.
///
/// Dismissible for the current day within the same app session. The dismiss
/// state is hoisted to a top-level ValueNotifier so it persists across
/// navigation events (tab switches, push/pop) without SharedPreferences.
class DailyTipCard extends StatefulWidget {
  const DailyTipCard({super.key, required this.tip});

  final HealthTip tip;

  @override
  State<DailyTipCard> createState() => _DailyTipCardState();
}

class _DailyTipCardState extends State<DailyTipCard> {
  @override
  void initState() {
    super.initState();
    _dismissedDate.addListener(_onDismissChanged);
  }

  @override
  void dispose() {
    _dismissedDate.removeListener(_onDismissChanged);
    super.dispose();
  }

  void _onDismissChanged() {
    if (mounted) setState(() {});
  }

  void _dismiss() {
    _dismissedDate.value = DateTime.now();
  }

  /// Returns a pastel color based on the current day of the week.
  Color _cardColor() {
    final weekday = DateTime.now().weekday; // 1 = Monday .. 7 = Sunday
    return switch (weekday) {
      1 => AppColors.pastelGreen,
      2 => AppColors.pastelBlue,
      3 => AppColors.pastelOrange,
      4 => AppColors.pastelPurple,
      5 => AppColors.pastelGreen,
      6 => AppColors.pastelBlue,
      _ => AppColors.pastelOrange, // Sunday
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissedToday()) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;

    return SoftCard(
      color: _cardColor(),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.limeSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.tip.emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 12),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tip.title,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.tip.body,
                  style: textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Dismiss button
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              icon: const Icon(Icons.close_rounded, color: AppColors.grey500),
              onPressed: _dismiss,
            ),
          ),
        ],
      ),
    );
  }
}
