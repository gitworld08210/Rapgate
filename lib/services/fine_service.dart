import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../models/fine_model.dart';
import '../utils/constants.dart';

/// Manual UPI fine settlement.
///
/// Trust boundary:
///  * The USER may only attach proof of payment (UTR and/or screenshot) and
///    move a fine from `pending`/`rejected` → `submitted`.
///  * Only an ADMIN may approve or reject. That decision is made by the
///    `review-fine` Edge Function, which re-verifies the caller's admin role
///    server-side (via the `admin_roles` table + email allowlist), so a
///    tampered client cannot self-approve.
class FineService {
  FineService({SupabaseClient? client}) : _db = client ?? supabase;

  final SupabaseClient _db;

  final ImagePicker _picker = ImagePicker();

  static const _bucket = 'fine-proofs';

  // ==================== ADMIN IDENTITY ====================

  /// Whether the signed-in user holds server-side admin access.
  ///
  /// This is only used to decide what UI to show. Every privileged action is
  /// re-checked server-side, so a spoofed `true` here grants nothing.
  Future<bool> isCurrentUserAdmin({bool forceRefresh = false}) async {
    final user = _db.auth.currentUser;
    if (user == null) return false;
    try {
      if (forceRefresh) {
        await _db.auth.refreshSession();
      }
      final row = await _db
          .from('admin_roles')
          .select('user_id')
          .eq('user_id', user.id)
          .isFilter('revoked_at', null)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// Bootstraps admin access for an allowlisted email (see supabase/functions).
  /// Safe to call repeatedly; it is a no-op for non-allowlisted accounts.
  Future<bool> claimAdminRole() async {
    try {
      final response = await _db.functions.invoke('claim-admin-role');
      if (response.status >= 400) {
        throw FineException(
          (response.data as Map?)?['error']?.toString() ??
              'Could not verify admin role.',
        );
      }
      return (response.data as Map?)?['granted'] == true;
    } on FineException {
      rethrow;
    } catch (e) {
      throw FineException('Could not verify admin role: $e');
    }
  }

  // ==================== USER: SUBMIT PROOF ====================

  /// Pick a payment screenshot from the gallery.
  Future<XFile?> pickScreenshot() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
  }

  /// Uploads the screenshot to the private `fine-proofs` bucket and returns
  /// its storage path (not a URL — the bucket is private, so admins resolve
  /// a signed URL at read time).
  Future<String> uploadScreenshot({
    required String uid,
    required String fineId,
    required XFile file,
  }) async {
    final length = await file.length();
    if (length > AppConstants.maxScreenshotBytes) {
      throw FineException(
        'Screenshot is too large. Please use an image under '
        '${AppConstants.maxScreenshotBytes ~/ (1024 * 1024)} MB.',
      );
    }

    final path = '$uid/fine_proofs/$fineId.jpg';
    await _db.storage.from(_bucket).upload(
          path,
          File(file.path),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return path;
  }

  /// Validates the UTR the user typed in.
  ///
  /// Returns null when valid, otherwise a message to show inline.
  static String? validateUtr(String? raw) {
    final utr = raw?.trim() ?? '';
    if (utr.isEmpty) return null; // optional when a screenshot is attached
    if (utr.length < AppConstants.utrMinLength) {
      return 'UTR looks too short — check your payment app.';
    }
    if (utr.length > AppConstants.utrMaxLength) {
      return 'UTR looks too long — check your payment app.';
    }
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(utr)) {
      return 'UTR should contain only letters and numbers.';
    }
    return null;
  }

  /// Submits proof of payment for review.
  ///
  /// At least one of [utr] or [screenshot] must be provided — the user may
  /// have only the reference number, or only a screenshot.
  ///
  /// Delegated to the `submit-fine-proof` Edge Function so the status
  /// transition and the `submitted_at` timestamp are written with service-role
  /// authority.
  Future<void> submitPaymentProof({
    required String fineId,
    String? utr,
    XFile? screenshot,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw FineException('You are not signed in.');

    final cleanUtr = utr?.trim();
    final hasUtr = cleanUtr != null && cleanUtr.isNotEmpty;

    if (!hasUtr && screenshot == null) {
      throw FineException(
        'Add the UTR number or a payment screenshot so it can be verified.',
      );
    }

    if (hasUtr) {
      final error = validateUtr(cleanUtr);
      if (error != null) throw FineException(error);
    }

    String? screenshotPath;
    if (screenshot != null) {
      screenshotPath = await uploadScreenshot(
        uid: uid,
        fineId: fineId,
        file: screenshot,
      );
    }

    try {
      final response = await _db.functions.invoke('submit-fine-proof', body: {
        'fineId': fineId,
        if (hasUtr) 'upiUtr': cleanUtr,
        if (screenshotPath != null) 'screenshotPath': screenshotPath,
      });
      if (response.status >= 400) {
        throw FineException(
          (response.data as Map?)?['error']?.toString() ??
              'Could not submit your payment proof.',
        );
      }
    } on FineException {
      rethrow;
    } catch (e) {
      throw FineException('Could not submit your payment proof: $e');
    }
  }

  // ==================== USER: READ OWN FINES ====================

  /// All of a user's fines, newest first.
  Stream<List<FineModel>> streamMyFines(String uid) {
    return _db
        .from('fines')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) => rows.map(FineModel.fromMap).toList());
  }

