import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../models/group_model.dart';

class GroupService {
  final SupabaseClient _db = supabase;

  String _extractError(FunctionException error, String fallback) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return fallback;
  }

  /// Creates a new group with the given name.
  Future<GroupModel> createGroup(String name) async {
    try {
      final response = await _db.functions.invoke(
        'create-group',
        body: {'name': name.trim()},
      );

      if (response.status >= 400) {
        final data = response.data as Map?;
        throw Exception(
            data?['error']?.toString() ?? 'Failed to create group.');
      }

      final data = response.data as Map<String, dynamic>;
      return GroupModel.fromMap(data);
    } on FunctionException catch (e) {
      throw Exception(_extractError(e, 'Could not create group.'));
    }
  }

  /// Joins a group using an invite code.
  Future<GroupModel> joinGroup(String inviteCode) async {
    try {
      final response = await _db.functions.invoke(
        'join-group',
        body: {'invite_code': inviteCode.trim().toUpperCase()},
      );

      if (response.status >= 400) {
        final data = response.data as Map?;
        throw Exception(
            data?['error']?.toString() ?? 'Failed to join group.');
      }

      final data = response.data as Map<String, dynamic>;
      return GroupModel.fromMap(data);
    } on FunctionException catch (e) {
      throw Exception(_extractError(e, 'Could not join group.'));
    }
  }

  /// Gets all groups the current user is a member of.
  Future<List<GroupModel>> getMyGroups() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in.');

    final response = await _db
        .from('group_members')
        .select('group_id, groups(id, name, invite_code, max_members, created_by, created_at)')
        .eq('user_id', userId);

    final List<GroupModel> groups = [];
    for (final row in response as List) {
      final groupData = row['groups'] as Map<String, dynamic>?;
      if (groupData == null) continue;

      // Get member count for this group
      final countResponse = await _db
          .from('group_members')
          .select('id')
          .eq('group_id', groupData['id']);
      final memberCount = (countResponse as List).length;

      groups.add(GroupModel.fromMap({
        ...groupData,
        'member_count': memberCount,
      }));
    }

    return groups;
  }

  /// Gets the leaderboard for a specific group.
  Future<GroupLeaderboard> getGroupLeaderboard(String groupId) async {
    try {
      final response = await _db.functions.invoke(
        'get-group-leaderboard',
        body: {'group_id': groupId},
      );

      if (response.status >= 400) {
        final data = response.data as Map?;
        throw Exception(
            data?['error']?.toString() ?? 'Failed to load leaderboard.');
      }

      final data = response.data as Map<String, dynamic>;
      return GroupLeaderboard.fromMap(data);
    } on FunctionException catch (e) {
      throw Exception(_extractError(e, 'Could not load leaderboard.'));
    }
  }

  /// Shares a group invite link via the system share sheet.
  Future<void> shareGroupInvite(String inviteCode, String groupName) async {
    final message =
        'Join my group "$groupName" on RepGate!\n\n'
        'Use code: $inviteCode\n\n'
        'Track pushups, nutrition & compete together.\n'
        'Download: https://repgate.app/group/$inviteCode';
    await Share.share(message);
  }
}
