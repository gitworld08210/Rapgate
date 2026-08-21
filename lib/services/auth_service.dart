import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Supabase Auth facade used by the existing UI.
///
/// Username/password accounts use a deterministic internal email alias because
/// Supabase Auth natively authenticates with email or phone. The visible
/// username is also stored in `auth.users.user_metadata` and can be copied to
/// the public users profile during onboarding.
class AuthService {
  GoTrueClient get _auth => supabase.auth;

  Stream<User?> get authStateChanges => _auth.onAuthStateChange
      .map((state) => state.session?.user);

  User? get currentUser => _auth.currentUser;
  String? get uid => currentUser?.id;
  Session? get currentSession => _auth.currentSession;

  /// Returns true if the user has a valid, non-expired session.
  bool get hasValidSession {
    final session = currentSession;
    if (session == null) return false;
    // Supabase JWT exp is in seconds since epoch
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    // Consider expired if within 60s of expiry (buffer for network latency)
    final expiryTime =
        DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    return DateTime.now().isBefore(expiryTime.subtract(const Duration(seconds: 60)));
  }

  /// Ensures the session is fresh. If expired, attempts a refresh.
  /// Returns true if session is valid after the check, false if user must re-login.
  Future<bool> ensureValidSession() async {
    if (hasValidSession) return true;

    // Attempt to refresh the session
    try {
      final response = await _auth.refreshSession();
      if (response.session != null) {
        debugPrint('[Auth] Session refreshed successfully');
        return true;
      }
    } catch (e) {
      debugPrint('[Auth] Session refresh failed: $e');
    }
    return false;
  }

  /// Wraps an async operation with session validation. If the session is expired,
  /// attempts refresh first. If refresh fails, throws a clear SessionExpiredException.
  Future<T> withValidSession<T>(Future<T> Function() operation) async {
    final isValid = await ensureValidSession();
    if (!isValid) {
      throw SessionExpiredException();
    }
    try {
      return await operation();
    } on AuthException catch (e) {
      // If we get an auth error during the operation, the session might have
      // just expired. Try one more refresh.
      if (e.statusCode == '401' || e.message.contains('JWT')) {
        final refreshed = await ensureValidSession();
        if (refreshed) {
          return await operation();
        }
      }
      throw SessionExpiredException();
    }
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

  Future<void> signOut() => _auth.signOut();

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
        case '401':
          return 'Your session has expired. Please sign in again.';
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

/// Thrown when the session cannot be refreshed and the user must sign in again.
class SessionExpiredException implements Exception {
  @override
  String toString() => 'Your session has expired. Please sign in again.';
}
