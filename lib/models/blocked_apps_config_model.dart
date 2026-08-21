class BlockedAppsConfigModel {
  final List<String> blockedPackages;
  final List<String> allowlistPackages;
  final DateTime? lastUnlockedAt;
  final DateTime? unlockGrantedUntil;
  final String? unlockSource;

  BlockedAppsConfigModel({
    required this.blockedPackages,
    required this.allowlistPackages,
    this.lastUnlockedAt,
    this.unlockGrantedUntil,
    this.unlockSource,
  });

  bool isAppBlocked(String packageName) {
    return blockedPackages.contains(packageName) &&
        !allowlistPackages.contains(packageName);
  }

  /// Mirrors the server's unlock window rather than assuming a fixed 24h
  /// offset from `lastUnlockedAt` — the source of truth is
  /// `unlock_granted_until`, written only by Edge Functions.
  bool get isCurrentlyUnlocked {
    if (unlockGrantedUntil == null) return false;
    return DateTime.now().isBefore(unlockGrantedUntil!);
  }

  factory BlockedAppsConfigModel.fromMap(Map<String, dynamic> data) =>
      BlockedAppsConfigModel(
        blockedPackages: List<String>.from(data['blocked_packages'] ?? const []),
        allowlistPackages:
            List<String>.from(data['allowlist_packages'] ?? const []),
        lastUnlockedAt: DateTime.tryParse(data['last_unlocked_at']?.toString() ?? ''),
        unlockGrantedUntil:
            DateTime.tryParse(data['unlock_granted_until']?.toString() ?? ''),
        unlockSource: data['unlock_source'] as String?,
      );

  /// Only the two client-owned lists are ever sent — unlock fields are
  /// server-owned and rejected by a Postgres trigger if a client tries to
  /// set them directly.
  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'blocked_packages': blockedPackages,
        'allowlist_packages': allowlistPackages,
      };

  BlockedAppsConfigModel copyWith({
    List<String>? blockedPackages,
    List<String>? allowlistPackages,
    DateTime? lastUnlockedAt,
    DateTime? unlockGrantedUntil,
    String? unlockSource,
  }) {
    return BlockedAppsConfigModel(
      blockedPackages: blockedPackages ?? this.blockedPackages,
      allowlistPackages: allowlistPackages ?? this.allowlistPackages,
      lastUnlockedAt: lastUnlockedAt ?? this.lastUnlockedAt,
      unlockGrantedUntil: unlockGrantedUntil ?? this.unlockGrantedUntil,
      unlockSource: unlockSource ?? this.unlockSource,
    );
  }
}
