import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle of a fine under the manual UPI settlement flow.
///
///   pending   → server created it (push-ups missed); nothing submitted yet
///   submitted → user sent UTR + screenshot; awaiting admin review
///   approved  → admin verified the payment; unlock granted as "paid bypass"
///   rejected  → admin rejected the proof; user may resubmit
///
/// The client is only ever permitted to move `pending`/`rejected` → `submitted`.
/// Only an admin (server-verified custom claim) may set `approved`/`rejected`.
enum FineStatus { pending, submitted, approved, rejected }

extension FineStatusX on FineStatus {
  /// Does the user still owe an action?
  bool get isOutstanding =>
      this == FineStatus.pending || this == FineStatus.rejected;

  bool get isAwaitingReview => this == FineStatus.submitted;

  bool get isSettled => this == FineStatus.approved;

  String get label => switch (this) {
        FineStatus.pending => 'Unpaid',
        FineStatus.submitted => 'Under review',
        FineStatus.approved => 'Paid',
        FineStatus.rejected => 'Rejected',
      };
}

class FineModel {
  const FineModel({
    required this.id,
    required this.uid,
    required this.amount,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.upiUtr,
    this.screenshotUrl,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNote,
  });

  final String id;

  /// Denormalised owner id so admins can run a `collectionGroup` query
  /// across every user's fines without needing to know the parent path.
  final String uid;

  /// Stored in paise to avoid floating-point money bugs.
  final int amount;

  final String reason;
  final FineStatus status;
  final DateTime createdAt;

  /// UPI reference / UTR number typed in by the user.
  final String? upiUtr;

  /// Cloud Storage URL of the payment screenshot.
  final String? screenshotUrl;

  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// Admin uid that actioned the review.
  final String? reviewedBy;

  /// Admin's note — the rejection reason, typically.
  final String? reviewNote;

  double get amountInRupees => amount / 100;

  String get amountLabel => '₹${amountInRupees.toStringAsFixed(0)}';

  factory FineModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // `uid` may be absent on legacy docs — recover it from the document path
    // (users/{uid}/fines/{fineId}).
    final pathUid = doc.reference.parent.parent?.id;

    return FineModel(
      id: doc.id,
      uid: (data['uid'] as String?) ?? pathUid ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      reason: data['reason'] as String? ?? 'pushup_skipped',
      status: FineStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => FineStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      upiUtr: data['upiUtr'] as String?,
      screenshotUrl: data['screenshotUrl'] as String?,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      reviewNote: data['reviewNote'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'amount': amount,
      'reason': reason,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'upiUtr': upiUtr,
      'screenshotUrl': screenshotUrl,
      'submittedAt':
          submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'reviewedAt':
          reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
      'reviewNote': reviewNote,
    };
  }

  /// Human-readable reason.
  String get reasonLabel => switch (reason) {
        'pushup_skipped' => 'Push-ups skipped',
        'emergency_unlock_abuse' => 'Emergency unlock overuse',
        _ => reason,
      };
}
