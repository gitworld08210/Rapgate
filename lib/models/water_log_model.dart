class WaterLogModel {
  final String id;
  final int amountMl;
  final DateTime loggedAt;

  WaterLogModel({required this.id, required this.amountMl, required this.loggedAt});

  factory WaterLogModel.fromMap(String id, Map<String, dynamic> data) => WaterLogModel(
        id: id,
        amountMl: (data['amount_ml'] as num?)?.toInt() ?? 0,
        loggedAt: DateTime.tryParse(data['logged_at']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'amount_ml': amountMl,
        'logged_at': loggedAt.toIso8601String(),
      };
}
