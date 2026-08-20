import 'package:cloud_firestore/cloud_firestore.dart';

enum PushupSessionStatus { pending, verified, failed }

class PushupSessionModel {
  final String id;
  final PushupSessionStatus status;
  final int repCount;
  final Map<String, dynamic>? poseLandmarkSummary;
  final bool faceVisibleCheck;
  final bool angleValidCheck;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? unlockGrantedUntil;

  PushupSessionModel({
    required this.id,
    required this.status,
    this.repCount = 0,
    this.poseLandmarkSummary,
    this.faceVisibleCheck = false,
    this.angleValidCheck = false,
    required this.startedAt,
    this.completedAt,
    this.unlockGrantedUntil,
  });

  bool get isSessionComplete => status == PushupSessionStatus.verified;

  bool get isUnlockActive {
    if (unlockGrantedUntil == null) return false;
    return DateTime.now().isBefore(unlockGrantedUntil!);
  }

  factory PushupSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PushupSessionModel(
      id: doc.id,
      status: PushupSessionStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PushupSessionStatus.pending,
      ),
      repCount: data['repCount'] ?? 0,
      poseLandmarkSummary: data['poseLandmarkSummary'],
      faceVisibleCheck: data['faceVisibleCheck'] ?? false,
      angleValidCheck: data['angleValidCheck'] ?? false,
      startedAt:
          (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      unlockGrantedUntil:
          (data['unlockGrantedUntil'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'status': status.name,
      'repCount': repCount,
      'poseLandmarkSummary': poseLandmarkSummary,
      'faceVisibleCheck': faceVisibleCheck,
      'angleValidCheck': angleValidCheck,
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'unlockGrantedUntil': unlockGrantedUntil != null
          ? Timestamp.fromDate(unlockGrantedUntil!)
          : null,
    };
  }
}
