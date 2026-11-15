import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../models/streak_model.dart';

class UserProvider extends ChangeNotifier {
  AuthService? _authService;
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _userModel;
  StreakModel? _streaks;
  bool _isLoading = false;
  bool _isProfileComplete = false;
  String? _error;

  StreamSubscription<UserModel?>? _userSubscription;
  StreamSubscription<StreakModel?>? _streakSubscription;

  /// Uid whose profile is currently loading/loaded. updateAuth can fire
  /// again on provider rebuilds; the loaded profile is the source of truth,
  /// so a repeat call for the same user must not re-subscribe and reload.
  String? _loadingUid;

  /// True once the profile stream (or the one-shot fallback) has delivered
  /// a definitive answer — a row, or a definitive "no row". A later channel
  /// error must never override that answer.
  bool _profileResolved = false;

  /// Bumps on every _loadUserData call so delayed timers/retries from an
  /// older load can't act on a newer one (e.g. after sign-out/sign-in).
  int _loadGeneration = 0;

  /// One-shot fallback attempts in the current load cycle.
  int _fallbackAttempts = 0;

  /// Whether this load cycle already tried to create a missing users row.
  /// The signup trigger sometimes never creates the row (missing/broken
  /// trigger in the live DB); the bootstrap upsert runs at most once per
  /// cycle so a failing insert can't spam the database.
  bool _bootstrapAttempted = false;

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
      if (user.id == _loadingUid) return;
      _loadUserData(user.id);
    } else {
      _clearData();
    }
  }

  Future<void> _loadUserData(String uid) async {
    final generation = ++_loadGeneration;
    _loadingUid = uid;
    _profileResolved = false;
    _fallbackAttempts = 0;
    _bootstrapAttempted = false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userSubscription?.cancel();
      _userSubscription = _firestoreService.streamUserProfile(uid).listen(
        (user) {
          _applyLoadedProfile(user);
        },
        onError: (e) {
          // A Realtime channel error fires even after the REST select already
          // delivered the profile — it must not override a resolved profile.
          // With no profile yet, fall back to a one-shot REST fetch.
          if (_profileResolved) return;
          _resolveViaOneShot(uid, generation);
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

      // Safety timeout: if neither onData nor onError fires within 8 seconds
      // the stream is stuck (slow network / cold project). Resolve with a
      // one-shot REST fetch instead of defaulting to "no profile" — the old
      // default sent the user to onboarding for a profile that exists.
      Future.delayed(const Duration(seconds: 8), () {
        if (generation == _loadGeneration &&
            uid == _loadingUid &&
            _isLoading &&
            !_profileResolved) {
          _resolveViaOneShot(uid, generation);
        }
      });
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Applies a loaded profile (stream or one-shot) as the single source of
  /// truth for the onboarding gate.
  void _applyLoadedProfile(UserModel? user) {
    _userModel = user;
    _isProfileComplete = user != null && user.name.isNotEmpty;
    _profileResolved = true;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// One-shot REST fallback when the profile stream hasn't resolved.
  /// A returned row — or a definitive "no row" — resolves the gate. A failed
  /// fetch keeps the loader visible and retries instead of dumping the user
  /// into onboarding for a profile that may exist.
  ///
  /// A definitive "no row" also means the signup trigger never created the
  /// public.users row. In that case the row is created once here (bootstrap
  /// upsert) so the onboarding save updates an existing row instead of
  /// looping on a row that never appears.
  Future<void> _resolveViaOneShot(String uid, int generation) async {
    if (generation != _loadGeneration || uid != _loadingUid) return;
    try {
      var user = await _firestoreService.getUserProfile(uid);
      if (generation != _loadGeneration || uid != _loadingUid) return;
      if (user == null && !_bootstrapAttempted) {
        _bootstrapAttempted = true;
        await _bootstrapMissingProfile(uid);
        if (generation != _loadGeneration || uid != _loadingUid) return;
        user = await _firestoreService.getUserProfile(uid);
        if (generation != _loadGeneration || uid != _loadingUid) return;
      }
      _applyLoadedProfile(user);
    } catch (e) {
      if (generation != _loadGeneration || uid != _loadingUid) return;
      _fallbackAttempts++;
      _error = 'Could not load profile: $e';
      notifyListeners();
      if (_fallbackAttempts < 3) {
        // Still loading: retry the one-shot fetch after a short pause.
        Future.delayed(const Duration(seconds: 5), () {
          if (generation == _loadGeneration &&
              uid == _loadingUid &&
              _isLoading &&
              !_profileResolved) {
            _resolveViaOneShot(uid, generation);
          }
        });
      } else {
        // Persistent failure: re-subscribe from scratch so a later network
        // recovery can still resolve the profile.
        Future.delayed(const Duration(seconds: 10), () {
          if (generation == _loadGeneration &&
              uid == _loadingUid &&
              _isLoading &&
              !_profileResolved) {
            _loadUserData(uid);
          }
        });
      }
    }
  }

  /// Creates the public.users row when the signup trigger never did.
  ///
  /// Uses the same client-owned columns as the onboarding save
  /// ([UserModel.toMap]), so the server-fields trigger can't reject it.
  /// The name comes from the auth metadata when the signup carried one;
  /// otherwise it stays empty and onboarding collects it once.
  Future<void> _bootstrapMissingProfile(String uid) async {
    final metadataName =
        _authService?.currentUser?.userMetadata?['name']?.toString() ?? '';
    await _firestoreService.setUserProfile(UserModel(
      uid: uid,
      name: metadataName,
      age: 25,
      weight: 70,
      height: 170,
      gender: 'male',
      dailyCalorieTarget: 2000,
      dailyProteinTarget: 100,
    ));
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
      _profileResolved = true;
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
    // Bump the generation so delayed timers/retries from the old load can't
    // act after sign-out.
    _loadGeneration++;
    _loadingUid = null;
    _profileResolved = false;
    _fallbackAttempts = 0;
    _bootstrapAttempted = false;
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
