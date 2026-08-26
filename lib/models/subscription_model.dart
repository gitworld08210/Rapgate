/// Subscription tier levels for RepGate Pro.
enum SubscriptionTier { free, pro, elite }

extension SubscriptionTierX on SubscriptionTier {
  String get label => switch (this) {
        SubscriptionTier.free => 'Free',
        SubscriptionTier.pro => 'Pro',
        SubscriptionTier.elite => 'Elite',
      };

  bool get isPaid => this != SubscriptionTier.free;
}

/// Represents a user's subscription status.
class SubscriptionModel {
  const SubscriptionModel({
    required this.uid,
    required this.tier,
    this.expiresAt,
    this.createdAt,
  });

  final String uid;
  final SubscriptionTier tier;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  /// Whether the subscription is currently active (not expired).
  bool get isActive {
    if (tier == SubscriptionTier.free) return false;
    if (expiresAt == null) return false;
    return expiresAt!.isAfter(DateTime.now());
  }

  factory SubscriptionModel.fromMap(Map<String, dynamic> data) {
    return SubscriptionModel(
      uid: data['user_id'] as String? ?? '',
      tier: SubscriptionTier.values.firstWhere(
        (e) => e.name == data['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      expiresAt: DateTime.tryParse(data['expires_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': uid,
        'tier': tier.name,
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
