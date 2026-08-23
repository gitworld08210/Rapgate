import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// A dual-bar chart that displays calorie and protein values side by side
/// for each day/week. Uses [CustomPainter] - no external chart library.
class CalorieProteinBarChart extends StatelessWidget {
  const CalorieProteinBarChart({
    super.key,
    required this.labels,
    required this.calorieValues,
    required this.proteinValues,
    this.height = 200,
    this.calorieColor = AppColors.green,
    this.proteinColor = AppColors.protein,
    this.maxCalories,
    this.maxProtein,
  });

  final List<String> labels;
  final List<double> calorieValues;
  final List<double> proteinValues;
  final double height;
  final Color calorieColor;
  final Color proteinColor;
  final double? maxCalories;
  final double? maxProtein;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          children: [
            _LegendDot(color: calorieColor, label: 'Calories'),
            const SizedBox(width: 16),
            _LegendDot(color: proteinColor, label: 'Protein'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _DualBarPainter(
              labels: labels,
              calorieValues: calorieValues,
              proteinValues: proteinValues,
              calorieColor: calorieColor,
              proteinColor: proteinColor,
              maxCalories: maxCalories,
              maxProtein: maxProtein,
              textColor: isDark ? AppColors.white : AppColors.grey500,
              gridColor: isDark ? AppColors.darkBorder : AppColors.grey200,
            ),
          ),
        ),
      ],
    );
  }
}

class _DualBarPainter extends CustomPainter {
  _DualBarPainter({
    required this.labels,
    required this.calorieValues,
    required this.proteinValues,
    required this.calorieColor,
    required this.proteinColor,
    required this.textColor,
    required this.gridColor,
    this.maxCalories,
    this.maxProtein,
  });

  final List<String> labels;
  final List<double> calorieValues;
  final List<double> proteinValues;
  final Color calorieColor;
  final Color proteinColor;
  final Color textColor;
  final Color gridColor;
  final double? maxCalories;
  final double? maxProtein;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;

    const bottomPad = 24.0;
    const topPad = 8.0;
    final chartHeight = size.height - bottomPad - topPad;
    final count = labels.length;

    final groupWidth = size.width / count;
    final barWidth = (groupWidth * 0.3).clamp(6.0, 20.0);
    final gap = 3.0;

    // Compute max value for normalization
    final maxCal = maxCalories ??
        (calorieValues.isEmpty
            ? 1.0
            : calorieValues.reduce(math.max) * 1.15);
    final maxProt = maxProtein ??
        (proteinValues.isEmpty
            ? 1.0
            : proteinValues.reduce(math.max) * 1.15);
    // Use calorie scale as primary (protein is scaled proportionally)
    final maxVal = maxCal > 0 ? maxCal : 1.0;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = topPad + chartHeight * (1 - i / 4);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Draw bars
    for (int i = 0; i < count; i++) {
      final centerX = groupWidth * i + groupWidth / 2;

      // Calorie bar
      final calRatio =
          maxVal > 0 ? (calorieValues[i] / maxVal).clamp(0.0, 1.0) : 0.0;
      final calHeight = chartHeight * calRatio;
      final calRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - barWidth - gap / 2,
          topPad + chartHeight - calHeight,
          barWidth,
          calHeight,
        ),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(
        calRect,
        Paint()..color = calorieColor,
      );

      // Protein bar (scaled to calorie axis for visual comparison)
      // Scale protein to approximate visual ratio
      final protScaled = proteinValues[i] * (maxVal / (maxProt > 0 ? maxProt : 1));
      final protRatio = maxVal > 0 ? (protScaled / maxVal).clamp(0.0, 1.0) : 0.0;
      final protHeight = chartHeight * protRatio;
      final protRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX + gap / 2,
          topPad + chartHeight - protHeight,
          barWidth,
          protHeight,
        ),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(
        protRect,
        Paint()..color = proteinColor,
      );

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(centerX - tp.width / 2, size.height - bottomPad + 6),
      );
    }
  }

  @override
  bool shouldRepaint(_DualBarPainter old) =>
      old.calorieValues != calorieValues || old.proteinValues != proteinValues;
}

/// A bar chart showing push-up days completed per week with a target line.
/// Uses [CustomPainter].
class PushupDaysChart extends StatelessWidget {
  const PushupDaysChart({
    super.key,
    required this.labels,
    required this.values,
    this.target = 7,
    this.height = 160,
    this.barColor = AppColors.limeBright,
  });

  final List<String> labels;
  final List<int> values;
  final int target;
  final double height;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: barColor, label: 'Days completed'),
            const SizedBox(width: 16),
            _LegendDot(
              color: AppColors.danger,
              label: 'Target ($target)',
              isDashed: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _PushupBarPainter(
              labels: labels,
              values: values,
              target: target,
              barColor: barColor,
              targetColor: AppColors.danger,
              textColor: isDark ? AppColors.white : AppColors.grey500,
              gridColor: isDark ? AppColors.darkBorder : AppColors.grey200,
            ),
          ),
        ),
      ],
    );
  }
}

class _PushupBarPainter extends CustomPainter {
  _PushupBarPainter({
    required this.labels,
    required this.values,
    required this.target,
    required this.barColor,
    required this.targetColor,
    required this.textColor,
    required this.gridColor,
  });

  final List<String> labels;
  final List<int> values;
  final int target;
  final Color barColor;
  final Color targetColor;
  final Color textColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;

    const bottomPad = 24.0;
    const topPad = 8.0;
    final chartHeight = size.height - bottomPad - topPad;
    final count = labels.length;
    final groupWidth = size.width / count;
    final barWidth = (groupWidth * 0.5).clamp(12.0, 36.0);

    final maxVal = (values.isEmpty ? target : math.max(values.reduce(math.max), target)) * 1.15;

    // Draw grid
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = topPad + chartHeight * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Target line
    final targetY = topPad + chartHeight * (1 - target / maxVal);
    final dashPaint = Paint()
      ..color = targetColor
      ..strokeWidth = 1.5;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, targetY),
        Offset(math.min(startX + dashWidth, size.width), targetY),
        dashPaint,
      );
      startX += dashWidth + dashSpace;
    }

    // Bars
    for (int i = 0; i < count; i++) {
      final centerX = groupWidth * i + groupWidth / 2;
      final ratio = maxVal > 0 ? (values[i] / maxVal).clamp(0.0, 1.0) : 0.0;
      final barHeight = chartHeight * ratio;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - barWidth / 2,
          topPad + chartHeight - barHeight,
          barWidth,
          barHeight,
        ),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, Paint()..color = barColor);

      // Value on top
      final valTp = TextPainter(
        text: TextSpan(
          text: '${values[i]}',
          style: TextStyle(
            color: textColor,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valTp.paint(
        canvas,
        Offset(
          centerX - valTp.width / 2,
          topPad + chartHeight - barHeight - 14,
        ),
      );

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(centerX - tp.width / 2, size.height - bottomPad + 6),
      );
    }
  }

  @override
  bool shouldRepaint(_PushupBarPainter old) => old.values != values;
}

/// A small legend indicator dot + label.
class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.isDashed = false,
  });

  final Color color;
  final String label;
  final bool isDashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isDashed ? null : color,
            border: isDashed ? Border.all(color: color, width: 2) : null,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.grey500,
          ),
        ),
      ],
    );
  }
}
