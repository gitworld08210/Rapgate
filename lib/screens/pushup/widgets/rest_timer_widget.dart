import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../widgets/pill_button.dart';

/// Circular countdown rest timer shown after a failed/incomplete session.
///
/// Recommends 60-90 seconds of rest before allowing another attempt.
/// Can be dismissed early by the user.
class RestTimerWidget extends StatefulWidget {
  /// Duration of the rest timer in seconds (default 60).
  final int durationSeconds;

  /// Called when the timer completes or is dismissed.
  final VoidCallback onComplete;

  const RestTimerWidget({
    super.key,
    this.durationSeconds = 60,
    required this.onComplete,
  });

  @override
  State<RestTimerWidget> createState() => _RestTimerWidgetState();
}

class _RestTimerWidgetState extends State<RestTimerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationSeconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    )..forward();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        t.cancel();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeText = '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.pastelPink,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(
            'Take a breather',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Rest before your next attempt for better performance',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.grey700,
                ),
          ),
          const SizedBox(height: 24),

          // Circular countdown
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _RestArcPainter(progress: _controller.value),
              child: Center(
                child: Text(
                  timeText,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Dismiss button
          PillButton(
            label: 'Skip rest',
            variant: PillVariant.outline,
            expand: false,
            onPressed: widget.onComplete,
          ),
        ],
      ),
    );
  }
}

/// Paints a circular arc showing rest timer progress.
class _RestArcPainter extends CustomPainter {
  final double progress;

  _RestArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Background track
    final trackPaint = Paint()
      ..color = AppColors.grey200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc (counts down)
    final arcPaint = Paint()
      ..color = AppColors.danger
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * (1.0 - progress);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RestArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
