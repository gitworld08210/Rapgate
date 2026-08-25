import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/tips_data.dart';
import 'soft_card.dart';

/// A visually distinct card that shows a contextual daily health tip.
///
/// Dismissible for the current session (state resets on navigation).
/// Background color cycles by day of week using pastel design tokens.
class DailyTipCard extends StatefulWidget {
  const DailyTipCard({super.key, required this.tip});

  final HealthTip tip;

  @override
  State<DailyTipCard> createState() => _DailyTipCardState();
}

class _DailyTipCardState extends State<DailyTipCard> {
  bool _dismissed = false;

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
    if (_dismissed) return const SizedBox.shrink();

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
              onPressed: () => setState(() => _dismissed = true),
            ),
          ),
        ],
      ),
    );
  }
}
