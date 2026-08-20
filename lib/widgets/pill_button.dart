import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

enum PillVariant { dark, lime, outline, soft, danger }

/// The signature black pill CTA from the reference UI, plus variants.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = PillVariant.dark,
    this.expand = true,
    this.loading = false,
    this.padding,
    this.fontSize = 15,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final PillVariant variant;
  final bool expand;
  final bool loading;
  final EdgeInsetsGeometry? padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onPressed == null || loading;

    late Color bg;
    late Color fg;
    BoxBorder? border;
    List<BoxShadow>? shadow;

    switch (variant) {
      case PillVariant.dark:
        bg = isDark ? AppColors.limeBright : AppColors.ink;
        fg = isDark ? AppColors.ink : AppColors.white;
        break;
      case PillVariant.lime:
        bg = AppColors.limeBright;
        fg = AppColors.ink;
        shadow = AppShadows.limeGlow;
        break;
      case PillVariant.outline:
        bg = Colors.transparent;
        fg = isDark ? AppColors.white : AppColors.ink;
        border = Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.grey200,
          width: 1.5,
        );
        break;
      case PillVariant.soft:
        bg = isDark ? AppColors.darkCard : AppColors.limeSoft;
        fg = isDark ? AppColors.white : AppColors.ink;
        break;
      case PillVariant.danger:
        bg = AppColors.danger;
        fg = AppColors.white;
        break;
    }

    if (disabled) {
      bg = variant == PillVariant.outline
          ? Colors.transparent
          : (isDark ? AppColors.darkBorder : AppColors.grey200);
      fg = AppColors.grey500;
      shadow = null;
    }

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 8),
            Icon(trailingIcon, size: 18, color: fg),
          ],
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: AppRadius.chip,
        child: Container(
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 26, vertical: 17),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.chip,
            border: border,
            boxShadow: shadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Small circular icon button (bell, back, heart, more) — used in headers.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 42,
    this.iconSize = 20,
    this.background,
    this.iconColor,
    this.showBadge = false,
    this.bordered = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? iconColor;
  final bool showBadge;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background ??
                  (isDark ? AppColors.darkCard : AppColors.white),
              shape: BoxShape.circle,
              border: bordered
                  ? Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.grey200,
                    )
                  : null,
              boxShadow: isDark ? null : AppShadows.soft,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor ?? (isDark ? AppColors.white : AppColors.ink),
            ),
          ),
          if (showBadge)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkBg : AppColors.white,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Segmented toggle — the "Today / Weekly" control in the reference.
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.grey100,
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected
                      ? (isDark ? AppColors.limeBright : AppColors.ink)
                      : Colors.transparent,
                  borderRadius: AppRadius.chip,
                ),
                child: Text(
                  options[i],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 13.5,
                        color: selected
                            ? (isDark ? AppColors.ink : AppColors.white)
                            : AppColors.grey500,
                      ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
