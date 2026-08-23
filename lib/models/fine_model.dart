/// Lifecycle of a fine under the manual UPI settlement flow.
///
///   pending   → server created it (push-ups missed); nothing submitted yet
///   submitted → user sent UTR + screenshot; awaiting admin review
///   approved  → admin verified the payment; unlock granted as "paid bypass"
///   rejected  → admin rejected the proof; user may resubmit
///
/// The client is only ever permitted to move `pending`/`rejected` → `submitted`.
/// Only an admin (server-verified via the `admin_roles` table) may set
/// `approved`/`rejected` — enforced by a Postgres trigger plus the
/// `review-fine` Edge Function's service-role write.
enum FineStatus { pending, submitted, approved, rejected }

extension FineStatusX on FineStatus {
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

  /// Owning user id (`fines.user_id`).
  final String uid;

  /// Stored in paise to avoid floating-point money bugs.
  final int amount;

  final String reason;
  final FineStatus status;
  final DateTime createdAt;

  /// UPI reference / UTR number typed in by the user.
  final String? upiUtr;

  /// Signed Supabase Storage URL of the payment screenshot, resolved by
  /// [FineService] from the stored `screenshot_path`.
  final String? screenshotUrl;

  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// Admin uid that actioned the review.
  final String? reviewedBy;

  /// Admin's note — the rejection reason, typically.
  final String? reviewNote;

  double get amountInRupees => amount / 100;

  String get amountLabel => '₹${amountInRupees.toStringAsFixed(0)}';

  factory FineModel.fromMap(Map<String, dynamic> data) {
    return FineModel(
      id: data['id'] as String,
      uid: data['user_id'] as String? ?? '',
      amount: (data['amount_paise'] as num?)?.toInt() ?? 0,
      reason: data['reason'] as String? ?? 'pushup_skipped',
      status: FineStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => FineStatus.pending,
      ),
      createdAt:
          DateTime.tryParse(data['created_at']?.toString() ?? '') ??
              DateTime.now(),
      upiUtr: data['upi_utr'] as String?,
      // `screenshot_path` is resolved to a signed URL by FineService before
      // this model is constructed; both keys are accepted for convenience.
      screenshotUrl:
          data['screenshot_url'] as String? ?? data['screenshot_path'] as String?,
      submittedAt: DateTime.tryParse(data['submitted_at']?.toString() ?? ''),
      reviewedAt: DateTime.tryParse(data['reviewed_at']?.toString() ?? ''),
      reviewedBy: data['reviewed_by'] as String?,
      reviewNote: data['review_note'] as String?,
    );
  }

  FineModel copyWithScreenshotUrl(String? url) => FineModel(
        id: id,
        uid: uid,
        amount: amount,
        reason: reason,
        status: status,
        createdAt: createdAt,
        upiUtr: upiUtr,
        screenshotUrl: url,
        submittedAt: submittedAt,
        reviewedAt: reviewedAt,
        reviewedBy: reviewedBy,
        reviewNote: reviewNote,
      );

  /// Human-readable reason.
  String get reasonLabel => switch (reason) {
        'pushup_skipped' => 'Push-ups skipped',
        'emergency_unlock_abuse' => 'Emergency unlock overuse',
        _ => reason,
      };
}
