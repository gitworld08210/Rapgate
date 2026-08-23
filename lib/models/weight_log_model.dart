class WeightLogModel {
  final String id;
  final double weightKg;
  final DateTime loggedAt;

  WeightLogModel({required this.id, required this.weightKg, required this.loggedAt});

  factory WeightLogModel.fromMap(String id, Map<String, dynamic> data) => WeightLogModel(
        id: id,
        weightKg: (data['weight_kg'] as num?)?.toDouble() ?? 0,
        loggedAt: DateTime.tryParse(data['logged_at']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'weight_kg': weightKg,
        'logged_at': loggedAt.toIso8601String(),
      };
}
