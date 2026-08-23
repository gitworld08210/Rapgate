/// Represents a single entry in the accountability leaderboard.
class LeaderboardEntry {
  final String userId;
  final String name;
  final int currentStreak;
  final int weeklyPushups;
  final int rank;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.currentStreak,
    required this.weeklyPushups,
    required this.rank,
    required this.isCurrentUser,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      userId: map['user_id'] as String? ?? '',
      name: map['display_name'] as String? ?? 'Anonymous',
      currentStreak: (map['current_streak'] as num?)?.toInt() ?? 0,
      weeklyPushups: (map['weekly_pushups'] as num?)?.toInt() ?? 0,
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      isCurrentUser: map['is_current_user'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'display_name': name,
      'current_streak': currentStreak,
      'weekly_pushups': weeklyPushups,
      'rank': rank,
      'is_current_user': isCurrentUser,
    };
  }
}
