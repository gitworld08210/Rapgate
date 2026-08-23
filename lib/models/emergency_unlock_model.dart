class EmergencyUnlockModel {
  final String id;
  final DateTime usedAt;
  final String? reason;

  EmergencyUnlockModel({
    required this.id,
    required this.usedAt,
    this.reason,
  });

  factory EmergencyUnlockModel.fromMap(Map<String, dynamic> data) =>
      EmergencyUnlockModel(
        id: data['id'] as String,
        usedAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ??
            DateTime.now(),
        reason: data['reason'] as String?,
      );

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'reason': reason,
      };
}
