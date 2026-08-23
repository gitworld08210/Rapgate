import 'dart:math';
import 'package:flutter/material.dart';

import '../services/height_measurement_service.dart';
import '../utils/app_theme.dart';
import '../utils/height_calculator.dart';

/// CustomPainter that draws detected pose landmarks on top of the camera preview
/// for height measurement visualization.
///
/// Shows: head point, shoulder line, vertical measurement line from head to feet,
/// and ankle points. Uses [AppColors.limeBright] for the lines and dots.
/// Dots pulse when a good pose is detected.
class PoseOverlayPainter extends CustomPainter {
  final HeightLandmarks? landmarks;
  final HeightMeasurementFeedback feedback;
  final double animationValue;
  final Size imageSize;
  final bool isFrontCamera;

  PoseOverlayPainter({
    required this.landmarks,
    required this.feedback,
    required this.animationValue,
    required this.imageSize,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks == null) return;

    final lm = landmarks!;

    // Scale factors to map image coordinates to canvas coordinates
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    // Mirror X if front camera
    double translateX(double x) {
      if (isFrontCamera) {
        return size.width - (x * scaleX);
      }
      return x * scaleX;
    }

    double translateY(double y) => y * scaleY;

    final isGoodPose = feedback.isReady;

    // Paint for the measurement line
    final linePaint = Paint()
      ..color = isGoodPose
          ? AppColors.limeBright
          : AppColors.limeBright.withOpacity(0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Paint for landmark dots
    final dotPaint = Paint()
      ..color = AppColors.limeBright
      ..style = PaintingStyle.fill;

    // Paint for the pulsing glow effect
    final glowPaint = Paint()
      ..color = AppColors.limeBright.withOpacity(0.3 * animationValue)
      ..style = PaintingStyle.fill;

    // Dot radius with pulse effect when pose is good
    final baseDotRadius = 6.0;
    final dotRadius = isGoodPose
        ? baseDotRadius + (2.0 * animationValue)
        : baseDotRadius;
    final glowRadius = dotRadius + (8.0 * animationValue);

    // Draw head point
    final headPoint = Offset(translateX(lm.headX), translateY(lm.headY));
    if (isGoodPose) {
      canvas.drawCircle(headPoint, glowRadius, glowPaint);
    }
    canvas.drawCircle(headPoint, dotRadius, dotPaint);

    // Draw inner white dot for head
    final innerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(headPoint, dotRadius * 0.4, innerDotPaint);

    // Draw ankle points
    if (lm.leftAnkleX != null) {
      final leftAnklePoint = Offset(
        translateX(lm.leftAnkleX!),
        translateY(lm.leftAnkleY),
      );
      if (isGoodPose) {
        canvas.drawCircle(leftAnklePoint, glowRadius, glowPaint);
      }
      canvas.drawCircle(leftAnklePoint, dotRadius, dotPaint);
      canvas.drawCircle(leftAnklePoint, dotRadius * 0.4, innerDotPaint);
    }

    if (lm.rightAnkleX != null) {
      final rightAnklePoint = Offset(
        translateX(lm.rightAnkleX!),
        translateY(lm.rightAnkleY),
      );
      if (isGoodPose) {
        canvas.drawCircle(rightAnklePoint, glowRadius, glowPaint);
      }
      canvas.drawCircle(rightAnklePoint, dotRadius, dotPaint);
      canvas.drawCircle(rightAnklePoint, dotRadius * 0.4, innerDotPaint);
    }

    // Draw shoulder line
    if (lm.leftShoulderX != null &&
        lm.leftShoulderY != null &&
        lm.rightShoulderX != null &&
        lm.rightShoulderY != null) {
      final shoulderLinePaint = Paint()
        ..color = AppColors.limeBright.withOpacity(0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(translateX(lm.leftShoulderX!), translateY(lm.leftShoulderY!)),
        Offset(translateX(lm.rightShoulderX!), translateY(lm.rightShoulderY!)),
        shoulderLinePaint,
      );

      // Draw shoulder dots
      final smallDotRadius = 4.0;
      canvas.drawCircle(
        Offset(translateX(lm.leftShoulderX!), translateY(lm.leftShoulderY!)),
        smallDotRadius,
        dotPaint..color = AppColors.limeBright.withOpacity(0.7),
      );
      canvas.drawCircle(
        Offset(translateX(lm.rightShoulderX!), translateY(lm.rightShoulderY!)),
        smallDotRadius,
        dotPaint..color = AppColors.limeBright.withOpacity(0.7),
      );
      dotPaint.color = AppColors.limeBright;
    }

    // Draw vertical measurement line from head to feet
    final feetY = translateY(lm.feetY);
    final measureLineX = translateX(lm.headX);

    // Dashed measurement line
    _drawDashedLine(
      canvas,
      Offset(measureLineX, headPoint.dy),
      Offset(measureLineX, feetY),
      linePaint,
      dashLength: 8.0,
      gapLength: 4.0,
    );

    // Draw horizontal tick marks at head and feet
    final tickLength = 16.0;
    final tickPaint = Paint()
      ..color = AppColors.limeBright
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Head tick
    canvas.drawLine(
      Offset(measureLineX - tickLength / 2, headPoint.dy),
      Offset(measureLineX + tickLength / 2, headPoint.dy),
      tickPaint,
    );

    // Feet tick
    canvas.drawLine(
      Offset(measureLineX - tickLength / 2, feetY),
      Offset(measureLineX + tickLength / 2, feetY),
      tickPaint,
    );

    // Draw measurement arrows at head and feet
    _drawArrow(canvas, Offset(measureLineX, headPoint.dy + 4), true, tickPaint);
    _drawArrow(canvas, Offset(measureLineX, feetY - 4), false, tickPaint);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashLength = 6.0,
    double gapLength = 3.0,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = sqrt(dx * dx + dy * dy);
    final unitDx = dx / distance;
    final unitDy = dy / distance;

    double drawn = 0.0;
    bool drawing = true;

    while (drawn < distance) {
      final segLength = drawing ? dashLength : gapLength;
      final remaining = distance - drawn;
      final seg = min(segLength, remaining);

      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + unitDx * drawn, start.dy + unitDy * drawn),
          Offset(
            start.dx + unitDx * (drawn + seg),
            start.dy + unitDy * (drawn + seg),
          ),
          paint,
        );
      }

      drawn += seg;
      drawing = !drawing;
    }
  }

  void _drawArrow(Canvas canvas, Offset tip, bool pointsUp, Paint paint) {
    final arrowSize = 6.0;
    final direction = pointsUp ? -1.0 : 1.0;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - arrowSize, tip.dy + (arrowSize * direction))
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + arrowSize, tip.dy + (arrowSize * direction));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(PoseOverlayPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
        oldDelegate.feedback != feedback ||
        oldDelegate.animationValue != animationValue;
  }
}
