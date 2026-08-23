class GroupModel {
  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final int maxMembers;
  final DateTime createdAt;
  final int memberCount;

  GroupModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.maxMembers,
    required this.createdAt,
    this.memberCount = 0,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) => GroupModel(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        inviteCode: map['invite_code'] as String? ?? '',
        createdBy: map['created_by'] as String? ?? '',
        maxMembers: (map['max_members'] as num?)?.toInt() ?? 10,
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
        memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
      );
}

class GroupMemberScore {
  final String userId;
  final String userName;
  final bool foodLogged;
  final bool pushupsDone;
  final bool proteinHit;
  final int totalPoints;
  final int weeklyTotal;

  GroupMemberScore({
    required this.userId,
    required this.userName,
    required this.foodLogged,
    required this.pushupsDone,
    required this.proteinHit,
    required this.totalPoints,
    required this.weeklyTotal,
  });

  factory GroupMemberScore.fromMap(Map<String, dynamic> map) =>
      GroupMemberScore(
        userId: map['user_id'] as String? ?? '',
        userName: map['user_name'] as String? ?? 'Unknown',
        foodLogged: map['food_logged'] as bool? ?? false,
        pushupsDone: map['pushups_done'] as bool? ?? false,
        proteinHit: map['protein_hit'] as bool? ?? false,
        totalPoints: (map['total_points'] as num?)?.toInt() ?? 0,
        weeklyTotal: (map['weekly_total'] as num?)?.toInt() ?? 0,
      );
}

class GroupLeaderboard {
  final GroupModel group;
  final List<GroupMemberScore> members;
  final String weekStart;
  final String weekEnd;
  final String today;

  GroupLeaderboard({
    required this.group,
    required this.members,
    required this.weekStart,
    required this.weekEnd,
    required this.today,
  });

  factory GroupLeaderboard.fromMap(Map<String, dynamic> map) {
    final groupData = map['group'] as Map<String, dynamic>? ?? {};
    final membersData = map['members'] as List? ?? [];

    return GroupLeaderboard(
      group: GroupModel.fromMap(groupData),
      members: membersData
          .map((m) => GroupMemberScore.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      weekStart: map['week_start'] as String? ?? '',
      weekEnd: map['week_end'] as String? ?? '',
      today: map['today'] as String? ?? '',
    );
  }
}
