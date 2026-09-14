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

  /// Fires at the next local midnight to re-scope the today-bound streams, so
  /// food/water logs don't keep querying yesterday if the app stays alive.
  Timer? _midnightTimer;
  DateTime? _subscribedDate;

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
    _subscribedDate = DateTime(today.year, today.month, today.day);

    // Re-subscribe the today-scoped streams at the next local midnight so a
    // long-lived session doesn't keep showing yesterday's food/water logs.
    _scheduleMidnightRefresh(uid);

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

  /// Schedules a one-shot timer for just after the next local midnight. When it
  /// fires, if the calendar day really has changed, the streams are rebuilt for
  /// the new "today". The timer reschedules itself for each subsequent day.
  void _scheduleMidnightRefresh(String uid) {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1, seconds: 1));
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (_uid != uid) return; // user changed / signed out
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      if (_subscribedDate == null || day.isAfter(_subscribedDate!)) {
        _subscribeToStreams(uid); // rebuilds streams + reschedules the timer
      } else {
        _scheduleMidnightRefresh(uid);
      }
    });
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
    _midnightTimer?.cancel();
    _foodLogsSub?.cancel();
    _waterLogsSub?.cancel();
    _weightLogsSub?.cancel();
    _pushupSessionSub?.cancel();
    _blockedAppsConfigSub?.cancel();
    _finesSub?.cancel();
    _uid = null;
    _subscribedDate = null;
  }

  @override
  void dispose() {
    clearSubscriptions();
    super.dispose();
  }
}
