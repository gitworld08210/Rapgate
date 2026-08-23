import 'dart:io';
import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Instagram-story-sized (1080x1920) shareable meal card.
///
/// Renders a beautiful nutrition summary with food photo, macro breakdown,
/// health score, and RepGate branding for social sharing.
class MealShareCard extends StatelessWidget {
  const MealShareCard({
    super.key,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.healthScore,
    this.imageUrl,
    this.localImagePath,
    this.mealTypeLabel,
  });

  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double healthScore;
  final String? imageUrl;
  final String? localImagePath;
  final String? mealTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      height: 1920,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.ink,
            Color(0xFF1A2410), // dark greenish-black
            AppColors.ink,
          ],
        ),
      ),
      child: Column(
        children: [
          // ---------- Food photo area (top 50%) ----------
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(40),
                  ),
                  child: _buildImage(),
                ),
                // Gradient overlay at bottom of photo
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 280,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(40),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.ink.withOpacity(0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                // Food name over the gradient
                Positioned(
                  bottom: 40,
                  left: 48,
                  right: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mealTypeLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.limeBright.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            mealTypeLabel!,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: AppColors.limeBright,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        foodName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------- Nutrition info (bottom half) ----------
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total calories - big highlight
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.limeBright.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.limeBright.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '🔥',
                          style: TextStyle(fontSize: 40),
                        ),
                        const SizedBox(width: 20),
                        Text(
                          '${calories.toStringAsFixed(0)} Kcal',
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                            color: AppColors.limeBright,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Macro row
                  Row(
                    children: [
                      _macroChip('Protein', protein, AppColors.protein),
                      const SizedBox(width: 16),
                      _macroChip('Carbs', carbs, AppColors.carbs),
                      const SizedBox(width: 16),
                      _macroChip('Fat', fat, AppColors.fat),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Health score
                  _healthScoreSection(),

                  const Spacer(),

                  // ---------- RepGate branding ----------
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.limeBright,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'RepGate',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Track your nutrition with RepGate',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: AppColors.grey500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (localImagePath != null) {
      return Image.file(
        File(localImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.limeBright.withOpacity(0.2),
            AppColors.ink,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: const Text('🥗', style: TextStyle(fontSize: 120)),
    );
  }

  Widget _macroChip(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              '${value.toStringAsFixed(0)}g',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _healthScoreSection() {
    final ratio = (healthScore / 10).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Health Score  ${healthScore.toStringAsFixed(0)}/10',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.grey700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.carbs,
                          AppColors.protein,
                          AppColors.limeBright,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
