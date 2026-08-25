import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../models/food_log_model.dart';
import '../models/water_log_model.dart';
import '../models/weight_log_model.dart';
import '../models/pushup_session_model.dart';
import '../models/blocked_apps_config_model.dart';
import '../models/fine_model.dart';
import '../utils/constants.dart';

class HealthProvider extends ChangeNotifier {
  FirestoreService? _firestoreService;
  String? _uid;

  // Data
  List<FoodLogModel> _todayFoodLogs = [];
  List<WaterLogModel> _todayWaterLogs = [];
  List<WeightLogModel> _weightLogs = [];
  PushupSessionModel? _latestPushupSession;
  BlockedAppsConfigModel? _blockedAppsConfig;
  List<FineModel> _outstandingFines = [];

  // Subscriptions
  StreamSubscription? _foodLogsSub;
  StreamSubscription? _waterLogsSub;
  StreamSubscription? _weightLogsSub;
  StreamSubscription? _pushupSessionSub;
  StreamSubscription? _blockedAppsConfigSub;
  StreamSubscription? _finesSub;

  // Getters
  List<FoodLogModel> get todayFoodLogs => _todayFoodLogs;
  List<WaterLogModel> get todayWaterLogs => _todayWaterLogs;
  List<WeightLogModel> get weightLogs => _weightLogs;
  PushupSessionModel? get latestPushupSession => _latestPushupSession;
  BlockedAppsConfigModel? get blockedAppsConfig => _blockedAppsConfig;
  /// Fines still owed — `pending` or `rejected`.
  List<FineModel> get outstandingFines => _outstandingFines;

  // Computed getters
  double get todayTotalCalories =>
      _todayFoodLogs.fold(0, (sum, log) => sum + log.totalCalories);

  double get todayTotalProtein =>
      _todayFoodLogs.fold(0, (sum, log) => sum + log.totalProtein);

  double get todayTotalCarbs =>
      _todayFoodLogs.fold(0, (sum, log) => sum + log.totalCarbs);

  double get todayTotalFat =>
      _todayFoodLogs.fold(0, (sum, log) => sum + log.totalFat);

  int get todayWaterIntakeMl =>
      _todayWaterLogs.fold(0, (sum, log) => sum + log.amountMl);

  double get waterProgress =>
      todayWaterIntakeMl / AppConstants.dailyWaterTargetMl;

  bool get isAppsUnlocked => _latestPushupSession?.isUnlockActive ?? false;

  DateTime? get unlockExpiresAt => _latestPushupSession?.unlockGrantedUntil;

  /// Total owed, in paise.
  int get totalOutstandingFineAmount =>
      _outstandingFines.fold(0, (sum, fine) => sum + fine.amount);

  // ---------- Achievement-related getters (STUBS) ----------
  // FIXME: These are single-day stubs. Multi-day achievements (e.g.
  // fitness_500_reps, nutrition_7_days, hydration_hero) will never unlock
  // because this provider only holds today's snapshot data. To fix properly,
  // add historical aggregation queries to Supabase (e.g. count of all
  // sessions, sum of all reps, distinct food-log days, consecutive water
  // days). Until then, only single-day/single-session achievements can unlock.

  /// Total number of verified push-up sessions completed.
  /// FIXME(stub): Only returns 0 or 1 based on today's session. Needs a
  /// Supabase query counting all completed sessions for the user.
  int get totalVerifiedSessions =>
      _latestPushupSession?.isSessionComplete == true ? 1 : 0;

  /// Total verified push-up reps across all sessions.
  /// FIXME(stub): Only returns today's latest session rep count. Needs a
  /// Supabase aggregate (SUM of rep_count across all verified sessions).
  int get totalVerifiedReps => _latestPushupSession?.repCount ?? 0;

  /// Number of distinct days with at least one food log.
  /// FIXME(stub): Only returns 0 or 1 based on today. Needs a Supabase
  /// COUNT(DISTINCT date) query on the food_logs table.
  int get totalFoodLogDays => _todayFoodLogs.isNotEmpty ? 1 : 0;

  /// Total food scans performed.
  /// FIXME(stub): Only returns today's scan count. Needs a Supabase COUNT(*)
  /// on food_logs for the user.
  int get totalFoodScans => _todayFoodLogs.length;

