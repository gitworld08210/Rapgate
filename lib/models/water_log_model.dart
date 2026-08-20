import 'package:cloud_firestore/cloud_firestore.dart';

class WaterLogModel {
  final String id;
  final int amountMl;
  final DateTime loggedAt;

  WaterLogModel({
    required this.id,
    required this.amountMl,
    required this.loggedAt,
  });

  factory WaterLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WaterLogModel(
      id: doc.id,
      amountMl: data['amountMl'] ?? 0,
      loggedAt: (data['loggedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amountMl': amountMl,
      'loggedAt': Timestamp.fromDate(loggedAt),
    };
  }
}
