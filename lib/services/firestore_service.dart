import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/food_log_model.dart';
import '../models/water_log_model.dart';
import '../models/weight_log_model.dart';
import '../models/pushup_session_model.dart';
import '../models/blocked_apps_config_model.dart';
import '../models/streak_model.dart';
import '../models/fine_model.dart';
import '../models/emergency_unlock_model.dart';
import '../utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==================== USER ====================

  /// Get user document reference
  DocumentReference _userDoc(String uid) =>
      _db.collection(AppConstants.usersCollection).doc(uid);

  /// Create or update user profile
  Future<void> setUserProfile(UserModel user) async {
    await _userDoc(user.uid).set(user.toFirestore(), SetOptions(merge: true));
  }

  /// Get user profile
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _userDoc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Stream user profile
  Stream<UserModel?> streamUserProfile(String uid) {
    return _userDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  // ==================== FOOD LOGS ====================

  CollectionReference _foodLogsCol(String uid) =>
      _userDoc(uid).collection(AppConstants.foodLogsSubcollection);

  /// Add food log
  Future<DocumentReference> addFoodLog(String uid, FoodLogModel log) async {
    return await _foodLogsCol(uid).add(log.toFirestore());
  }

  /// Get food logs for a specific date
  Stream<List<FoodLogModel>> streamFoodLogsForDate(
      String uid, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _foodLogsCol(uid)
        .where('loggedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('loggedAt', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('loggedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FoodLogModel.fromFirestore(doc))
            .toList());
  }

  /// Get food logs for a date range (for reports)
  Future<List<FoodLogModel>> getFoodLogsForRange(
      String uid, DateTime start, DateTime end) async {
    final snapshot = await _foodLogsCol(uid)
        .where('loggedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('loggedAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('loggedAt', descending: true)
        // A month of logs is bounded in practice, but cap it so a runaway
        // account can never pull an unbounded result set.
        .limit(400)
        .get();
    return snapshot.docs
        .map((doc) => FoodLogModel.fromFirestore(doc))
        .toList();
  }

  /// Delete food log
  Future<void> deleteFoodLog(String uid, String logId) async {
    await _foodLogsCol(uid).doc(logId).delete();
  }

  // ==================== WATER LOGS ====================

  CollectionReference _waterLogsCol(String uid) =>
      _userDoc(uid).collection(AppConstants.waterLogsSubcollection);

  /// Add water log
  Future<DocumentReference> addWaterLog(String uid, WaterLogModel log) async {
    return await _waterLogsCol(uid).add(log.toFirestore());
  }

  /// Get water logs for today
  Stream<List<WaterLogModel>> streamWaterLogsForDate(
      String uid, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _waterLogsCol(uid)
        .where('loggedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('loggedAt', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('loggedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WaterLogModel.fromFirestore(doc))
            .toList());
  }

  /// Delete water log
  Future<void> deleteWaterLog(String uid, String logId) async {
    await _waterLogsCol(uid).doc(logId).delete();
  }

  // ==================== WEIGHT LOGS ====================

  CollectionReference _weightLogsCol(String uid) =>
      _userDoc(uid).collection(AppConstants.weightLogsSubcollection);

  /// Add weight log
  Future<DocumentReference> addWeightLog(
      String uid, WeightLogModel log) async {
    return await _weightLogsCol(uid).add(log.toFirestore());
  }

  /// Get weight logs (last N entries)
  Stream<List<WeightLogModel>> streamWeightLogs(String uid,
      {int limit = 30}) {
    return _weightLogsCol(uid)
        .orderBy('loggedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WeightLogModel.fromFirestore(doc))
            .toList());
  }

  /// Get all weight logs for range
  Future<List<WeightLogModel>> getWeightLogsForRange(
      String uid, DateTime start, DateTime end) async {
    final snapshot = await _weightLogsCol(uid)
        .where('loggedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('loggedAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('loggedAt')
        .limit(400)
        .get();
    return snapshot.docs
        .map((doc) => WeightLogModel.fromFirestore(doc))
        .toList();
  }

  // ==================== PUSHUP SESSIONS ====================

  CollectionReference _pushupSessionsCol(String uid) =>
      _userDoc(uid).collection(AppConstants.pushupSessionsSubcollection);

  /// Stream latest pushup session (to check unlock status)
  Stream<PushupSessionModel?> streamLatestPushupSession(String uid) {
    return _pushupSessionsCol(uid)
        .where('status', isEqualTo: 'verified')
        .orderBy('completedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return PushupSessionModel.fromFirestore(snapshot.docs.first);
    });
  }

  /// Get pushup sessions for date range
  Future<List<PushupSessionModel>> getPushupSessionsForRange(
      String uid, DateTime start, DateTime end) async {
    final snapshot = await _pushupSessionsCol(uid)
        .where('startedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startedAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('startedAt', descending: true)
        .limit(200)
        .get();
    return snapshot.docs
        .map((doc) => PushupSessionModel.fromFirestore(doc))
        .toList();
  }

  // ==================== BLOCKED APPS CONFIG ====================

  DocumentReference _blockedAppsConfigDoc(String uid) =>
      _userDoc(uid).collection('config').doc(AppConstants.blockedAppsConfigDoc);

  /// Get blocked apps config
  Future<BlockedAppsConfigModel?> getBlockedAppsConfig(String uid) async {
    final doc = await _blockedAppsConfigDoc(uid).get();
    if (!doc.exists) return null;
    return BlockedAppsConfigModel.fromFirestore(doc);
  }

  /// Stream blocked apps config
  Stream<BlockedAppsConfigModel?> streamBlockedAppsConfig(String uid) {
    return _blockedAppsConfigDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BlockedAppsConfigModel.fromFirestore(doc);
    });
  }

  /// Update blocked apps config
  Future<void> updateBlockedAppsConfig(
      String uid, BlockedAppsConfigModel config) async {
    await _blockedAppsConfigDoc(uid)
        .set(config.toFirestore(), SetOptions(merge: true));
  }

  // ==================== STREAKS ====================

  DocumentReference _streaksDoc(String uid) =>
      _userDoc(uid).collection('meta').doc(AppConstants.streaksDoc);

  /// Stream streaks
  Stream<StreakModel?> streamStreaks(String uid) {
    return _streaksDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return StreakModel.fromFirestore(doc);
    });
  }

  /// Get streaks
  Future<StreakModel?> getStreaks(String uid) async {
    final doc = await _streaksDoc(uid).get();
    if (!doc.exists) return null;
    return StreakModel.fromFirestore(doc);
  }

  // ==================== FINES ====================

  CollectionReference _finesCol(String uid) =>
      _userDoc(uid).collection(AppConstants.finesSubcollection);

  /// Fines the user still owes something on.
  ///
  /// Includes `rejected` as well as `pending`: a rejected payment means the
  /// fine was never settled, so it is still outstanding and resubmittable.
  /// `submitted` is excluded — the user has done their part and is waiting.
  Stream<List<FineModel>> streamOutstandingFines(String uid) {
    return _finesCol(uid)
        .where('status', whereIn: [
          FineStatus.pending.name,
          FineStatus.rejected.name,
        ])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FineModel.fromFirestore(doc)).toList());
  }

  /// Get all fines
  Future<List<FineModel>> getAllFines(String uid) async {
    final snapshot = await _finesCol(uid)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
    return snapshot.docs
        .map((doc) => FineModel.fromFirestore(doc))
        .toList();
  }

  // ==================== EMERGENCY UNLOCKS ====================

  CollectionReference _emergencyUnlocksCol(String uid) =>
      _userDoc(uid).collection(AppConstants.emergencyUnlocksSubcollection);

  /// Get emergency unlocks this week
  Future<int> getEmergencyUnlocksThisWeek(String uid) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekMidnight =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final snapshot = await _emergencyUnlocksCol(uid)
        .where('usedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekMidnight))
        .get();
    return snapshot.docs.length;
  }

  /// Add emergency unlock
  Future<void> addEmergencyUnlock(
      String uid, EmergencyUnlockModel unlock) async {
    await _emergencyUnlocksCol(uid).add(unlock.toFirestore());
  }
}