  /// Fines that still need the user to do something (unpaid or rejected).
  Stream<List<FineModel>> streamOutstandingFines(String uid) {
    return _db
        .from('fines')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => rows
            .where((row) =>
                row['status'] == 'pending' || row['status'] == 'rejected')
            .map(FineModel.fromMap)
            .toList());
  }

  Future<FineModel?> getFine(String uid, String fineId) async {
    final row = await _db
        .from('fines')
        .select()
        .eq('id', fineId)
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return FineModel.fromMap(row);
  }

  // ==================== ADMIN: REVIEW QUEUE ====================

  /// Every fine awaiting review, across all users.
  ///
  /// Row Level Security restricts this table read to the owner unless the
  /// caller holds admin access (checked via `has_admin_role` in the RLS
  /// policy), so a non-admin simply sees an empty stream.
  Stream<List<FineModel>> streamReviewQueue() {
    return _db
        .from('fines')
        .stream(primaryKey: ['id'])
        .order('submitted_at')
        .limit(100)
        .map((rows) => rows
            .where((row) => row['status'] == 'submitted')
            .map(FineModel.fromMap)
            .toList());
  }

  /// Recently reviewed fines, so the admin can audit or undo a mistake.
  Stream<List<FineModel>> streamRecentlyReviewed({int limit = 50}) {
    return _db
        .from('fines')
        .stream(primaryKey: ['id'])
        .order('reviewed_at', ascending: false)
        .limit(limit)
        .map((rows) => rows
            .where((row) =>
                row['status'] == 'approved' || row['status'] == 'rejected')
            .map(FineModel.fromMap)
            .toList());
  }

  /// Resolves a signed URL for a fine's screenshot, for display in the admin
  /// review UI. The bucket is private, so a raw path cannot be rendered
  /// directly with `Image.network`.
  Future<String?> resolveScreenshotUrl(FineModel fine) async {
    if (fine.screenshotUrl == null) return null;
    try {
      return await _db.storage
          .from(_bucket)
          .createSignedUrl(fine.screenshotUrl!, 60 * 30);
    } catch (_) {
      return null;
    }
  }

  /// Approve a fine: marks it paid and grants the 24h "paid bypass" unlock.
  Future<void> approveFine({
    required String targetUid,
    required String fineId,
    String? note,
  }) =>
      _review(
        targetUid: targetUid,
        fineId: fineId,
        approve: true,
        note: note,
      );

  /// Reject a fine: it stays unpaid and becomes resubmittable by the user.
  Future<void> rejectFine({
    required String targetUid,
    required String fineId,
    required String reason,
  }) {
    if (reason.trim().isEmpty) {
      throw FineException('Give a reason so the user knows what to fix.');
    }
    return _review(
      targetUid: targetUid,
      fineId: fineId,
      approve: false,
      note: reason.trim(),
    );
  }

  Future<void> _review({
    required String targetUid,
    required String fineId,
    required bool approve,
    String? note,
  }) async {
    try {
      final response = await _db.functions.invoke('review-fine', body: {
        'targetUid': targetUid,
        'fineId': fineId,
        'approve': approve,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      if (response.status == 403) {
        throw FineException('You are not authorised to review fines.');
      }
      if (response.status >= 400) {
        throw FineException(
          (response.data as Map?)?['error']?.toString() ??
              'Could not record your decision.',
        );
      }
    } on FineException {
      rethrow;
    } catch (e) {
      throw FineException('Could not record your decision: $e');
    }
  }
}

/// User-presentable failure from the fine flow.
class FineException implements Exception {
  const FineException(this.message);
  final String message;

  @override
  String toString() => message;
}
