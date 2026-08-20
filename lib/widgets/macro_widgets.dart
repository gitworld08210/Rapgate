import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'soft_card.dart';

/// A macro tile with a colored circular icon badge — exactly the
/// "48g Carbs / 160g Protein / 72g Fat" trio from the reference.
class MacroTile extends StatelessWidget {
  const MacroTile({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.grey200,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Row of the three standard macros.
class MacroRow extends StatelessWidget {
  const MacroRow({
    super.key,
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final double carbs;
  final double protein;
  final double fat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MacroTile(
            value: '${carbs.toStringAsFixed(0)}g',
            label: 'Carbs',
            color: AppColors.carbs,
            icon: Icons.grain_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MacroTile(
            value: '${protein.toStringAsFixed(0)}g',
            label: 'Protein',
            color: AppColors.protein,
            icon: Icons.egg_alt_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MacroTile(
            value: '${fat.toStringAsFixed(0)}g',
            label: 'Fat',
            color: AppColors.fat,
            icon: Icons.water_drop_rounded,
          ),
        ),
      ],
    );
  }
}

/// The segmented multi-color "Healthy Score 5/10" bar from the reference.
class HealthScoreBar extends StatelessWidget {
  const HealthScoreBar({
    super.key,
    required this.score,
    this.outOf = 10,
    this.showLabel = true,
  });

  final double score;
  final int outOf;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ratio = (score / outOf).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Healthy Score  ${score.toStringAsFixed(0)}/$outOf',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            const gap = 4.0;
            final segW = (w - gap * 3) / 4;
            const colors = [
              AppColors.carbs,
              AppColors.protein,
              AppColors.fat,
              AppColors.burned,
            ];
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: List.generate(4, (i) {
                    final segStart = i / 4;
                    final segEnd = (i + 1) / 4;
                    final filled = ratio >= segEnd
                        ? 1.0
                        : ratio <= segStart
                            ? 0.0
                            : (ratio - segStart) * 4;
                    return Padding(
                      padding: EdgeInsets.only(right: i < 3 ? gap : 0),
                      child: SizedBox(
                        width: segW,
                        height: 7,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.grey200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: filled,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colors[i],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                // Position marker dot
                Positioned(
                  left: (w * ratio - 5).clamp(0.0, w - 10),
                  top: -2,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.white : AppColors.ink,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkBg : AppColors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Thick rounded progress bar with an optional floating percentage bubble.
/// Used for "Total progress 40%" and meal calorie progress.
class SoftProgressBar extends StatelessWidget {
  const SoftProgressBar({
    super.key,
    required this.progress,
    this.height = 10,
    this.color = AppColors.limeBright,
    this.showBubble = false,
    this.bubbleLabel,
  });

  final double progress;
  final double height;
  final Color color;
  final bool showBubble;
  final String? bubbleLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBubble)
              Padding(
                padding: EdgeInsets.only(
                  left: (w * p - 22).clamp(0.0, w - 44),
                  bottom: 6,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.white : AppColors.ink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bubbleLabel ?? '${(p * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.ink : AppColors.white,
                    ),
                  ),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(height),
              child: SizedBox(
                height: height,
                child: Stack(
                  children: [
                    Container(
                      color: isDark ? AppColors.darkBorder : AppColors.grey200,
                    ),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      widthFactor: p,
                      child: Container(color: color),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Small pastel stat tile: icon chip + big value + unit, e.g.
/// "Step to walk 5,234 steps" / "Drink water 12 glass"
class QuickStatTile extends StatelessWidget {
  const QuickStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.tint,
    this.onTap,
    this.progress,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 2,
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: tint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 3),
              Text(unit, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            SoftProgressBar(progress: progress!, height: 6, color: tint),
          ],
        ],
      ),
    );
  }
}
