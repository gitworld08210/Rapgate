import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/streak_model.dart';

class UserProvider extends ChangeNotifier {
  AuthService? _authService;
  final DatabaseService _firestoreService = DatabaseService();

  UserModel? _userModel;
  StreakModel? _streaks;
  bool _isLoading = false;
  bool _isProfileComplete = false;
  String? _error;

  StreamSubscription<UserModel?>? _userSubscription;
  StreamSubscription<StreakModel?>? _streakSubscription;

  // Getters
  UserModel? get userModel => _userModel;
  StreakModel? get streaks => _streaks;
  bool get isLoading => _isLoading;
  bool get isProfileComplete => _isProfileComplete;
  String? get error => _error;
  bool get isLoggedIn => _authService?.currentUser != null;
  String? get uid => _authService?.uid;

  void updateAuth(AuthService authService) {
    _authService = authService;
    final user = authService.currentUser;
    if (user != null) {
      _loadUserData(user.id);
    } else {
      _clearData();
    }
  }

  Future<void> _loadUserData(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userSubscription?.cancel();
      _userSubscription = _firestoreService.streamUserProfile(uid).listen(
        (user) {
          _userModel = user;
          _isProfileComplete = user != null && user.name.isNotEmpty;
          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          // Table not provisioned, RLS denies access, or network issue.
          // Treat as "no profile" so the user reaches onboarding rather than
          // staring at a spinner forever.
          _isLoading = false;
          _isProfileComplete = false;
          _error = 'Could not load profile: $e';
          notifyListeners();
        },
      );

      _streakSubscription?.cancel();
      _streakSubscription = _firestoreService.streamStreaks(uid).listen(
        (streaks) {
          _streaks = streaks;
          notifyListeners();
        },
        onError: (_) {}, // Silently ignore; streaks will show 0
      );

      // Safety timeout: if neither onData nor onError fires within 8 seconds,
      // unblock the loading state so the user isn't stuck permanently.
      Future.delayed(const Duration(seconds: 8), () {
        if (_isLoading) {
          _isLoading = false;
          _isProfileComplete = false;
          notifyListeners();
        }
      });
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save user profile (during onboarding or profile edit)
  Future<void> saveProfile(UserModel user) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.setUserProfile(user);
      _userModel = user;
      _isProfileComplete = true;
    } catch (e) {
      _error = 'Failed to save profile: $e';
      // Rethrow so the caller (onboarding) can surface the failure instead of
      // silently re-rendering the same step, which looked like an infinite loop.
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update specific profile fields
  Future<void> updateProfile({
    String? name,
    int? age,
    double? weight,
    double? height,
    String? gender,
    double? dailyCalorieTarget,
    double? dailyProteinTarget,
  }) async {
    if (_userModel == null) return;

    final updated = _userModel!.copyWith(
      name: name,
      age: age,
      weight: weight,
      height: height,
      gender: gender,
      dailyCalorieTarget: dailyCalorieTarget,
      dailyProteinTarget: dailyProteinTarget,
    );

    await saveProfile(updated);
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService?.signOut();
    _clearData();
  }

  void _clearData() {
    _userSubscription?.cancel();
    _streakSubscription?.cancel();
    _userModel = null;
    _streaks = null;
    _isProfileComplete = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _streakSubscription?.cancel();
    super.dispose();
  }
}
