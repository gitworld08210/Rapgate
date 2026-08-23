import 'package:cloud_firestore/cloud_firestore.dart';

class BlockedAppsConfigModel {
  final List<String> blockedPackages;
  final List<String> allowlistPackages;
  final DateTime? lastUnlockedAt;
  final DateTime? unlockGrantedUntil;

  BlockedAppsConfigModel({
    required this.blockedPackages,
    required this.allowlistPackages,
    this.lastUnlockedAt,
    this.unlockGrantedUntil,
  });

  bool isAppBlocked(String packageName) {
    return blockedPackages.contains(packageName) &&
        !allowlistPackages.contains(packageName);
  }

  bool get isCurrentlyUnlocked {
    // Prefer the explicit unlockGrantedUntil written by the server (fine payment
    // or pushup verification) over the legacy 24h-from-lastUnlockedAt fallback.
    if (unlockGrantedUntil != null) {
      return DateTime.now().isBefore(unlockGrantedUntil!);
    }
    if (lastUnlockedAt == null) return false;
    final unlockExpiry =
        lastUnlockedAt!.add(const Duration(hours: 24));
    return DateTime.now().isBefore(unlockExpiry);
  }

  /// The time at which the current unlock expires, or null if not unlocked.
  DateTime? get unlockExpiry {
    if (unlockGrantedUntil != null &&
        DateTime.now().isBefore(unlockGrantedUntil!)) {
      return unlockGrantedUntil;
    }
    if (lastUnlockedAt != null) {
      final expiry = lastUnlockedAt!.add(const Duration(hours: 24));
      if (DateTime.now().isBefore(expiry)) return expiry;
    }
    return null;
  }

  factory BlockedAppsConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlockedAppsConfigModel(
      blockedPackages: List<String>.from(data['blockedPackages'] ?? []),
      allowlistPackages: List<String>.from(data['allowlistPackages'] ?? []),
      lastUnlockedAt:
          (data['lastUnlockedAt'] as Timestamp?)?.toDate(),
      unlockGrantedUntil:
          (data['unlockGrantedUntil'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'blockedPackages': blockedPackages,
      'allowlistPackages': allowlistPackages,
      'lastUnlockedAt': lastUnlockedAt != null
          ? Timestamp.fromDate(lastUnlockedAt!)
          : null,
      'unlockGrantedUntil': unlockGrantedUntil != null
          ? Timestamp.fromDate(unlockGrantedUntil!)
          : null,
    };
  }

  BlockedAppsConfigModel copyWith({
    List<String>? blockedPackages,
    List<String>? allowlistPackages,
    DateTime? lastUnlockedAt,
    DateTime? unlockGrantedUntil,
  }) {
    return BlockedAppsConfigModel(
      blockedPackages: blockedPackages ?? this.blockedPackages,
      allowlistPackages: allowlistPackages ?? this.allowlistPackages,
      lastUnlockedAt: lastUnlockedAt ?? this.lastUnlockedAt,
      unlockGrantedUntil: unlockGrantedUntil ?? this.unlockGrantedUntil,
    );
  }
}
