import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../models/user_model.dart';
import '../models/food_log_model.dart';
import '../models/water_log_model.dart';
import '../models/weight_log_model.dart';
import '../models/pushup_session_model.dart';
import '../models/blocked_apps_config_model.dart';
import '../models/streak_model.dart';
import '../models/fine_model.dart';
import '../models/emergency_unlock_model.dart';

/// Postgres-backed replacement for the old Firestore-facing service.
///
/// Realtime streams use Supabase's Postgres Changes (`.stream()`), which
/// requires each table to have `REPLICA IDENTITY` publishing enabled (done
/// in the migration) and to be added to the `supabase_realtime` publication.
/// Every stream is scoped by `user_id`/`id`, mirroring the per-user Firestore
/// subcollections this replaces.
class FirestoreService {
  final SupabaseClient _db = supabase;

  // ==================== USER ====================

  Future<void> setUserProfile(UserModel user) async {
    await _db.from('users').upsert(user.toMap());
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final row = await _db.from('users').select().eq('id', uid).maybeSingle();
    if (row == null) return null;
    return UserModel.fromMap(uid, row);
  }

  Stream<UserModel?> streamUserProfile(String uid) {
    return _db
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) => rows.isEmpty ? null : UserModel.fromMap(uid, rows.first));
  }

  // ==================== FOOD LOGS ====================

  /// Persists a manually-entered or barcode food log directly.
  ///
  /// AI-scanned logs are written server-side by the `scan-food-image` Edge
  /// Function instead — see [FoodService.scanFoodImage] — so this path is
  /// only used for `manual` and `barcode` sources.
  Future<String> addFoodLog(String uid, FoodLogModel log) async {
    final row = await _db
        .from('food_logs')
        .insert(log.toMap(uid))
        .select('id')
        .single();
    return row['id'] as String;
  }

  Stream<List<FoodLogModel>> streamFoodLogsForDate(String uid, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .from('food_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('logged_at', ascending: false)
        .map((rows) => rows
            .where((row) {
              final loggedAt = DateTime.tryParse(row['logged_at']?.toString() ?? '');
              return loggedAt != null &&
                  !loggedAt.isBefore(startOfDay) &&
                  loggedAt.isBefore(endOfDay);
            })
            .map((row) => FoodLogModel.fromMap(row['id'] as String, row))
            .toList());
  }

  Future<List<FoodLogModel>> getFoodLogsForRange(
      String uid, DateTime start, DateTime end) async {
    final rows = await _db
        .from('food_logs')
        .select()
        .eq('user_id', uid)
        .gte('logged_at', start.toIso8601String())
        .lt('logged_at', end.toIso8601String())
        .order('logged_at', ascending: false)
        .limit(400);
    return rows
        .map<FoodLogModel>((row) => FoodLogModel.fromMap(row['id'] as String, row))
        .toList();
  }

  Future<void> deleteFoodLog(String uid, String logId) async {
    await _db.from('food_logs').delete().eq('id', logId).eq('user_id', uid);
  }

  // ==================== WATER LOGS ====================

  Future<String> addWaterLog(String uid, WaterLogModel log) async {
    final row = await _db
        .from('water_logs')
        .insert(log.toMap(uid))
        .select('id')
        .single();
    return row['id'] as String;
  }

  Stream<List<WaterLogModel>> streamWaterLogsForDate(String uid, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .from('water_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('logged_at', ascending: false)
        .map((rows) => rows
            .where((row) {
              final loggedAt = DateTime.tryParse(row['logged_at']?.toString() ?? '');
              return loggedAt != null &&
                  !loggedAt.isBefore(startOfDay) &&
                  loggedAt.isBefore(endOfDay);
            })
            .map((row) => WaterLogModel.fromMap(row['id'] as String, row))
            .toList());
  }

  Future<void> deleteWaterLog(String uid, String logId) async {
    await _db.from('water_logs').delete().eq('id', logId).eq('user_id', uid);
  }

  // ==================== WEIGHT LOGS ====================

  Future<String> addWeightLog(String uid, WeightLogModel log) async {
    final row = await _db
        .from('weight_logs')
        .insert(log.toMap(uid))
        .select('id')
        .single();
    return row['id'] as String;
  }

  Stream<List<WeightLogModel>> streamWeightLogs(String uid, {int limit = 30}) {
    return _db
        .from('weight_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('logged_at', ascending: false)
        .limit(limit)
        .map((rows) => rows
            .map((row) => WeightLogModel.fromMap(row['id'] as String, row))
            .toList());
  }

  Future<List<WeightLogModel>> getWeightLogsForRange(
      String uid, DateTime start, DateTime end) async {
    final rows = await _db
        .from('weight_logs')
        .select()
        .eq('user_id', uid)
        .gte('logged_at', start.toIso8601String())
        .lt('logged_at', end.toIso8601String())
        .order('logged_at')
        .limit(400);
    return rows
        .map<WeightLogModel>((row) => WeightLogModel.fromMap(row['id'] as String, row))
        .toList();
  }

  // ==================== PUSHUP SESSIONS ====================

  Stream<PushupSessionModel?> streamLatestPushupSession(String uid) {
    return _db
        .from('pushup_sessions')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('completed_at', ascending: false)
        .map((rows) {
          final verified = rows.where((row) => row['status'] == 'verified');
          if (verified.isEmpty) return null;
          final row = verified.first;
          return PushupSessionModel.fromMap(row['id'] as String, row);
        });
  }

  Future<List<PushupSessionModel>> getPushupSessionsForRange(
      String uid, DateTime start, DateTime end) async {
    final rows = await _db
        .from('pushup_sessions')
        .select()
        .eq('user_id', uid)
        .gte('started_at', start.toIso8601String())
        .lt('started_at', end.toIso8601String())
        .order('started_at', ascending: false)
        .limit(200);
    return rows
        .map<PushupSessionModel>(
            (row) => PushupSessionModel.fromMap(row['id'] as String, row))
        .toList();
  }

  // ==================== BLOCKED APPS CONFIG ====================

  Future<BlockedAppsConfigModel?> getBlockedAppsConfig(String uid) async {
    final row = await _db
        .from('blocked_apps_config')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return BlockedAppsConfigModel.fromMap(row);
  }

  Stream<BlockedAppsConfigModel?> streamBlockedAppsConfig(String uid) {
    return _db
        .from('blocked_apps_config')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .map((rows) =>
            rows.isEmpty ? null : BlockedAppsConfigModel.fromMap(rows.first));
  }

  /// Only writes the two client-owned lists. Unlock fields are rejected by a
  /// Postgres trigger if included, so they are intentionally omitted here.
  Future<void> updateBlockedAppsConfig(
      String uid, BlockedAppsConfigModel config) async {
    await _db.from('blocked_apps_config').upsert(config.toMap(uid));
  }

  // ==================== STREAKS ====================

  Stream<StreakModel?> streamStreaks(String uid) {
    return _db
        .from('streaks')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .map((rows) => rows.isEmpty ? null : StreakModel.fromMap(rows.first));
  }

  Future<StreakModel?> getStreaks(String uid) async {
    final row =
        await _db.from('streaks').select().eq('user_id', uid).maybeSingle();
    if (row == null) return null;
    return StreakModel.fromMap(row);
  }

  // ==================== FINES ====================

  /// Fines the user still owes something on (`pending` or `rejected`).
  Stream<List<FineModel>> streamOutstandingFines(String uid) {
    return _db
        .from('fines')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .where((row) =>
                row['status'] == 'pending' || row['status'] == 'rejected')
            .map(FineModel.fromMap)
            .toList());
  }

  Future<List<FineModel>> getAllFines(String uid) async {
    final rows = await _db
        .from('fines')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map<FineModel>(FineModel.fromMap).toList();
  }

  // ==================== EMERGENCY UNLOCKS ====================

  Future<int> getEmergencyUnlocksThisWeek(String uid) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekMidnight =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final rows = await _db
        .from('emergency_unlocks')
        .select('id')
        .eq('user_id', uid)
        .gte('created_at', startOfWeekMidnight.toIso8601String());
    return rows.length;
  }

  Future<void> addEmergencyUnlock(
      String uid, EmergencyUnlockModel unlock) async {
    await _db.from('emergency_unlocks').insert(unlock.toMap(uid));
  }
}
