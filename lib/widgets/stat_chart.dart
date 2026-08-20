import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Vertical rounded bar chart with a gradient-filled active bar and a
/// floating tooltip bubble — the "Statistic 1250 kcal" chart in the reference.
class GradientBarChart extends StatelessWidget {
  const GradientBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.activeIndex,
    this.maxValue,
    this.height = 180,
    this.barWidth = 30,
    this.tooltipLabel,
  });

  final List<double> values;
  final List<String> labels;
  final int? activeIndex;
  final double? maxValue;
  final double height;
  final double barWidth;
  final String? tooltipLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final max = maxValue ??
        (values.isEmpty
            ? 1.0
            : values.reduce((a, b) => a > b ? a : b) * 1.15);

    return SizedBox(
      height: height + 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(values.length, (i) {
          final isActive = i == activeIndex;
          final ratio = max <= 0 ? 0.0 : (values[i] / max).clamp(0.0, 1.0);

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isActive && tooltipLabel != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.white : AppColors.ink,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tooltipLabel!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.ink : AppColors.white,
                      ),
                    ),
                  ),
                // Bar (track + fill)
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: barWidth,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.grey100,
                              borderRadius:
                                  BorderRadius.circular(barWidth / 2),
                            ),
                          ),
                          AnimatedFractionallySizedBox(
                            duration: Duration(
                                milliseconds: 500 + i * 60),
                            curve: Curves.easeOutCubic,
                            heightFactor: ratio,
                            widthFactor: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: isActive
                                      ? const [
                                          AppColors.limeDeep,
                                          AppColors.limeBright,
                                          AppColors.limeSoft,
                                        ]
                                      : [
                                          AppColors.lime.withOpacity(0.55),
                                          AppColors.lime.withOpacity(0.28),
                                        ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(barWidth / 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  labels.length > i ? labels[i] : '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isActive
                            ? (isDark ? AppColors.white : AppColors.ink)
                            : AppColors.grey500,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w600,
                      ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Sparkline-style line chart for weight progress.
class MiniLineChart extends StatelessWidget {
  const MiniLineChart({
    super.key,
    required this.values,
    this.height = 120,
    this.color = AppColors.limeDeep,
    this.showDots = true,
  });

  final List<double> values;
  final double height;
  final Color color;
  final bool showDots;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Log at least 2 entries to see your trend',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LinePainter(
          values: values,
          color: color,
          showDots: showDots,
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.color,
    required this.showDots,
  });

  final List<double> values;
  final Color color;
  final bool showDots;

  @override
  void paint(Canvas canvas, Size size) {
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs() < 0.01 ? 1.0 : max - min;

    const padV = 14.0;
    final usableH = size.height - padV * 2;
    final stepX = size.width / (values.length - 1);

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final norm = (values[i] - min) / range;
      points.add(Offset(i * stepX, padV + usableH * (1 - norm)));
    }

    // Smooth path
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    // Gradient fill under the line
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.28), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (showDots) {
      // Emphasize the latest point
      final last = points.last;
      canvas.drawCircle(last, 6, Paint()..color = color);
      canvas.drawCircle(last, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values;
}
