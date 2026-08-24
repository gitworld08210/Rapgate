import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// A styled card widget displaying the user's daily progress stats.
///
/// Used in [ShareProgressScreen] as a preview of what gets shared (as text).
/// The card shows: pushup streak, health score, calories, and water intake
/// with the app branding.
class ShareProgressCard extends StatelessWidget {
  const ShareProgressCard({
    super.key,
    required this.streak,
    required this.healthScore,
    required this.caloriesEaten,
    required this.calorieTarget,
    required this.waterMl,
    required this.waterTargetMl,
  });

  final int streak;
  final double healthScore;
  final double caloriesEaten;
  final double calorieTarget;
  final int waterMl;
  final int waterTargetMl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.ink,
            Color(0xFF1A2E1A),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App branding
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.limeBright,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  size: 18,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'HealthPush',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Streak highlight
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.limeBright.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.limeBright.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '$streak',
                  style: const TextStyle(
                    color: AppColors.limeBright,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  streak == 1 ? 'DAY STREAK' : 'DAY STREAK',
                  style: TextStyle(
                    color: AppColors.limeBright.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.favorite_rounded,
                  label: 'Health Score',
                  value: '${healthScore.toStringAsFixed(1)}/10',
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatItem(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Calories',
                  value:
                      '${caloriesEaten.toStringAsFixed(0)}/${calorieTarget.toStringAsFixed(0)}',
                  color: AppColors.burned,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.water_drop_rounded,
                  label: 'Water',
                  value:
                      '${(waterMl / 1000).toStringAsFixed(1)}/${(waterTargetMl / 1000).toStringAsFixed(1)}L',
                  color: AppColors.water,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatItem(
                  icon: Icons.emoji_events_rounded,
                  label: 'Push-ups',
                  value: streak > 0 ? 'Done today' : 'Pending',
                  color: AppColors.success,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Tagline
          Text(
            'Earn your screen time',
            style: TextStyle(
              color: AppColors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
