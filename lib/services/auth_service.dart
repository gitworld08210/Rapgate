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

/// User-presentable failure from the auth flow.
class AppAuthException implements Exception {
  const AppAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  GoTrueClient get _auth => supabase.auth;

  Stream<User?> get authStateChanges => _auth.onAuthStateChange
      .map((state) => state.session?.user);

  User? get currentUser => _auth.currentUser;
  String? get uid => currentUser?.id;

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
      onError(_handleAuthException(e).message);
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

  AppAuthException _handleAuthException(Object error) {
    if (error is AuthException) {
      switch (error.statusCode) {
        case '400':
          return const AppAuthException('Invalid credentials or expired OTP.');
        case '422':
          return const AppAuthException('Please enter a valid email, phone number, or password.');
        case '429':
          return const AppAuthException('Too many attempts. Please try again later.');
        default:
          return AppAuthException(error.message);
      }
    }
    debugPrint('Supabase Auth error: $error');
    return const AppAuthException('An authentication error occurred. Please try again.');
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
