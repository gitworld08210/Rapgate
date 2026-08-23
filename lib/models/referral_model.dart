class ReferralModel {
  final String id;
  final String referrerName;
  final String? refereeId;
  final String code;
  final String status;
  final DateTime createdAt;

  ReferralModel({
    required this.id,
    required this.referrerName,
    this.refereeId,
    required this.code,
    required this.status,
    required this.createdAt,
  });

  factory ReferralModel.fromMap(Map<String, dynamic> map) => ReferralModel(
        id: map['id'] as String? ?? '',
        referrerName: map['referrer_name'] as String? ?? '',
        refereeId: map['referee_id'] as String?,
        code: map['code'] as String? ?? '',
        status: map['status'] as String? ?? 'pending',
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'referrer_name': referrerName,
        'referee_id': refereeId,
        'code': code,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}

class LeaderboardEntry {
  final String userId;
  final String name;
  final int referralCount;

  LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.referralCount,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) =>
      LeaderboardEntry(
        userId: map['user_id'] as String? ?? '',
        name: map['name'] as String? ?? 'Anonymous',
        referralCount: (map['referral_count'] as num?)?.toInt() ?? 0,
      );
}

class ReferralStats {
  final String referralCode;
  final int totalReferrals;
  final List<LeaderboardEntry> leaderboard;

  ReferralStats({
    required this.referralCode,
    required this.totalReferrals,
    required this.leaderboard,
  });

  factory ReferralStats.fromMap(Map<String, dynamic> map) => ReferralStats(
        referralCode: map['referral_code'] as String? ?? '',
        totalReferrals: (map['total_referrals'] as num?)?.toInt() ?? 0,
        leaderboard: ((map['leaderboard'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => LeaderboardEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
