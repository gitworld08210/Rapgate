import 'package:flutter/material.dart';

import '../../models/group_model.dart';
import '../../services/group_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';

/// Group detail screen: daily leaderboard, weekly totals, invite sharing.
class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.group});

  final GroupModel group;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final GroupService _groupService = GroupService();
  GroupLeaderboard? _leaderboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final leaderboard =
          await _groupService.getGroupLeaderboard(widget.group.id);
      setState(() {
        _leaderboard = leaderboard;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _shareInvite() {
    _groupService.shareGroupInvite(
      widget.group.inviteCode,
      widget.group.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.grey100,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : _buildContent(context, isDark),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: AppSpacing.md),
          PillButton(
            label: 'Retry',
            expand: false,
            variant: PillVariant.outline,
            onPressed: _loadLeaderboard,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final leaderboard = _leaderboard!;

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),
            // Back button and header
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leaderboard.group.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${leaderboard.group.memberCount} members',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.grey500,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Invite button
            PillButton(
              label: 'Invite Friends',
              icon: Icons.share,
              variant: PillVariant.lime,
              onPressed: _shareInvite,
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Today's leaderboard
            Text(
              "Today's Progress",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            SoftCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  // Header row
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 3,
                          child: Text('Member',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppColors.grey500)),
                        ),
                        _headerCell('Food'),
                        _headerCell('Pushup'),
                        _headerCell('Protein'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...leaderboard.members.map(
                    (member) => _buildDailyRow(member),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Weekly leaderboard
            Text(
              'Weekly Leaderboard',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${leaderboard.weekStart} - ${leaderboard.weekEnd}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.grey500,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...List.generate(leaderboard.members.length, (index) {
              final member = leaderboard.members[index];
              return _buildWeeklyRow(context, index + 1, member, isDark);
            }),
            const SizedBox(height: AppSpacing.xxl),

            // Invite code display
            SoftCard(
              child: Column(
                children: [
                  Text(
                    'Invite Code',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey500,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    leaderboard.group.inviteCode,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Share this code with friends to let them join.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey500,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String label) {
    return SizedBox(
      width: 56,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          color: AppColors.grey500,
        ),
      ),
    );
  }

  Widget _buildDailyRow(GroupMemberScore member) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              member.userName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _statusIcon(member.foodLogged),
          _statusIcon(member.pushupsDone),
          _statusIcon(member.proteinHit),
        ],
      ),
    );
  }

  Widget _statusIcon(bool completed) {
    return SizedBox(
      width: 56,
      child: Icon(
        completed ? Icons.check_circle : Icons.circle_outlined,
        color: completed ? AppColors.success : AppColors.grey300,
        size: 20,
      ),
    );
  }

  Widget _buildWeeklyRow(
      BuildContext context, int rank, GroupMemberScore member, bool isDark) {
    Color? rankColor;
    if (rank == 1) rankColor = AppColors.limeBright;
    if (rank == 2) rankColor = AppColors.grey300;
    if (rank == 3) rankColor = AppColors.burned;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rankColor?.withOpacity(0.2) ??
                    (isDark ? AppColors.darkBorder : AppColors.grey100),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: rankColor ?? AppColors.grey500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                member.userName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${member.weeklyTotal} pts',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: rank == 1 ? AppColors.limeDeep : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
