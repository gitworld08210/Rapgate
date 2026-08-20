import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Semicircular calorie arc gauge — the centerpiece of the reference
/// dashboard, with Eaten / Cals / Burned readouts flanking it.
class CalorieGauge extends StatelessWidget {
  const CalorieGauge({
    super.key,
    required this.consumed,
    required this.target,
    this.burned = 0,
    this.size = 200,
  });

  final double consumed;
  final double target;
  final double burned;
  final double size;

  double get _remaining => (target - consumed + burned).clamp(0, double.infinity);
  double get _progress => target <= 0 ? 0 : (consumed / target).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.62,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CustomPaint(
            size: Size(size, size * 0.62),
            painter: _ArcPainter(
              progress: _progress,
              trackColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBorder
                  : AppColors.grey200,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: size * 0.04),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _remaining.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: size * 0.19,
                      ),
                ),
                Text(
                  'kcal left',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.trackColor});

  final double progress;
  final Color trackColor;

  static const _startAngle = math.pi; // 180° — left side
  static const _sweep = math.pi; // half circle

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      (size.width - stroke), // full circle box; we only draw the top half
    );

    final track = Paint()
      ..color = trackColor
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, _sweep, false, track);

    if (progress > 0) {
      final gradient = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweep,
        colors: const [
          AppColors.limeBright,
          AppColors.carbs,
          AppColors.burned,
        ],
        stops: const [0.0, 0.55, 1.0],
        transform: GradientRotation(_startAngle),
      );

      final fill = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, _startAngle, _sweep * progress, false, fill);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.trackColor != trackColor;
}

/// The three-up readout beneath/around the gauge: Eaten · Cals · Burned
class CalorieStatRow extends StatelessWidget {
  const CalorieStatRow({
    super.key,
    required this.eaten,
    required this.target,
    required this.burned,
  });

  final double eaten;
  final double target;
  final double burned;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _stat(context, '🍎', eaten, 'Eaten'),
        _stat(context, '🔥', target, 'Target'),
        _stat(context, '⚡', burned, 'Burned'),
      ],
    );
  }

  Widget _stat(BuildContext context, String emoji, double value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(0),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
