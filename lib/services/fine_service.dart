import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/fine_model.dart';
import '../utils/constants.dart';

/// Manual UPI fine settlement.
///
/// Trust boundary:
///  * The USER may only attach proof of payment (UTR and/or screenshot) and
///    move a fine from `pending`/`rejected` → `submitted`.
///  * Only an ADMIN may approve or reject. That decision is made by a Cloud
///    Function which re-verifies the caller's admin custom claim server-side,
///    so a tampered client cannot self-approve.
class FineService {
  FineService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  final ImagePicker _picker = ImagePicker();

  // ==================== ADMIN IDENTITY ====================

  /// Whether the signed-in user holds the `admin` custom claim.
  ///
  /// This is only used to decide what UI to show. Every privileged action is
  /// re-checked server-side, so a spoofed `true` here grants nothing.
  Future<bool> isCurrentUserAdmin({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final token = await user.getIdTokenResult(forceRefresh);
      return token.claims?['admin'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Bootstraps the admin claim for an allowlisted email (see functions/src).
  /// Safe to call repeatedly; it is a no-op for non-allowlisted accounts.
  Future<bool> claimAdminRole() async {
    try {
      final result =
          await _functions.httpsCallable(AppConstants.cfClaimAdminRole).call();
      final granted = (result.data as Map?)?['granted'] == true;
      if (granted) {
        // Force a token refresh so the new claim is visible immediately.
        await _auth.currentUser?.getIdToken(true);
      }
      return granted;
    } on FirebaseFunctionsException catch (e) {
      throw FineException(e.message ?? 'Could not verify admin role.');
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

  /// Uploads the screenshot and returns its download URL.
  ///
  /// Path is namespaced per-user so Storage rules can scope write access,
  /// while still allowing admins to read it during review.
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

    final ref = _storage.ref('users/$uid/fine_proofs/$fineId.jpg');
    final task = await ref.putFile(
      File(file.path),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
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
  /// Delegated to a Cloud Function so the status transition and the
  /// `submittedAt` timestamp are written with server authority.
  Future<void> submitPaymentProof({
    required String fineId,
    String? utr,
    XFile? screenshot,
  }) async {
    final uid = _auth.currentUser?.uid;
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

    String? screenshotUrl;
    if (screenshot != null) {
      screenshotUrl = await uploadScreenshot(
        uid: uid,
        fineId: fineId,
        file: screenshot,
      );
    }

    try {
      await _functions.httpsCallable(AppConstants.cfSubmitFineProof).call({
        'fineId': fineId,
        if (hasUtr) 'upiUtr': cleanUtr,
        if (screenshotUrl != null) 'screenshotUrl': screenshotUrl,
      });
    } on FirebaseFunctionsException catch (e) {
      throw FineException(e.message ?? 'Could not submit your payment proof.');
    }
  }

  // ==================== USER: READ OWN FINES ====================

  CollectionReference<Map<String, dynamic>> _finesCol(String uid) => _db
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.finesSubcollection);

  /// All of a user's fines, newest first.
  Stream<List<FineModel>> streamMyFines(String uid) {
    return _finesCol(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FineModel.fromFirestore).toList());
  }

  /// Fines that still need the user to do something (unpaid or rejected).
  Stream<List<FineModel>> streamOutstandingFines(String uid) {
    return _finesCol(uid)
        .where('status', whereIn: [
          FineStatus.pending.name,
          FineStatus.rejected.name,
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FineModel.fromFirestore).toList());
  }

  Future<FineModel?> getFine(String uid, String fineId) async {
    final doc = await _finesCol(uid).doc(fineId).get();
    if (!doc.exists) return null;
    return FineModel.fromFirestore(doc);
  }

  // ==================== ADMIN: REVIEW QUEUE ====================

  /// Every fine awaiting review, across all users.
  ///
  /// Uses a `collectionGroup` query over `fines`, which is why each fine
  /// document denormalises its owner `uid`. Requires the composite index
  /// declared in firestore.indexes.json and is gated to admins by rules.
  Stream<List<FineModel>> streamReviewQueue() {
    return _db
        .collectionGroup(AppConstants.finesSubcollection)
        .where('status', isEqualTo: FineStatus.submitted.name)
        .orderBy('submittedAt')
        .snapshots()
        .map((s) => s.docs.map(FineModel.fromFirestore).toList());
  }

  /// Recently reviewed fines, so the admin can audit or undo a mistake.
  Stream<List<FineModel>> streamRecentlyReviewed({int limit = 50}) {
    return _db
        .collectionGroup(AppConstants.finesSubcollection)
        .where('status', whereIn: [
          FineStatus.approved.name,
          FineStatus.rejected.name,
        ])
        .orderBy('reviewedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(FineModel.fromFirestore).toList());
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
      await _functions.httpsCallable(AppConstants.cfReviewFine).call({
        'targetUid': targetUid,
        'fineId': fineId,
        'approve': approve,
        if (note != null && note.isNotEmpty) 'note': note,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        throw FineException('You are not authorised to review fines.');
      }
      throw FineException(e.message ?? 'Could not record your decision.');
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
