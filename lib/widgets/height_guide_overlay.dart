import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/height_calculator.dart';

/// Camera overlay widget that shows a silhouette outline and positioning
/// guides for the height measurement camera view.
///
/// Displays:
/// - A translucent silhouette outline where the person should stand
/// - Positioning feedback text
/// - A vertical ruler animation on the side
/// - Minimum distance indicators
class HeightGuideOverlay extends StatelessWidget {
  final HeightMeasurementFeedback feedback;
  final double animationValue;
  final bool showSilhouette;

  const HeightGuideOverlay({
    super.key,
    required this.feedback,
    this.animationValue = 1.0,
    this.showSilhouette = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Silhouette guide
        if (showSilhouette) _buildSilhouette(context),

        // Vertical ruler on the left side
        Positioned(
          left: 16,
          top: 60,
          bottom: 60,
          child: _buildVerticalRuler(context),
        ),

        // Feedback text at bottom
        Positioned(
          left: 24,
          right: 24,
          bottom: 32,
          child: _buildFeedbackBadge(context),
        ),

        // Corner brackets for frame guide
        ..._buildCornerBrackets(context),
      ],
    );
  }

  Widget _buildSilhouette(BuildContext context) {
    final isReady = feedback.isReady;
    final silhouetteColor = isReady
        ? AppColors.limeBright.withOpacity(0.15 + 0.1 * animationValue)
        : Colors.white.withOpacity(0.08);

    return Center(
      child: Container(
        width: 120,
        height: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 40),
        child: CustomPaint(
          painter: _SilhouettePainter(
            color: silhouetteColor,
            borderColor: isReady
                ? AppColors.limeBright.withOpacity(0.6)
                : Colors.white.withOpacity(0.2),
            animationValue: animationValue,
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalRuler(BuildContext context) {
    return SizedBox(
      width: 24,
      child: CustomPaint(
        painter: _RulerPainter(
          color: Colors.white.withOpacity(0.4),
          animationValue: animationValue,
        ),
      ),
    );
  }

  Widget _buildFeedbackBadge(BuildContext context) {
    final isReady = feedback.isReady;
    final bgColor = isReady
        ? AppColors.limeBright.withOpacity(0.9)
        : Colors.black.withOpacity(0.7);
    final textColor = isReady ? AppColors.ink : Colors.white;
    final icon = isReady ? Icons.check_circle_rounded : Icons.info_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isReady
              ? AppColors.limeBright
              : Colors.white.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: isReady ? AppShadows.limeGlow : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              feedback.message,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerBrackets(BuildContext context) {
    final isReady = feedback.isReady;
    final color = isReady
        ? AppColors.limeBright
        : Colors.white.withOpacity(0.5);
    final bracketLength = 32.0;
    final bracketThickness = 3.0;
    final margin = 24.0;

    return [
      // Top-left
      Positioned(
        top: margin,
        left: margin,
        child: _CornerBracket(
          color: color,
          length: bracketLength,
          thickness: bracketThickness,
          corner: _Corner.topLeft,
        ),
      ),
      // Top-right
      Positioned(
        top: margin,
        right: margin,
        child: _CornerBracket(
          color: color,
          length: bracketLength,
          thickness: bracketThickness,
          corner: _Corner.topRight,
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: margin + 70,
        left: margin,
        child: _CornerBracket(
          color: color,
          length: bracketLength,
          thickness: bracketThickness,
          corner: _Corner.bottomLeft,
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: margin + 70,
        right: margin,
        child: _CornerBracket(
          color: color,
          length: bracketLength,
          thickness: bracketThickness,
          corner: _Corner.bottomRight,
        ),
      ),
    ];
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerBracket extends StatelessWidget {
  final Color color;
  final double length;
  final double thickness;
  final _Corner corner;

  const _CornerBracket({
    required this.color,
    required this.length,
    required this.thickness,
    required this.corner,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: length,
      height: length,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          color: color,
          thickness: thickness,
          corner: corner,
        ),
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final _Corner corner;

  _CornerBracketPainter({
    required this.color,
    required this.thickness,
    required this.corner,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    switch (corner) {
      case _Corner.topLeft:
        path.moveTo(0, size.height);
        path.lineTo(0, 0);
        path.lineTo(size.width, 0);
        break;
      case _Corner.topRight:
        path.moveTo(0, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height);
        break;
      case _Corner.bottomLeft:
        path.moveTo(0, 0);
        path.lineTo(0, size.height);
        path.lineTo(size.width, size.height);
        break;
      case _Corner.bottomRight:
        path.moveTo(0, size.height);
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, 0);
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SilhouettePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double animationValue;

  _SilhouettePainter({
    required this.color,
    required this.borderColor,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw a simplified human silhouette
    final centerX = size.width / 2;
    final headRadius = size.width * 0.15;
    final topPadding = size.height * 0.05;

    // Head
    final headCenter = Offset(centerX, topPadding + headRadius);
    canvas.drawCircle(headCenter, headRadius, fillPaint);
    canvas.drawCircle(headCenter, headRadius, borderPaint);

    // Torso
    final torsoTop = topPadding + headRadius * 2 + 8;
    final torsoBottom = size.height * 0.55;
    final torsoWidth = size.width * 0.45;

    final torsoPath = Path()
      ..moveTo(centerX - torsoWidth / 2, torsoTop)
      ..lineTo(centerX + torsoWidth / 2, torsoTop)
      ..lineTo(centerX + torsoWidth * 0.4, torsoBottom)
      ..lineTo(centerX - torsoWidth * 0.4, torsoBottom)
      ..close();

    canvas.drawPath(torsoPath, fillPaint);
    canvas.drawPath(torsoPath, borderPaint);

    // Legs
    final legTop = torsoBottom;
    final legBottom = size.height * 0.95;
    final legWidth = size.width * 0.15;
    final legGap = 4.0;

    // Left leg
    final leftLegPath = Path()
      ..moveTo(centerX - legGap, legTop)
      ..lineTo(centerX - torsoWidth * 0.35, legTop)
      ..lineTo(centerX - legWidth - legGap, legBottom)
      ..lineTo(centerX - legGap, legBottom)
      ..close();

    canvas.drawPath(leftLegPath, fillPaint);
    canvas.drawPath(leftLegPath, borderPaint);

    // Right leg
    final rightLegPath = Path()
      ..moveTo(centerX + legGap, legTop)
      ..lineTo(centerX + torsoWidth * 0.35, legTop)
      ..lineTo(centerX + legWidth + legGap, legBottom)
      ..lineTo(centerX + legGap, legBottom)
      ..close();

    canvas.drawPath(rightLegPath, fillPaint);
    canvas.drawPath(rightLegPath, borderPaint);
  }

  @override
  bool shouldRepaint(_SilhouettePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.animationValue != animationValue;
  }
}

class _RulerPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  _RulerPainter({
    required this.color,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // Draw vertical line
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Draw tick marks
    final tickCount = 20;
    final spacing = size.height / tickCount;

    for (int i = 0; i <= tickCount; i++) {
      final y = i * spacing;
      final isLargeTick = i % 5 == 0;
      final tickWidth = isLargeTick ? size.width * 0.8 : size.width * 0.4;

      canvas.drawLine(
        Offset((size.width - tickWidth) / 2, y),
        Offset((size.width + tickWidth) / 2, y),
        paint..strokeWidth = isLargeTick ? 1.5 : 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.animationValue != animationValue;
  }
}
