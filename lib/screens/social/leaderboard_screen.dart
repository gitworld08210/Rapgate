import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/leaderboard_entry_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';

/// Premium leaderboard screen with glassmorphism podium,
/// animated rank changes, and competitive UX.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  List<LeaderboardEntry>? _entries;
  bool _loading = true;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = context.read<AuthService>().uid;
      if (uid == null) {
        setState(() {
          _error = 'Not signed in';
          _loading = false;
        });
        return;
      }

      final db = context.read<DatabaseService>();
      final entries = await db.getLeaderboard(uid);

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
      _fadeController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load leaderboard';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadLeaderboard,
          color: AppColors.limeBright,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Leaderboard',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.limeBright.withOpacity(0.15)
                              : AppColors.limeSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_alt_rounded,
                              size: 14,
                              color: isDark
                                  ? AppColors.limeBright
                                  : AppColors.limeDeep,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_entries?.length ?? 0}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.limeBright
                                    : AppColors.limeDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Content
              if (_loading)
                SliverToBoxAdapter(child: _buildShimmer())
              else if (_error != null)
                SliverToBoxAdapter(child: _buildError())
              else if (_entries == null || _entries!.isEmpty)
                SliverToBoxAdapter(child: _buildEmpty())
              else ...[
                // Podium for top 3
                if (_entries!.length >= 3)
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildPodium(),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Full ranked list
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AppSpacing.page,
                    child: Text(
                      'Rankings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, 0.1 * (index + 1)),
                              end: Offset.zero,
                            ).animate(_fadeAnimation),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child:
                                  _buildRankRow(_entries![index]),
                            ),
                          ),
                        );
                      },
                      childCount: _entries!.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodium() {
    final top3 = _entries!.take(3).toList();
    // Display order: 2nd, 1st, 3rd
    return Padding(
      padding: AppSpacing.page,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _podiumPlace(top3[1], 2)),
          const SizedBox(width: 8),
          Expanded(child: _podiumPlace(top3[0], 1)),
          const SizedBox(width: 8),
          Expanded(child: _podiumPlace(top3[2], 3)),
        ],
      ),
    );
  }

  Widget _podiumPlace(LeaderboardEntry entry, int place) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heights = {1: 160.0, 2: 130.0, 3: 110.0};
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    final colors = {
      1: const Color(0xFFFFD700),
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      height: heights[place],
      blur: 16,
      opacity: isDark ? 0.1 : 0.6,
      borderOpacity: isDark ? 0.2 : 0.5,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                colors[place]!.withOpacity(0.12),
                colors[place]!.withOpacity(0.04),
              ]
            : [
                colors[place]!.withOpacity(0.15),
                colors[place]!.withOpacity(0.05),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(medals[place]!, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors[place]!.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: colors[place]!.withOpacity(0.6),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.white : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.name.length > 8
                ? '${entry.name.substring(0, 8)}...'
                : entry.name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.white : AppColors.ink,
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 2),
              Text(
                '${entry.currentStreak}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.grey300 : AppColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow(LeaderboardEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMe = entry.isCurrentUser;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isMe
            ? (isDark
                ? AppColors.limeBright.withOpacity(0.1)
                : AppColors.limeSoft)
            : (isDark ? AppColors.darkCard : AppColors.white),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isMe
              ? (isDark
                  ? AppColors.limeBright.withOpacity(0.3)
                  : AppColors.limeBright.withOpacity(0.5))
              : (isDark ? AppColors.darkBorder : AppColors.grey200),
        ),
        boxShadow: isDark ? null : AppShadows.soft,
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _rankBadgeColor(entry.rank).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _rankBadgeColor(entry.rank),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBorder
                  : AppColors.grey100,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.white : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.limeBright,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.weeklyPushups} push-ups this week',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          // Streak
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 3),
                  Text(
                    '${entry.currentStreak}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              Text(
                'streak',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _rankBadgeColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFA0A0A0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppColors.grey500;
    }
  }

  Widget _buildShimmer() {
    return Padding(
      padding: AppSpacing.page,
      child: Column(
        children: [
          const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: ShimmerLoading(height: 130)),
              const SizedBox(width: 8),
              Expanded(child: ShimmerLoading(height: 160)),
              const SizedBox(width: 8),
              Expanded(child: ShimmerLoading(height: 110)),
            ],
          ),
          const SizedBox(height: 32),
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ShimmerLoading(height: 64),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.limeBright.withOpacity(0.12)
                    : AppColors.limeSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group_add_rounded,
                size: 32,
                color: isDark ? AppColors.limeBright : AppColors.limeDeep,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No contacts linked yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Link accountability contacts to compete on the leaderboard and stay motivated together.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PillButton(
              label: 'Link contacts',
              icon: Icons.person_add_rounded,
              variant: PillVariant.lime,
              expand: false,
              onPressed: () {
                HapticFeedback.lightImpact();
                // Navigate to link contacts (future feature)
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            const Text('😵', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            PillButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              variant: PillVariant.soft,
              expand: false,
              onPressed: _loadLeaderboard,
            ),
          ],
        ),
      ),
    );
  }
}
