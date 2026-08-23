import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';
import 'widgets/confetti_painter.dart';

/// Full-screen post-session summary displayed after push-up verification.
///
/// Shows total reps verified, session duration, average rep time, form quality
/// score, streak info, and a celebratory confetti animation on success.
/// For failures, shows improvement tips instead.
class PushupSummaryScreen extends StatefulWidget {
  /// Whether the session was verified successfully.
  final bool success;

  /// Number of reps the server verified.
  final int verifiedReps;

  /// Number of reps required by the session.
  final int requiredReps;

  /// Duration of the session.
  final Duration sessionDuration;

  /// Average time per rep in milliseconds.
  final double avgRepTimeMs;

  /// Face visibility ratio (0.0 to 1.0).
  final double faceVisibilityRatio;

  /// Optional error message on failure.
  final String? errorMessage;

  const PushupSummaryScreen({
    super.key,
    required this.success,
    required this.verifiedReps,
    required this.requiredReps,
    required this.sessionDuration,
    required this.avgRepTimeMs,
    required this.faceVisibilityRatio,
    this.errorMessage,
  });

  @override
  State<PushupSummaryScreen> createState() => _PushupSummaryScreenState();
}

class _PushupSummaryScreenState extends State<PushupSummaryScreen> {
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    if (widget.success) {
      // Slight delay so the screen is visible before confetti starts
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _showConfetti = true);
      });
    }
  }

  /// Compute a form quality score from face visibility and rep consistency.
  int get _formScore {
    // Face visibility contributes 60%, rep time consistency contributes 40%.
    final faceScore = (widget.faceVisibilityRatio * 60).round();
    // A good avg rep time is between 1500-3000ms
    double repTimeScore;
    if (widget.avgRepTimeMs >= 1500 && widget.avgRepTimeMs <= 3000) {
      repTimeScore = 40;
    } else if (widget.avgRepTimeMs > 3000 && widget.avgRepTimeMs <= 5000) {
      repTimeScore = 30;
    } else if (widget.avgRepTimeMs >= 800 && widget.avgRepTimeMs < 1500) {
      repTimeScore = 25;
    } else {
      repTimeScore = 15;
    }
    return (faceScore + repTimeScore).round().clamp(0, 100);
  }

  String get _motivationalMessage {
    if (widget.success) {
      final score = _formScore;
      if (score >= 90) return 'Outstanding form! You are crushing it!';
      if (score >= 75) return 'Great session! Your consistency is improving.';
      if (score >= 50) return 'Solid work! Keep showing up every day.';
      return 'Session complete! Focus on form next time.';
    } else {
      return 'Not quite there yet. Rest up and try again.';
    }
  }

  String get _durationText {
    final minutes = widget.sessionDuration.inMinutes;
    final seconds = widget.sessionDuration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // Hero icon
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: widget.success ? AppColors.limeSoft : AppColors.pastelPink,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.success
                          ? Icons.emoji_events_rounded
                          : Icons.refresh_rounded,
                      size: 42,
                      color: widget.success ? AppColors.limeDeep : AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    widget.success ? 'Session Complete!' : 'Session Incomplete',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _motivationalMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.grey500,
                        ),
                  ),

                  const SizedBox(height: 32),

                  // Stats grid
                  _buildStatsGrid(context),

                  const SizedBox(height: 24),

                  // Form quality bar
                  _buildFormQualityBar(context),

                  if (!widget.success) ...[
                    const SizedBox(height: 24),
                    _buildImprovementTips(context),
                  ],

                  const Spacer(flex: 2),

                  // Done button
                  PillButton(
                    label: widget.success ? 'Done' : 'Back to Push-ups',
                    variant: widget.success ? PillVariant.lime : PillVariant.dark,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 34),
                ],
              ),
            ),
          ),

          // Confetti overlay
          if (widget.success)
            Positioned.fill(
              child: ConfettiWidget(play: _showConfetti),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Verified Reps',
            value: '${widget.verifiedReps}/${widget.requiredReps}',
            icon: Icons.check_circle_rounded,
            color: widget.success ? AppColors.success : AppColors.danger,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Duration',
            value: _durationText,
            icon: Icons.timer_rounded,
            color: AppColors.limeDeep,
          ),
        ),
      ],
    );
  }

  Widget _buildFormQualityBar(BuildContext context) {
    final score = _formScore;
    final Color barColor;
    if (score >= 75) {
      barColor = AppColors.success;
    } else if (score >= 50) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Form Quality',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '$score/100',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: barColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: AppColors.grey200),
                  FractionallySizedBox(
                    widthFactor: score / 100,
                    child: Container(color: barColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _miniStat(context, 'Face visible', '${(widget.faceVisibilityRatio * 100).round()}%'),
              const SizedBox(width: 16),
              _miniStat(context, 'Avg rep', '${(widget.avgRepTimeMs / 1000).toStringAsFixed(1)}s'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
        ),
      ],
    );
  }

  Widget _buildImprovementTips(BuildContext context) {
    final tips = <String>[];
    if (widget.faceVisibilityRatio < 0.8) {
      tips.add('Keep your face visible to the front camera throughout the session');
    }
    if (widget.avgRepTimeMs < 1000) {
      tips.add('Slow down your reps - aim for 1.5-3 seconds per rep');
    }
    if (widget.avgRepTimeMs > 5000) {
      tips.add('Try to maintain a steady pace without long pauses between reps');
    }
    if (widget.verifiedReps < widget.requiredReps) {
      tips.add('Ensure full range of motion - arms fully extended then bent');
    }
    if (tips.isEmpty) {
      tips.add('Keep practicing - consistency is key to improvement');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pastelPink,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 18, color: AppColors.danger),
              const SizedBox(width: 8),
              Text(
                'Tips to improve',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.danger,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('\u2022 ', style: TextStyle(color: AppColors.grey700)),
                    Expanded(
                      child: Text(
                        tip,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.grey700,
                            ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// Single stat tile used in the summary stats grid.
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
