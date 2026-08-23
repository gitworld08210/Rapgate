class AchievementModel {
  final String id;
  final String badgeKey;
  final DateTime earnedAt;
  final Map<String, dynamic> metadata;

  AchievementModel({
    required this.id,
    required this.badgeKey,
    required this.earnedAt,
    this.metadata = const {},
  });

  factory AchievementModel.fromMap(String id, Map<String, dynamic> data) =>
      AchievementModel(
        id: id,
        badgeKey: data['badge_key'] as String? ?? '',
        earnedAt: DateTime.tryParse(data['earned_at']?.toString() ?? '') ??
            DateTime.now(),
        metadata: (data['metadata'] as Map<String, dynamic>?) ?? const {},
      );

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'badge_key': badgeKey,
        'metadata': metadata,
      };

  String get badgeName =>
      metadata['name'] as String? ?? badgeKey.replaceAll('_', ' ');

  String get badgeDescription =>
      metadata['description'] as String? ?? '';
}
