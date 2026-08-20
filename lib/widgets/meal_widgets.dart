import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'soft_card.dart';
import 'macro_widgets.dart';

/// Food card with image, name, kcal badge, and an action pill —
/// the "Chicken Salad / 480 kcal / Tell me Recipe" card in the reference.
class FoodDiscoveryCard extends StatelessWidget {
  const FoodDiscoveryCard({
    super.key,
    required this.name,
    required this.kcal,
    this.imageUrl,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.width = 168,
  });

  final String name;
  final double kcal;
  final String? imageUrl;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      width: width,
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      color: AppColors.limeSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 8),
            child: Text(
              name,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: _FoodImage(
                  imageUrl: imageUrl,
                  height: 104,
                  width: double.infinity,
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: KcalBadge(kcal: kcal),
              ),
            ],
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onAction,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: AppRadius.chip,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 13, color: AppColors.limeBright),
                    const SizedBox(width: 6),
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small "🔥 480 kcal" pill badge.
class KcalBadge extends StatelessWidget {
  const KcalBadge({super.key, required this.kcal, this.compact = false});

  final double kcal;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.92),
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: compact ? 9 : 11)),
          const SizedBox(width: 4),
          Text(
            '${kcal.toStringAsFixed(0)} kcal',
            style: TextStyle(
              fontSize: compact ? 10 : 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// A logged meal row: thumbnail + name + kcal + trailing check/remove.
class MealLogRow extends StatelessWidget {
  const MealLogRow({
    super.key,
    required this.name,
    required this.kcal,
    this.imageUrl,
    this.subtitle,
    this.onTap,
    this.onRemove,
    this.checked = true,
  });

  final String name;
  final double kcal;
  final String? imageUrl;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _FoodImage(imageUrl: imageUrl, height: 44, width: 44),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle ?? '${kcal.toStringAsFixed(0)} Cal',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            if (checked)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.limeBright,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.check_rounded,
                    size: 15, color: AppColors.ink),
              ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close_rounded,
                    size: 19, color: AppColors.grey500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Meal group card: "Breakfast / 456 / 512 kcal" + progress + ingredients.
class MealGroupCard extends StatelessWidget {
  const MealGroupCard({
    super.key,
    required this.mealName,
    required this.consumed,
    required this.target,
    required this.itemCount,
    this.children = const [],
    this.onAdd,
    this.onMore,
  });

  final String mealName;
  final double consumed;
  final double target;
  final int itemCount;
  final List<Widget> children;
  final VoidCallback? onAdd;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(mealName,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (onAdd != null)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.limeSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 18, color: AppColors.ink),
                  ),
                ),
              if (onMore != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onMore,
                  child: const Icon(Icons.more_vert_rounded,
                      size: 19, color: AppColors.grey500),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(consumed.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.headlineMedium),
              Text(
                ' / ${target.toStringAsFixed(0)} kcal',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SoftProgressBar(
            progress: target <= 0 ? 0 : consumed / target,
            height: 9,
          ),
          if (itemCount > 0) ...[
            const SizedBox(height: 14),
            Text('$itemCount ingredient${itemCount == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.labelSmall),
          ],
          if (children.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...children,
          ],
        ],
      ),
    );
  }
}

/// Circular category chip: food image + label ("Vegan / Carb / Protein").
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.emoji,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.limeBright
                  : (isDark ? AppColors.darkCard : AppColors.limeSoft),
              shape: BoxShape.circle,
              boxShadow: isDark ? null : AppShadows.soft,
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? (isDark ? AppColors.white : AppColors.ink)
                      : AppColors.grey500,
                ),
          ),
        ],
      ),
    );
  }
}

/// Dark photo card with bold overlay text — the "4 DAY STREAK KEEP GOING" card.
class StreakBannerCard extends StatelessWidget {
  const StreakBannerCard({
    super.key,
    required this.streak,
    this.subtitle = 'KEEP GOING',
    this.imageUrl,
    this.onTap,
  });

  final int streak;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          color: AppColors.ink,
          image: imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(imageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.45),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Stack(
          children: [
            if (imageUrl == null)
              Positioned(
                right: -10,
                bottom: -10,
                child: Text(
                  '🔥',
                  style: TextStyle(
                    fontSize: 110,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '$streak',
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(
                              color: AppColors.white,
                              fontSize: 46,
                            ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'DAY\nSTREAK',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: AppColors.white,
                              height: 1.1,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.limeBright,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Graceful image placeholder for food photos.
class _FoodImage extends StatelessWidget {
  const _FoodImage({
    this.imageUrl,
    required this.height,
    required this.width,
  });

  final String? imageUrl;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        height: height,
        width: width,
        color: AppColors.pastelGreen,
        alignment: Alignment.center,
        child: Text('🥗', style: TextStyle(fontSize: height * 0.42)),
      );
    }
    return Image.network(
      imageUrl!,
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: width,
        color: AppColors.pastelGreen,
        alignment: Alignment.center,
        child: Text('🥗', style: TextStyle(fontSize: height * 0.42)),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: height,
          width: width,
          color: AppColors.grey100,
        );
      },
    );
  }
}

/// Public alias so screens can reuse the image placeholder.
class FoodThumb extends StatelessWidget {
  const FoodThumb({
    super.key,
    this.imageUrl,
    this.size = 44,
    this.radius = 12,
  });

  final String? imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: _FoodImage(imageUrl: imageUrl, height: size, width: size),
    );
  }
}
