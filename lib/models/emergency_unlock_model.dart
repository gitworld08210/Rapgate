import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyUnlockModel {
  final String id;
  final DateTime usedAt;
  final String? reason;

  EmergencyUnlockModel({
    required this.id,
    required this.usedAt,
    this.reason,
  });

  factory EmergencyUnlockModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyUnlockModel(
      id: doc.id,
      usedAt: (data['usedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: data['reason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'usedAt': Timestamp.fromDate(usedAt),
      'reason': reason,
    };
  }
}
