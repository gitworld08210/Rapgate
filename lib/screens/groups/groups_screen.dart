import 'package:flutter/material.dart';

import '../../models/group_model.dart';
import '../../services/group_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import 'group_detail_screen.dart';

/// Main groups screen: lists user's groups with create/join buttons.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final GroupService _groupService = GroupService();
  List<GroupModel> _groups = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await _groupService.getMyGroups();
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _showCreateDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: 'Group name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        await _groupService.createGroup(result.trim());
        _loadGroups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group created!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      }
    }
  }

  Future<void> _showJoinDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Enter invite code',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        await _groupService.joinGroup(result.trim());
        _loadGroups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Joined group successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.grey100,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Groups',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Compete with friends. Stay accountable.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey500,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Create Group',
                      icon: Icons.add,
                      variant: PillVariant.dark,
                      onPressed: _showCreateDialog,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PillButton(
                      label: 'Join Group',
                      icon: Icons.group_add,
                      variant: PillVariant.outline,
                      onPressed: _showJoinDialog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Groups list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!,
                                    style: TextStyle(color: AppColors.danger)),
                                const SizedBox(height: AppSpacing.md),
                                PillButton(
                                  label: 'Retry',
                                  expand: false,
                                  variant: PillVariant.outline,
                                  onPressed: _loadGroups,
                                ),
                              ],
                            ),
                          )
                        : _groups.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                onRefresh: _loadGroups,
                                child: ListView.separated(
                                  itemCount: _groups.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: AppSpacing.md),
                                  itemBuilder: (_, i) =>
                                      _buildGroupCard(_groups[i]),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_outlined,
              size: 64, color: AppColors.grey300),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No groups yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.grey500,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Create a group or join one with an invite code.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.grey500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(GroupModel group) {
    return SoftCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(group: group),
          ),
        ).then((_) => _loadGroups());
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.limeSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.groups, color: AppColors.limeDeep, size: 24),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${group.memberCount}/${group.maxMembers} members',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey500,
                      ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.grey300),
        ],
      ),
    );
  }
}
