import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../utils/app_theme.dart';
import '../../../services/pushup_service.dart';

/// Displays real-time form feedback as a colored arc/gauge showing current
/// elbow angle quality. Green = good form, yellow = partial, red = too shallow.
class RepQualityIndicator extends StatelessWidget {
  const RepQualityIndicator({
    super.key,
    required this.quality,
    required this.elbowAngle,
    required this.isDown,
  });

  final RepQuality quality;
  final double? elbowAngle;
  final bool isDown;

  Color _qualityColor() {
    switch (quality) {
      case RepQuality.good:
        return AppColors.success;
      case RepQuality.partial:
        return AppColors.warning;
      case RepQuality.tooShallow:
        return AppColors.danger;
      case RepQuality.extending:
        return AppColors.limeBright;
    }
  }

  String _tipText() {
    switch (quality) {
      case RepQuality.good:
        return 'Great form!';
      case RepQuality.partial:
        return 'Go deeper!';
      case RepQuality.tooShallow:
        return 'Too shallow';
      case RepQuality.extending:
        return 'Full extension!';
    }
  }

  IconData _tipIcon() {
    switch (quality) {
      case RepQuality.good:
        return Icons.check_circle_rounded;
      case RepQuality.partial:
        return Icons.arrow_downward_rounded;
      case RepQuality.tooShallow:
        return Icons.warning_rounded;
      case RepQuality.extending:
        return Icons.arrow_upward_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (elbowAngle == null) return const SizedBox.shrink();

    final color = _qualityColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: color.withOpacity(0.6),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini arc gauge
          SizedBox(
            width: 32,
            height: 32,
            child: CustomPaint(
              painter: _ArcGaugePainter(
                progress: _normalizedAngle(),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_tipIcon(), size: 14, color: color),
                  const SizedBox(width: 5),
                  Text(
                    _tipText(),
                    style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${elbowAngle!.toStringAsFixed(0)}\u00B0',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Normalizes the elbow angle to a 0..1 range for the gauge.
  /// 60 degrees (fully flexed) = 0.0, 160 degrees (fully extended) = 1.0
  double _normalizedAngle() {
    if (elbowAngle == null) return 0.0;
    const minAngle = 60.0;
    const maxAngle = 160.0;
    return ((elbowAngle! - minAngle) / (maxAngle - minAngle)).clamp(0.0, 1.0);
  }
}

/// Custom painter for a small arc gauge showing the current angle progress.
class _ArcGaugePainter extends CustomPainter {
  _ArcGaugePainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // Background arc (track)
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75, // start at bottom-left
      math.pi * 1.5, // sweep 270 degrees
      false,
      trackPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcGaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
