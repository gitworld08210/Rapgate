import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/achievement_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';

/// Static metadata for each badge type.
class _BadgeMeta {
  final String key;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String emoji;

  const _BadgeMeta({
    required this.key,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.emoji,
  });
}

const _allBadges = <_BadgeMeta>[
  _BadgeMeta(
    key: 'first_pushup',
    name: 'First Push-up',
    description: 'Completed your first verified push-up session',
    icon: Icons.fitness_center_rounded,
    color: AppColors.limeBright,
    emoji: '💪',
  ),
  _BadgeMeta(
    key: 'streak_7',
    name: '7-Day Warrior',
    description: 'Maintained a 7-day push-up streak',
    icon: Icons.local_fire_department_rounded,
    color: AppColors.burned,
    emoji: '🔥',
  ),
  _BadgeMeta(
    key: 'streak_30',
    name: '30-Day Legend',
    description: 'Maintained a 30-day push-up streak',
    icon: Icons.star_rounded,
    color: Color(0xFFFFD700),
    emoji: '⭐',
  ),
  _BadgeMeta(
    key: 'water_champion',
    name: 'Water Champion',
    description: 'Hit your water goal 7 consecutive days',
    icon: Icons.water_drop_rounded,
    color: AppColors.water,
    emoji: '💧',
  ),
  _BadgeMeta(
    key: 'early_bird',
    name: 'Early Bird',
    description: 'Completed push-ups before 7 AM',
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFFFF9500),
    emoji: '🌅',
  ),
  _BadgeMeta(
    key: 'century_club',
    name: 'Century Club',
    description: '100 total verified push-up sessions',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFAF52DE),
    emoji: '🏆',
  ),
  _BadgeMeta(
    key: 'clean_eater',
    name: 'Clean Eater',
    description: 'Logged 3 meals for 7 consecutive days',
    icon: Icons.restaurant_rounded,
    color: AppColors.carbs,
    emoji: '🥗',
  ),
];

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFBF0),
              Color(0xFFFFFFFF),
              Color(0xFFF8F0FF),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: StreamBuilder<List<AchievementModel>>(
            stream: context.read<DatabaseService>().streamAchievements(uid),
            builder: (context, snapshot) {
              final earned = snapshot.data ?? [];
              final earnedKeys =
                  earned.map((a) => a.badgeKey).toSet();
              final earnedCount = earnedKeys.length;

              return ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  // Header
                  Padding(
                    padding: AppSpacing.page,
                    child: Row(
                      children: [
                        CircleIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          iconSize: 16,
                          bordered: true,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Achievements',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium,
                          ),
                        ),
                        const Text('🏆',
                            style: TextStyle(fontSize: 24)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Progress summary
                  Padding(
                    padding: AppSpacing.page,
                    child: Text(
                      '$earnedCount of ${_allBadges.length} badges earned',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Progress bar
                  Padding(
                    padding: AppSpacing.page,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _allBadges.isEmpty
                            ? 0
                            : earnedCount / _allBadges.length,
                        minHeight: 8,
                        backgroundColor: AppColors.grey100,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.limeBright),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Badge grid
                  Padding(
                    padding: AppSpacing.page,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.88,
                      ),
                      itemCount: _allBadges.length,
                      itemBuilder: (context, index) {
                        final badge = _allBadges[index];
                        final isEarned = earnedKeys.contains(badge.key);
                        final achievement = isEarned
                            ? earned.firstWhere(
                                (a) => a.badgeKey == badge.key)
                            : null;

                        return _BadgeCard(
                          badge: badge,
                          isEarned: isEarned,
                          earnedAt: achievement?.earnedAt,
                          animationDelay: index * 0.1,
                          animController: _animController,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Footer motivation
                  Center(
                    child: Column(
                      children: [
                        const Text('💎',
                            style: TextStyle(fontSize: 28)),
                        const SizedBox(height: 8),
                        Text(
                          'Keep pushing, unlock them all!',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: AppColors.grey500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.badge,
    required this.isEarned,
    required this.earnedAt,
    required this.animationDelay,
    required this.animController,
  });

  final _BadgeMeta badge;
  final bool isEarned;
  final DateTime? earnedAt;
  final double animationDelay;
  final AnimationController animController;

  @override
  Widget build(BuildContext context) {
    final fadeAnim = CurvedAnimation(
      parent: animController,
      curve: Interval(
        (animationDelay).clamp(0.0, 0.8),
        (animationDelay + 0.4).clamp(0.2, 1.0),
        curve: Curves.easeOut,
      ),
    );

    return FadeTransition(
      opacity: fadeAnim,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _showBadgeDetail(context);
        },
        child: ClipRRect(
          borderRadius: AppRadius.cardLg,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: AppRadius.cardLg,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isEarned
                      ? [
                          badge.color.withOpacity(0.12),
                          badge.color.withOpacity(0.05),
                        ]
                      : [
                          Colors.grey.shade100.withOpacity(0.8),
                          Colors.grey.shade50.withOpacity(0.6),
                        ],
                ),
                border: Border.all(
                  color: isEarned
                      ? badge.color.withOpacity(0.3)
                      : Colors.grey.shade200,
                  width: 1.2,
                ),
                boxShadow: isEarned
                    ? [
                        BoxShadow(
                          color: badge.color.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : AppShadows.soft,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Badge icon circle
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isEarned)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                badge.color.withOpacity(0.2),
                                badge.color.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isEarned
                              ? badge.color.withOpacity(0.15)
                              : AppColors.grey200,
                          border: Border.all(
                            color: isEarned
                                ? badge.color.withOpacity(0.4)
                                : AppColors.grey300,
                            width: 2,
                          ),
                        ),
                        child: isEarned
                            ? Icon(badge.icon,
                                size: 24, color: badge.color)
                            : const Icon(Icons.lock_rounded,
                                size: 20, color: AppColors.grey500),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Badge name
                  Text(
                    badge.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: isEarned ? AppColors.ink : AppColors.grey500,
                          fontWeight:
                              isEarned ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),

                  const SizedBox(height: 4),

                  // Status
                  Text(
                    isEarned ? badge.emoji : 'Locked',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isEarned
                              ? badge.color
                              : AppColors.grey500,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBadgeDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEarned
                    ? badge.color.withOpacity(0.15)
                    : AppColors.grey100,
                border: Border.all(
                  color: isEarned
                      ? badge.color.withOpacity(0.4)
                      : AppColors.grey200,
                  width: 2.5,
                ),
              ),
              child: isEarned
                  ? Icon(badge.icon, size: 32, color: badge.color)
                  : const Icon(Icons.lock_rounded,
                      size: 28, color: AppColors.grey500),
            ),
            const SizedBox(height: 18),
            Text(
              badge.name,
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            if (isEarned && earnedAt != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badge.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Earned ${_formatDate(earnedAt!)}',
                  style:
                      Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
                            color: badge.color,
                            fontWeight: FontWeight.w600,
                          ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