  /// Current consecutive days of hitting the water target (3L).
  /// FIXME(stub): Only returns 0 or 1 based on today. Needs a Supabase query
  /// that walks backward from today counting consecutive days where
  /// SUM(amount_ml) >= dailyWaterTargetMl.
  int get currentWaterStreak =>
      todayWaterIntakeMl >= AppConstants.dailyWaterTargetMl ? 1 : 0;

  /// Number of days the protein target was met.
  /// FIXME(stub): Always returns 0. No protein target tracking exists yet.
  /// Needs a Supabase query counting days where SUM(protein) >= user target.
  int get proteinTargetDays => 0;

  void updateFirestore(FirestoreService firestoreService) {
    _firestoreService = firestoreService;
  }

  /// Initialize streams for a user
  void initializeForUser(String uid) {
    if (_uid == uid) return; // Already initialized
    _uid = uid;
    _subscribeToStreams(uid);
  }

  void _subscribeToStreams(String uid) {
    final today = DateTime.now();

    // FIXME: subscriptions use today's date at subscribe-time; if the app stays
    // alive past midnight, food/water logs won't update until next hot restart.

    // Food logs for today
    _foodLogsSub?.cancel();
    _foodLogsSub = _firestoreService
        ?.streamFoodLogsForDate(uid, today)
        .listen((logs) {
      _todayFoodLogs = logs;
      notifyListeners();
    }, onError: (_) {});

    // Water logs for today
    _waterLogsSub?.cancel();
    _waterLogsSub = _firestoreService
        ?.streamWaterLogsForDate(uid, today)
        .listen((logs) {
      _todayWaterLogs = logs;
      notifyListeners();
    }, onError: (_) {});

    // Weight logs
    _weightLogsSub?.cancel();
    _weightLogsSub =
        _firestoreService?.streamWeightLogs(uid).listen((logs) {
      _weightLogs = logs;
      notifyListeners();
    }, onError: (_) {});

    // Latest pushup session
    _pushupSessionSub?.cancel();
    _pushupSessionSub = _firestoreService
        ?.streamLatestPushupSession(uid)
        .listen((session) {
      _latestPushupSession = session;
      notifyListeners();
    }, onError: (_) {});

    // Blocked apps config
    _blockedAppsConfigSub?.cancel();
    _blockedAppsConfigSub = _firestoreService
        ?.streamBlockedAppsConfig(uid)
        .listen((config) {
      _blockedAppsConfig = config;
      notifyListeners();
    }, onError: (_) {});

    // Outstanding fines (pending or rejected)
    _finesSub?.cancel();
    _finesSub =
        _firestoreService?.streamOutstandingFines(uid).listen((fines) {
      _outstandingFines = fines;
      notifyListeners();
    }, onError: (_) {});
  }

  /// Add water log
  Future<void> addWater(int amountMl) async {
    if (_uid == null || _firestoreService == null) return;
    final log = WaterLogModel(
      id: '',
      amountMl: amountMl,
      loggedAt: DateTime.now(),
    );
    await _firestoreService!.addWaterLog(_uid!, log);
  }

  /// Add weight log
  Future<void> addWeight(double weightKg) async {
    if (_uid == null || _firestoreService == null) return;
    final log = WeightLogModel(
      id: '',
      weightKg: weightKg,
      loggedAt: DateTime.now(),
    );
    await _firestoreService!.addWeightLog(_uid!, log);
  }

  /// Update blocked apps configuration
  Future<void> updateBlockedApps(BlockedAppsConfigModel config) async {
    if (_uid == null || _firestoreService == null) return;
    await _firestoreService!.updateBlockedAppsConfig(_uid!, config);
  }

  /// Clean up subscriptions
  void clearSubscriptions() {
    _foodLogsSub?.cancel();
    _waterLogsSub?.cancel();
    _weightLogsSub?.cancel();
    _pushupSessionSub?.cancel();
    _blockedAppsConfigSub?.cancel();
    _finesSub?.cancel();
    _uid = null;
  }

  @override
  void dispose() {
    clearSubscriptions();
    super.dispose();
  }
}
