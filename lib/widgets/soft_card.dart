import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// The base card used across the app: very rounded, soft diffuse shadow,
/// white (or tinted) fill. Matches the reference UI card treatment.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.radius,
    this.onTap,
    this.border,
    this.shadows,
    this.width,
    this.height,
    this.gradient,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double? radius;
  final VoidCallback? onTap;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;
  final Gradient? gradient;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius ?? AppRadius.xl);

    final content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (color ?? (isDark ? AppColors.darkCard : AppColors.white))
            : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: border ?? (isDark ? Border.all(color: AppColors.darkBorder) : null),
        boxShadow: isDark ? null : (shadows ?? AppShadows.soft),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: content,
      ),
    );
  }
}

/// Section heading with an optional trailing "See all" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.md),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Row(
                children: [
                  Text(
                    actionLabel!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey500,
                        ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.grey500),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
