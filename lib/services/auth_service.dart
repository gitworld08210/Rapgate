import 'dart:async';

import 'package:flutter/foundation.dart';
// Hide the SDK's AuthException so our own user-facing AuthException below is
// unambiguous; the SDK type is still reachable via the `supa` prefix.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'supabase_client.dart';

/// Supabase Auth facade.
///
/// Authentication is **email + password**. A one-time code is used **only at
/// signup** to verify the user owns the email — login is a plain
/// email+password sign-in with no OTP. Phone/SMS auth has been removed.
///
/// Signup flow (server does the account creation):
///   1. [sendSignupOtp] — `send-email-otp` emails a 6-digit code (Azure ACS).
///   2. [verifySignupOtp] — `verify-email-otp` checks the code and creates the
///      auth user WITH the chosen password, returning a session we install.
class AuthService {
  GoTrueClient get _auth => supabase.auth;

  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((state) => state.session?.user);

  User? get currentUser => _auth.currentUser;
  String? get uid => currentUser?.id;

  static bool looksLikeEmail(String value) {
    final email = value.trim();
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) &&
        email.length <= 254;
  }

  // ==================== LOGIN (email + password, no OTP) ====================

  Future<void> login({required String email, required String password}) async {
    final clean = email.trim().toLowerCase();
    if (!looksLikeEmail(clean)) {
      throw const AuthException('Enter a valid email address.');
    }
    if (password.isEmpty) {
      throw const AuthException('Enter your password.');
    }
    try {
      await _auth.signInWithPassword(email: clean, password: password);
      // authStateChanges fires; AuthWrapper routes the user in.
    } on supa.AuthException catch (e) {
      throw AuthException(_mapSupabaseAuthError(e));
    } catch (e) {
      throw AuthException(_describe(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final clean = email.trim().toLowerCase();
    if (!looksLikeEmail(clean)) {
      throw const AuthException('Enter a valid email address.');
    }
    try {
      await _auth.resetPasswordForEmail(clean);
    } catch (e) {
      throw AuthException(_describe(e));
    }
  }

  // ==================== SIGNUP (email verify via OTP) ====================

  /// Step 1: request a signup verification code. Fails if the email is already
  /// registered (that user should log in instead).
  Future<void> sendSignupOtp(String email) async {
    final clean = email.trim().toLowerCase();
    if (!looksLikeEmail(clean)) {
      throw const AuthException('Enter a valid email address.');
    }
    try {
      final response = await supabase.functions.invoke(
        'send-email-otp',
        body: {'email': clean},
      );
      if (response.status >= 400) {
        throw AuthException(_functionError(response.data, 'Could not send your code.'));
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(_describe(e));
    }
  }

  /// Step 2: verify the code and create the account with [password] + [name].
  /// On success the returned session is installed and the user is signed in.
  Future<void> verifySignupOtp({
    required String email,
    required String code,
    required String password,
    required String name,
  }) async {
    final clean = email.trim().toLowerCase();
    final digits = code.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(digits)) {
      throw const AuthException('Enter the 6-digit code.');
    }
    if (password.length < 6) {
      throw const AuthException('Password must be at least 6 characters.');
    }
    try {
      final response = await supabase.functions.invoke(
        'verify-email-otp',
        body: {
          'email': clean,
          'code': digits,
          'password': password,
          'name': name.trim(),
        },
      );
      if (response.status >= 400) {
        throw AuthException(_functionError(response.data, 'Could not verify the code.'));
      }

      final data = (response.data as Map?) ?? const {};
      final session = data['session'] as Map?;
      final refreshToken = session?['refresh_token'] as String?;
      if (refreshToken != null) {
        await _auth.setSession(refreshToken);
      } else {
        // Account created but no session returned — fall back to password login.
        await _auth.signInWithPassword(email: clean, password: password);
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(_describe(e));
    }
  }

  // ==================== SESSION ====================

  Future<void> signOut() => _auth.signOut();

  /// Account cleanup is server-side so Storage and Postgres rows are removed
  /// together instead of leaving orphaned user data.
  Future<void> deleteAccount() async {
    final response = await supabase.functions.invoke('delete-account');
    if (response.status >= 400) {
      throw AuthException(_functionError(response.data, 'Could not delete the account.'));
    }
    await signOut();
  }

  // ==================== HELPERS ====================

  String _functionError(Object? data, String fallback) {
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return fallback;
  }

  String _mapSupabaseAuthError(supa.AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email first.';
    }
    return e.message;
  }

  String _describe(Object error) {
    if (error is FunctionException) {
      return 'Network error. Check your connection and try again.';
    }
    debugPrint('Auth error: $error');
    return 'Something went wrong. Please try again.';
  }
}

/// User-presentable authentication failure.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
