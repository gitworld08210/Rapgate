import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// A premium glassmorphism card with frosted glass effect.
/// Uses BackdropFilter for the blur and a semi-transparent fill.
/// Adapts beautifully to both light and dark mode.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius,
    this.blur = 12.0,
    this.opacity = 0.08,
    this.borderOpacity = 0.15,
    this.width,
    this.height,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final double? width;
  final double? height;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.xl);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withOpacity(opacity),
                          Colors.white.withOpacity(opacity * 0.5),
                        ]
                      : [
                          Colors.white.withOpacity(0.7),
                          Colors.white.withOpacity(0.4),
                        ],
                ),
            borderRadius: radius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(borderOpacity)
                  : Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
