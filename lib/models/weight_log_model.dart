import 'package:cloud_firestore/cloud_firestore.dart';

class WeightLogModel {
  final String id;
  final double weightKg;
  final DateTime loggedAt;

  WeightLogModel({
    required this.id,
    required this.weightKg,
    required this.loggedAt,
  });

  factory WeightLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WeightLogModel(
      id: doc.id,
      weightKg: (data['weightKg'] ?? 0.0).toDouble(),
      loggedAt: (data['loggedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'weightKg': weightKg,
      'loggedAt': Timestamp.fromDate(loggedAt),
    };
  }
}
