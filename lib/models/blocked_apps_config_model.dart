import 'package:cloud_firestore/cloud_firestore.dart';

class BlockedAppsConfigModel {
  final List<String> blockedPackages;
  final List<String> allowlistPackages;
  final DateTime? lastUnlockedAt;

  BlockedAppsConfigModel({
    required this.blockedPackages,
    required this.allowlistPackages,
    this.lastUnlockedAt,
  });

  bool isAppBlocked(String packageName) {
    return blockedPackages.contains(packageName) &&
        !allowlistPackages.contains(packageName);
  }

  bool get isCurrentlyUnlocked {
    if (lastUnlockedAt == null) return false;
    final unlockExpiry =
        lastUnlockedAt!.add(const Duration(hours: 24));
    return DateTime.now().isBefore(unlockExpiry);
  }

  factory BlockedAppsConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlockedAppsConfigModel(
      blockedPackages: List<String>.from(data['blockedPackages'] ?? []),
      allowlistPackages: List<String>.from(data['allowlistPackages'] ?? []),
      lastUnlockedAt:
          (data['lastUnlockedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'blockedPackages': blockedPackages,
      'allowlistPackages': allowlistPackages,
      'lastUnlockedAt': lastUnlockedAt != null
          ? Timestamp.fromDate(lastUnlockedAt!)
          : null,
    };
  }

  BlockedAppsConfigModel copyWith({
    List<String>? blockedPackages,
    List<String>? allowlistPackages,
    DateTime? lastUnlockedAt,
  }) {
    return BlockedAppsConfigModel(
      blockedPackages: blockedPackages ?? this.blockedPackages,
      allowlistPackages: allowlistPackages ?? this.allowlistPackages,
      lastUnlockedAt: lastUnlockedAt ?? this.lastUnlockedAt,
    );
  }
}
