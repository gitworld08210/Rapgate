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
  bool get isUnlockActive =>
      unlockGrantedUntil != null && DateTime.now().isBefore(unlockGrantedUntil!);

  factory PushupSessionModel.fromMap(String id, Map<String, dynamic> data) => PushupSessionModel(
        id: id,
        status: PushupSessionStatus.values.firstWhere(
          (item) => item.name == data['status'],
          orElse: () => PushupSessionStatus.pending,
        ),
        repCount: (data['rep_count'] as num?)?.toInt() ?? 0,
        poseLandmarkSummary: data['pose_landmark_summary'] is Map
            ? Map<String, dynamic>.from(data['pose_landmark_summary'] as Map)
            : null,
        faceVisibleCheck: data['face_visible_check'] == true,
        angleValidCheck: data['angle_valid_check'] == true,
        startedAt: DateTime.tryParse(data['started_at']?.toString() ?? '') ?? DateTime.now(),
        completedAt: DateTime.tryParse(data['completed_at']?.toString() ?? ''),
        unlockGrantedUntil: DateTime.tryParse(data['unlock_granted_until']?.toString() ?? ''),
      );

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'status': status.name == 'failed' ? 'rejected' : status.name,
        'rep_count': repCount,
        'pose_landmark_summary': poseLandmarkSummary,
        'face_visible_check': faceVisibleCheck,
        'angle_valid_check': angleValidCheck,
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'unlock_granted_until': unlockGrantedUntil?.toIso8601String(),
      };
}
