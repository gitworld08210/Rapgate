import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Supabase Auth facade used by the existing UI with Instant Guest/Demo mode.
///
/// Username/password accounts use a deterministic internal email alias because
/// Supabase Auth natively authenticates with email or phone. The visible
/// username is also stored in `auth.users.user_metadata` and can be copied to
/// the public users profile during onboarding.
class AuthService {
  static const _guestKey = 'rapgate_is_guest_mode';
  static const _guestUidKey = 'rapgate_guest_uid';
  static User? _cachedGuestUser;
  static final StreamController<User?> _authController =
      StreamController<User?>.broadcast();
  static bool _initialized = false;

  GoTrueClient get _auth => supabase.auth;

  AuthService() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isGuest = prefs.getBool(_guestKey) ?? false;
      if (isGuest) {
        final guestId = prefs.getString(_guestUidKey) ?? 'guest_demo_user';
        _cachedGuestUser = User(
          id: guestId,
          appMetadata: const {},
          userMetadata: const {'name': 'Guest Explorer'},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );
        _authController.add(_cachedGuestUser);
      } else {
        _authController.add(_auth.currentUser);
      }
    } catch (_) {
      _authController.add(_auth.currentUser);
    }

    _auth.onAuthStateChange.listen((state) {
      if (_cachedGuestUser == null) {
        _authController.add(state.session?.user);
      }
    });
  }

  Stream<User?> get authStateChanges async* {
    await _initAuth();
    yield currentUser;
    yield* _authController.stream;
  }

  User? get currentUser => _cachedGuestUser ?? _auth.currentUser;
  String? get uid => currentUser?.id;
  bool get isGuest => _cachedGuestUser != null;

  /// Instant Guest / Demo Mode — zero OTP, zero Supabase email limits, 100% offline.
  Future<void> signInAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    final guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setBool(_guestKey, true);
    await prefs.setString(_guestUidKey, guestId);
    _cachedGuestUser = User(
      id: guestId,
      appMetadata: const {},
      userMetadata: const {'name': 'Guest Explorer'},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );
    _authController.add(_cachedGuestUser);
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<AuthResponse> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signUp(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sends a passwordless email OTP. The caller must verify it with
  /// [verifyEmailOTP].
  Future<void> sendEmailOTP({required String email}) async {
    try {
      await _auth.signInWithOtp(email: email.trim());
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<AuthResponse> verifyEmailOTP({
    required String email,
    required String token,
  }) async {
    try {
      return await _auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.email,
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Supabase's phone OTP flow is server-driven; Android auto-verification is
  /// not exposed by the Flutter SDK, so the UI verifies the received code.
  Future<void> sendPhoneOTP({
    required String phoneNumber,
    required void Function(String phoneNumber) onCodeSent,
    required void Function(String error) onError,
    int? resendToken,
    // Kept as an optional compatibility parameter for old callers.
    Future<void> Function(Object credential)? onAutoVerified,
  }) async {
    try {
      await _auth.signInWithOtp(phone: phoneNumber);
      onCodeSent(phoneNumber);
    } catch (e) {
      onError(_handleAuthException(e));
    }
  }

  Future<AuthResponse> verifyPhoneOTP({
    required String phoneNumber,
    required String smsCode,
  }) async {
    try {
      return await _auth.verifyOTP(
        phone: phoneNumber,
        token: smsCode.trim(),
        type: OtpType.sms,
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<AuthResponse> signInWithPhoneCredential(Object credential) {
    throw UnsupportedError(
      'Phone credentials are not exposed by Supabase Flutter; verify the SMS OTP instead.',
    );
  }

  /// Username/password support without adding a second identity provider.
  /// The username remains user-facing while Auth uses a non-deliverable alias.
  Future<AuthResponse> signInWithUsername({
    required String username,
    required String password,
  }) => signInWithEmail(
        email: _usernameAlias(username),
        password: password,
      );

  Future<AuthResponse> registerWithUsername({
    required String username,
    required String password,
  }) async {
    final clean = _validateUsername(username);
    try {
      return await _auth.signUp(
        email: _usernameAlias(clean),
        password: password,
        data: {'username': clean},
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestKey);
    await prefs.remove(_guestUidKey);
    _cachedGuestUser = null;
    _authController.add(null);
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  /// Account cleanup is intentionally server-side so Storage and Postgres
  /// rows are removed together instead of leaving orphaned user data.
  Future<void> deleteAccount() async {
    final response = await supabase.functions.invoke('delete-account');
    if (response.status >= 400) {
      throw Exception('Could not delete the account.');
    }
    await signOut();
  }

  String _handleAuthException(Object error) {
    if (error is AuthException) {
      switch (error.statusCode) {
        case '400':
          return 'Invalid credentials or expired OTP.';
        case '422':
          return 'Please enter a valid email, phone number, or password.';
        case '429':
          return 'Too many attempts. Please try again later.';
        default:
          return error.message;
      }
    }
    debugPrint('Supabase Auth error: $error');
    return 'An authentication error occurred. Please try again.';
  }

  static String _validateUsername(String raw) {
    final username = raw.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,32}$').hasMatch(username)) {
      throw 'Username must be 3–32 characters using letters, numbers, or _.';
    }
    return username;
  }

  static String _usernameAlias(String username) {
    final clean = _validateUsername(username);
    return '$clean@users.rapgate.invalid';
  }
}
