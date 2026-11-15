import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FastingState {
  final bool isActive;
  final DateTime? startTime;
  final int targetHours;
  final Duration elapsed;
  final double progress;
  final Duration remaining;
  final bool isGoalReached;

  const FastingState({
    required this.isActive,
    this.startTime,
    this.targetHours = 16,
    this.elapsed = Duration.zero,
    this.progress = 0.0,
    this.remaining = Duration.zero,
    this.isGoalReached = false,
  });
}

class FastingService extends ChangeNotifier {
  static const String _keyStartTime = 'fasting_start_time';
  static const String _keyTargetHours = 'fasting_target_hours';
  static const String _keyIsActive = 'fasting_is_active';

  bool _isActive = false;
  DateTime? _startTime;
  int _targetHours = 16;

  bool get isActive => _isActive;
  DateTime? get startTime => _startTime;
  int get targetHours => _targetHours;

  FastingService() {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isActive = prefs.getBool(_keyIsActive) ?? false;
      _targetHours = prefs.getInt(_keyTargetHours) ?? 16;
      final startStr = prefs.getString(_keyStartTime);
      if (startStr != null) {
        _startTime = DateTime.tryParse(startStr);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[FastingService] Error loading fasting state: $e');
    }
  }

  FastingState getCurrentState() {
    if (!_isActive || _startTime == null) {
      return FastingState(
        isActive: false,
        targetHours: _targetHours,
      );
    }

    final now = DateTime.now();
    final elapsed = now.isAfter(_startTime!)
        ? now.difference(_startTime!)
        : Duration.zero;

    final targetSeconds = _targetHours * 3600;
    final elapsedSeconds = elapsed.inSeconds;
    final progress = (elapsedSeconds / targetSeconds).clamp(0.0, 1.0);
    final remainingSeconds = (targetSeconds - elapsedSeconds).clamp(0, targetSeconds);
    final isGoalReached = elapsedSeconds >= targetSeconds;

    return FastingState(
      isActive: true,
      startTime: _startTime,
      targetHours: _targetHours,
      elapsed: elapsed,
      progress: progress,
      remaining: Duration(seconds: remainingSeconds),
      isGoalReached: isGoalReached,
    );
  }

  Future<void> startFast({int targetHours = 16}) async {
    _isActive = true;
    _startTime = DateTime.now();
    _targetHours = targetHours;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsActive, true);
    await prefs.setString(_keyStartTime, _startTime!.toIso8601String());
    await prefs.setInt(_keyTargetHours, _targetHours);

    notifyListeners();
  }

  Future<void> endFast() async {
    _isActive = false;
    _startTime = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsActive, false);
    await prefs.remove(_keyStartTime);

    notifyListeners();
  }

  Future<void> updateTargetHours(int hours) async {
    _targetHours = hours;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTargetHours, _targetHours);
    notifyListeners();
  }
}
