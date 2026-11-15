import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Postgres-backed service with 100% offline Instant Guest/Demo mode support.
///
/// If `uid` starts with `guest_`, all reads/writes are stored locally in
/// `SharedPreferences`, completely bypassing network and backend limitations.
class FirestoreService {
  final SupabaseClient _db = supabase;

  // Guest event controllers for reactive local UI updates
  static final _guestUserStreamController =
      StreamController<UserModel?>.broadcast();
  static final _guestFoodLogsController =
      StreamController<List<FoodLogModel>>.broadcast();
  static final _guestWaterLogsController =
      StreamController<List<WaterLogModel>>.broadcast();

  bool _isGuest(String uid) => uid.startsWith('guest_');

  // ==================== USER ====================

  Future<void> setUserProfile(UserModel user) async {
    if (_isGuest(user.uid)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'guest_profile_${user.uid}', jsonEncode(user.toMap()));
      _guestUserStreamController.add(user);
      return;
    }
    await _db.from('users').upsert(user.toMap());
  }

  Future<UserModel?> getUserProfile(String uid) async {
    if (_isGuest(uid)) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('guest_profile_$uid');
      if (raw != null) {
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          return UserModel.fromMap(uid, data);
        } catch (_) {}
      }
      final defaultUser = UserModel(
        uid: uid,
        name: 'Guest Explorer',
        age: 24,
        weight: 70,
        height: 172,
        gender: 'male',
        dailyCalorieTarget: 2100,
        dailyProteinTarget: 120,
        pushupTarget: 15,
      );
      await setUserProfile(defaultUser);
      return defaultUser;
    }

    try {
      final row =
          await _db.from('users').select().eq('id', uid).maybeSingle();
      if (row == null) return null;
      return UserModel.fromMap(uid, row);
    } catch (_) {
      return null;
    }
  }

  Stream<UserModel?> streamUserProfile(String uid) async* {
    if (_isGuest(uid)) {
      final profile = await getUserProfile(uid);
      yield profile;
      yield* _guestUserStreamController.stream;
      return;
    }

    yield* _db.from('users').stream(primaryKey: ['id']).eq('id', uid).map(
        (rows) => rows.isEmpty ? null : UserModel.fromMap(uid, rows.first));
  }

  // ==================== FOOD LOGS ====================

  Future<String> addFoodLog(String uid, FoodLogModel log) async {
    if (_isGuest(uid)) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'guest_food_logs_$uid';
      final list = await _getRawGuestFoodLogs(uid);
      final newId = 'guest_food_${DateTime.now().millisecondsSinceEpoch}';
      final map = log.toMap(uid);
      map['id'] = newId;
      list.insert(0, map);
      await prefs.setString(key, jsonEncode(list));

      final allLogs = list
          .map((item) => FoodLogModel.fromMap(item['id'] as String, item))
          .toList();
      _guestFoodLogsController.add(allLogs);
      return newId;
    }

    final row = await _db
        .from('food_logs')
        .insert(log.toMap(uid))
        .select('id')
        .single();
    final logId = row['id'] as String;

    try {
      await _db.rpc('bump_food_streak', params: {'p_user_id': uid});
    } catch (_) {}

    return logId;
  }

  Future<List<Map<String, dynamic>>> _getRawGuestFoodLogs(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'guest_food_logs_$uid';
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    // Default sample food logs for an engaging first experience
    final sample = [
      {
        'id': 'sample_1',
        'user_id': uid,
        'image_path': null,
        'detected_items': [
          {
            'name': '2 Boiled Eggs & Whole Wheat Toast',
            'calories': 230,
            'protein': 15,
            'carbs': 18,
            'fat': 11,
            'confidence': 0.98,
          }
        ],
        'meal_type': 'breakfast',
        'logged_at': DateTime.now()
            .subtract(const Duration(hours: 4))
            .toIso8601String(),
        'source': 'manual',
      },
      {
        'id': 'sample_2',
        'user_id': uid,
        'image_path': null,
        'detected_items': [
          {
            'name': '2 Roti & Dal Tadka (Ghar Ka Khana)',
            'calories': 365,
            'protein': 14,
            'carbs': 56,
            'fat': 9,
            'confidence': 0.95,
          }
        ],
        'meal_type': 'lunch',
        'logged_at': DateTime.now()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
        'source': 'ai_scan',
      },
    ];
    await prefs.setString(key, jsonEncode(sample));
    return sample;
  }

  Future<List<FoodLogModel>> getFoodLogsForDate(
      String uid, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    if (_isGuest(uid)) {
      final list = await _getRawGuestFoodLogs(uid);
      return list
          .where((row) {
            final loggedAt =
                DateTime.tryParse(row['logged_at']?.toString() ?? '');
            return loggedAt != null &&
                !loggedAt.isBefore(startOfDay) &&
                loggedAt.isBefore(endOfDay);
          })
          .map((row) => FoodLogModel.fromMap(row['id'] as String, row))
          .toList();
    }

    return getFoodLogsForRange(uid, startOfDay, endOfDay);
  }

  Stream<List<FoodLogModel>> streamFoodLogsForDate(
      String uid, DateTime date) async* {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    if (_isGuest(uid)) {
      final initial = await getFoodLogsForDate(uid, date);
      yield initial;
      yield* _guestFoodLogsController.stream.map((logs) {
        return logs.where((l) {
          return !l.loggedAt.isBefore(startOfDay) &&
              l.loggedAt.isBefore(endOfDay);
        }).toList();
      });
      return;
    }

    yield* _db
        .from('food_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('logged_at', ascending: false)
        .limit(500)
        .map((rows) => rows
            .where((row) {
              final loggedAt =
                  DateTime.tryParse(row['logged_at']?.toString() ?? '');
              return loggedAt != null &&
                  !loggedAt.isBefore(startOfDay) &&
                  loggedAt.isBefore(endOfDay);
            })
            .map((row) => FoodLogModel.fromMap(row['id'] as String, row))
            .toList());
  }

  Future<List<FoodLogModel>> getFoodLogsForRange(
      String uid, DateTime start, DateTime end) async {
    if (_isGuest(uid)) {
      final list = await _getRawGuestFoodLogs(uid);
      return list
          .where((row) {
            final loggedAt =
                DateTime.tryParse(row['logged_at']?.toString() ?? '');
            return loggedAt != null &&
                !loggedAt.isBefore(start) &&
                loggedAt.isBefore(end);
          })
          .map((row) => FoodLogModel.fromMap(row['id'] as String, row))
          .toList();
    }

    final rows = await _db
        .from('food_logs')
        .select()
        .eq('user_id', uid)
        .gte('logged_at', start.toIso8601String())
        .lt('logged_at', end.toIso8601String())
        .order('logged_at', ascending: false)
        .limit(400);
    return rows
        .map<FoodLogModel>(
            (row) => FoodLogModel.fromMap(row['id'] as String, row))
        .toList();
  }

  Future<void> deleteFoodLog(String uid, String logId) async {
    if (_isGuest(uid)) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'guest_food_logs_$uid';
      final list = await _getRawGuestFoodLogs(uid);
      list.removeWhere((item) => item['id'] == logId);
      await prefs.setString(key, jsonEncode(list));
      final allLogs = list
          .map((item) => FoodLogModel.fromMap(item['id'] as String, item))
          .toList();
      _guestFoodLogsController.add(allLogs);
      return;
    }
    await _db.from('food_logs').delete().eq('id', logId).eq('user_id', uid);
  }

  // ==================== WATER LOGS ====================

  Future<String> addWaterLog(String uid, WaterLogModel log) async {
    if (_isGuest(uid)) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'guest_water_logs_$uid';
      final list = await _getRawGuestWaterLogs(uid);
      final newId = 'guest_water_${DateTime.now().millisecondsSinceEpoch}';
      final map = log.toMap(uid);
      map['id'] = newId;
      list.insert(0, map);
      await prefs.setString(key, jsonEncode(list));
      final all = list
          .map((item) => WaterLogModel.fromMap(item['id'] as String, item))
          .toList();
      _guestWaterLogsController.add(all);
      return newId;
    }

    final row = await _db
        .from('water_logs')
        .insert(log.toMap(uid))
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<List<Map<String, dynamic>>> _getRawGuestWaterLogs(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'guest_water_logs_$uid';
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    final initial = [
      {
        'id': 'water_1',
        'user_id': uid,
        'amount_ml': 500,
        'logged_at': DateTime.now()
            .subtract(const Duration(hours: 3))
            .toIso8601String(),
      },
      {
        'id': 'water_2',
        'user_id': uid,
        'amount_ml': 250,
        'logged_at': DateTime.now()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
      },
    ];
    await prefs.setString(key, jsonEncode(initial));
    return initial;
  }

  Stream<List<WaterLogModel>> streamWaterLogsForDate(
      String uid, DateTime date) async* {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    if (_isGuest(uid)) {
      final list = await _getRawGuestWaterLogs(uid);
      final mapped = list
          .where((row) {
            final loggedAt =
                DateTime.tryParse(row['logged_at']?.toString() ?? '');
            return loggedAt != null &&
                !loggedAt.isBefore(startOfDay) &&
                loggedAt.isBefore(endOfDay);
          })
          .map((row) => WaterLogModel.fromMap(row['id'] as String, row))
          .toList();
      yield mapped;
      yield* _guestWaterLogsController.stream.map((logs) {
        return logs.where((l) {
          return !l.loggedAt.isBefore(startOfDay) &&
              l.loggedAt.isBefore(endOfDay);
        }).toList();
      });
      return;
    }

    yield* _db
        .from('water_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('logged_at', ascending: false)
        .limit(500)
        .map((rows) => rows
            .where((row) {
              final loggedAt =
                  DateTime.tryParse(row['logged_at']?.toString() ?? '');
              return loggedAt != null &&
                  !loggedAt.isBefore(startOfDay) &&
                  loggedAt.isBefore(endOfDay);
            })
            .map((row) => WaterLogModel.fromMap(row['id'] as String, row))
            .toList());
  }

  Future<void> deleteWaterLog(String uid, String logId) async {
    if (_isGuest(uid)) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'guest_water_logs_$uid';
      final list = await _getRawGuestWaterLogs(uid);
      list.removeWhere((item) => item['id'] == logId);
      await prefs.setString(key, jsonEncode(list));
      final all = list
          .map((item) => WaterLogModel.fromMap(item['id'] as String, item))
          .toList();
      _guestWaterLogsController.add(all);
      return;
    }
    await _db.from('water_logs').delete().eq('id', logId).eq('user_id', uid);
  }

  // ==================== WEIGHT LOGS ====================

  Future<String> addWeightLog(String uid, WeightLogModel log) async {
    if (_isGuest(uid)) return 'guest_weight';
    final row = await _db
        .from('weight_logs')
        .insert(log.toMap(uid))
        .select('id')
        .single();
    return row['id'] as String;
  }

  Stream<List<WeightLogModel>> streamWeightLogs(String uid,
      {int limit = 30}) async* {
    if (_isGuest(uid)) {
      yield [
        WeightLogModel(
          id: 'guest_w1',
          weightKg: 70.0,
          loggedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
      return;
    }
    yield* _db
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
    if (_isGuest(uid)) {
      return [
        WeightLogModel(
          id: 'guest_w1',
          weightKg: 70.0,
          loggedAt: DateTime.now(),
        ),
      ];
    }
    final rows = await _db
        .from('weight_logs')
        .select()
        .eq('user_id', uid)
        .gte('logged_at', start.toIso8601String())
        .lt('logged_at', end.toIso8601String())
        .order('logged_at')
        .limit(400);
    return rows
        .map<WeightLogModel>(
            (row) => WeightLogModel.fromMap(row['id'] as String, row))
        .toList();
  }

  // ==================== PUSHUP SESSIONS ====================

  Stream<PushupSessionModel?> streamLatestPushupSession(String uid) async* {
    if (_isGuest(uid)) {
      yield null;
      return;
    }
    yield* _db
        .from('pushup_sessions')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('completed_at', ascending: false)
        .limit(200)
        .map((rows) {
          final verified = rows.where((row) => row['status'] == 'verified');
          if (verified.isEmpty) return null;
          final row = verified.first;
          return PushupSessionModel.fromMap(row['id'] as String, row);
        });
  }

  Future<List<PushupSessionModel>> getPushupSessionsForRange(
      String uid, DateTime start, DateTime end) async {
    if (_isGuest(uid)) return const [];
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
    if (_isGuest(uid)) {
      return BlockedAppsConfigModel(
        blockedPackages: const [],
        allowlistPackages: const [],
      );
    }
    final row = await _db
        .from('blocked_apps_config')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return BlockedAppsConfigModel.fromMap(row);
  }

  Stream<BlockedAppsConfigModel?> streamBlockedAppsConfig(String uid) async* {
    if (_isGuest(uid)) {
      yield BlockedAppsConfigModel(
        blockedPackages: const [],
        allowlistPackages: const [],
      );
      return;
    }
    yield* _db
        .from('blocked_apps_config')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .map((rows) =>
            rows.isEmpty ? null : BlockedAppsConfigModel.fromMap(rows.first));
  }

  Future<void> updateBlockedAppsConfig(
      String uid, BlockedAppsConfigModel config) async {
    if (_isGuest(uid)) return;
    await _db.from('blocked_apps_config').upsert(config.toMap(uid));
  }

  // ==================== STREAKS ====================

  Stream<StreakModel?> streamStreaks(String uid) async* {
    if (_isGuest(uid)) {
      yield StreakModel(
        currentPushupStreak: 2,
        longestPushupStreak: 5,
        currentFoodLogStreak: 3,
        lastFoodLogDate: DateTime.now(),
        lastPushupDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      return;
    }
    yield* _db
        .from('streaks')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .map((rows) => rows.isEmpty ? null : StreakModel.fromMap(rows.first));
  }

  Future<StreakModel?> getStreaks(String uid) async {
    if (_isGuest(uid)) {
      return StreakModel(
        currentPushupStreak: 2,
        longestPushupStreak: 5,
        currentFoodLogStreak: 3,
        lastFoodLogDate: DateTime.now(),
      );
    }
    final row =
        await _db.from('streaks').select().eq('user_id', uid).maybeSingle();
    if (row == null) return null;
    return StreakModel.fromMap(row);
  }

  // ==================== FINES ====================

  /// Fines the user still owes something on (`pending` or `rejected`).
  Stream<List<FineModel>> streamOutstandingFines(String uid) async* {
    if (_isGuest(uid)) {
      yield const [];
      return;
    }
    yield* _db
        .from('fines')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) => rows
            .where((row) =>
                row['status'] == 'pending' || row['status'] == 'rejected')
            .map(FineModel.fromMap)
            .toList());
  }

  Future<List<FineModel>> getAllFines(String uid) async {
    if (_isGuest(uid)) return const [];
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
    if (_isGuest(uid)) return 0;
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
    if (_isGuest(uid)) return;
    await _db.from('emergency_unlocks').insert(unlock.toMap(uid));
  }
}
