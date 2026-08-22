import 'package:flutter/material.dart';

import '../models/coach_message_model.dart';
import '../utils/app_theme.dart';

/// The coach's identity mark. A soft lime gradient with a bloom behind it, so
/// the assistant reads as a distinct presence rather than another grey avatar.
class CoachAvatar extends StatelessWidget {
  const CoachAvatar({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.limeBright, AppColors.green],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: AppColors.limeDeep.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome,
        size: size * 0.55,
        color: AppColors.ink,
      ),
    );
  }
}

/// Wraps a message so it fades and lifts into place instead of snapping in.
/// Each bubble animates once on insert; the list is otherwise static.
class MessageEntrance extends StatefulWidget {
  const MessageEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<MessageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.16),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    // A slight overshoot makes the arrival feel physical rather than linear.
    curve: Curves.easeOutCubic,
  ));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Three dots that rise and brighten in sequence while the coach composes.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.grey100,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
          bottomRight: Radius.circular(AppRadius.lg),
          bottomLeft: Radius.circular(6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              // Stagger each dot by a third of the cycle, then read a smooth
              // 0→1→0 curve so the wave loops without a visible seam.
              final phase = (_controller.value - i * 0.18) % 1.0;
              final wave = phase < 0.5
                  ? Curves.easeInOut.transform(phase * 2)
                  : Curves.easeInOut.transform((1 - phase) * 2);
              return Container(
                margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
                transform: Matrix4.translationValues(0, -2.5 * wave, 0),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.grey300 : AppColors.grey500)
                      .withValues(alpha: 0.4 + 0.6 * wave),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// A single chat row: avatar + bubble for the coach, right-aligned dark bubble
/// for the user. The tail corner is squared on the sender's side, which is the
/// convention every mature chat product uses to signal direction at a glance.
class CoachBubble extends StatelessWidget {
  const CoachBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onSuggestionTap,
  });

  final CoachMessage message;
  final VoidCallback? onRetry;
  final ValueChanged<MealSuggestion>? onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (message.hasFailed) ...[
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 13, color: AppColors.danger),
                      SizedBox(width: 4),
                      Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.76,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.limeBright : AppColors.ink,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    topRight: Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(AppRadius.lg),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.ink : AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CoachAvatar(),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 2),
                      child: Text(
                        'RepGate Coach',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          color: isDark
                              ? AppColors.grey300
                              : AppColors.grey500,
                        ),
                      ),
                    ),
                    if (message.isPending)
                      const TypingIndicator()
                    else
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.74,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCard
                              : AppColors.grey100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(AppRadius.lg),
                            topRight: Radius.circular(AppRadius.lg),
                            bottomRight: Radius.circular(AppRadius.lg),
                            bottomLeft: Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.white : AppColors.ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Suggestion cards sit outside the bubble and scroll horizontally, so
          // three options never squeeze the reply into a narrow column.
          if (message.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 40, right: 8),
                itemCount: message.suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => MealSuggestionCard(
                  suggestion: message.suggestions[i],
                  onTap: onSuggestionTap == null
                      ? null
                      : () => onSuggestionTap!(message.suggestions[i]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A recommended meal with its protein and calorie figures.
class MealSuggestionCard extends StatelessWidget {
  const MealSuggestionCard({
    super.key,
    required this.suggestion,
    this.onTap,
  });

  final MealSuggestion suggestion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 168,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.grey200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: isDark ? AppColors.white : AppColors.ink,
                    ),
                  ),
                  if (suggestion.note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      suggestion.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey500,
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  _stat(
                    '${suggestion.protein.toStringAsFixed(0)}g',
                    'protein',
                    AppColors.protein,
                    isDark,
                  ),
                  const SizedBox(width: 6),
                  _stat(
                    suggestion.calories.toStringAsFixed(0),
                    'kcal',
                    AppColors.burned,
                    isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color accent, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isDark ? 0.16 : 0.09),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable starter prompt shown on the empty state.
class StarterPromptChip extends StatelessWidget {
  const StarterPromptChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.chip,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: AppRadius.chip,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.grey200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.limeDeep),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
