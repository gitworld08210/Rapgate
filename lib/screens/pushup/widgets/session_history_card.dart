import 'package:flutter/material.dart';

import '../../../models/pushup_session_model.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/soft_card.dart';

/// A card showing recent push-up sessions (last 5-7 items).
///
/// Each entry displays date, rep count, and pass/fail status badge
/// in a compact vertical list using [SoftCard] styling.
class SessionHistoryCard extends StatelessWidget {
  /// Recent sessions to display (most recent first).
  final List<PushupSessionModel> sessions;

  const SessionHistoryCard({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 18, color: AppColors.grey500),
                const SizedBox(width: 8),
                Text(
                  'Recent Sessions',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'No sessions yet. Start your first push-up session!',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    // Show up to 5 most recent sessions
    final displaySessions = sessions.take(5).toList();

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 18, color: AppColors.limeDeep),
              const SizedBox(width: 8),
              Text(
                'Recent Sessions',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                '${sessions.length} total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(displaySessions.length, (i) {
            final session = displaySessions[i];
            final isLast = i == displaySessions.length - 1;
            return _SessionRow(session: session, showDivider: !isLast);
          }),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final PushupSessionModel session;
  final bool showDivider;

  const _SessionRow({required this.session, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final isVerified = session.status == PushupSessionStatus.verified;
    final isFailed = session.status == PushupSessionStatus.failed;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Timeline dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isVerified
                      ? AppColors.success
                      : isFailed
                          ? AppColors.danger
                          : AppColors.grey300,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),

              // Date and time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(session.startedAt),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      _formatTime(session.startedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Rep count
              Text(
                '${session.repCount}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 4),
              Text(
                'reps',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 12),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isVerified
                      ? AppColors.pastelGreen
                      : isFailed
                          ? AppColors.pastelPink
                          : AppColors.grey100,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  isVerified
                      ? 'PASS'
                      : isFailed
                          ? 'FAIL'
                          : 'PENDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isVerified
                        ? AppColors.success
                        : isFailed
                            ? AppColors.danger
                            : AppColors.grey500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(sessionDate).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $amPm';
  }
}
