import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Premium shimmer/skeleton loading placeholder.
/// Replaces boring CircularProgressIndicators with content-shaped placeholders
/// that have a beautiful shimmer animation - like top SaaS apps.
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.child,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  /// Optional child to wrap with shimmer effect.
  final Widget? child;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkCard : AppColors.grey100;
    final highlightColor = isDark ? AppColors.darkBorder : AppColors.grey200;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(widget.height / 2);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// A shimmer card placeholder - mimics a full card loading state.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(width: 120, height: 14),
          const SizedBox(height: 12),
          ShimmerLoading(height: 12),
          const SizedBox(height: 8),
          ShimmerLoading(width: 200, height: 12),
          const Spacer(),
          ShimmerLoading(width: 80, height: 10),
        ],
      ),
    );
  }
}
