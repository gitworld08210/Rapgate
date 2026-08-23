import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/meal_favorite_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

/// Horizontal scrollable row of saved meal favorites with premium card design.
///
/// Shows favorite meal cards with name, calorie count, and a quick-add action.
/// Used at the top of the food log screen for rapid meal logging.
class FavoritesSection extends StatelessWidget {
  const FavoritesSection({super.key, this.onFavoriteTapped});

  /// Called when a favorite card is tapped (to pre-fill food details).
  final void Function(MealFavoriteModel favorite)? onFavoriteTapped;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<MealFavoriteModel>>(
      stream: context.read<DatabaseService>().streamMealFavorites(uid),
      builder: (context, snapshot) {
        final favorites = snapshot.data ?? [];
        if (favorites.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.page,
              child: Row(
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'Favorites',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${favorites.length} saved',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: favorites.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final favorite = favorites[index];
                  return _FavoriteCard(
                    favorite: favorite,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onFavoriteTapped?.call(favorite);
                    },
                    onDismiss: () async {
                      HapticFeedback.mediumImpact();
                      await context
                          .read<DatabaseService>()
                          .deleteMealFavorite(uid, favorite.id);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.favorite,
    required this.onTap,
    required this.onDismiss,
  });

  final MealFavoriteModel favorite;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDismiss,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.limeSoft,
              AppColors.white,
            ],
          ),
          border: Border.all(
            color: AppColors.limeBright.withOpacity(0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.limeDeep.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Name
            Text(
              favorite.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
            ),
            // Calories + quick add
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${favorite.totalCalories.toStringAsFixed(0)} kcal',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.grey500,
                        ),
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.limeDeep.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 14,
                    color: AppColors.limeDeep,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
