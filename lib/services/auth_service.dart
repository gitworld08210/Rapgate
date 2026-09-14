import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Supabase Auth facade.
///
/// Authentication is **email only** and passwordless: the user requests a
/// 6-digit code (delivered via Azure Communication Services from the
/// `send-email-otp` Edge Function) and verifies it with `verify-email-otp`,
/// which returns a Supabase session this client installs. Phone/SMS auth has
/// been removed entirely.
class AuthService {
  GoTrueClient get _auth => supabase.auth;

  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((state) => state.session?.user);

  User? get currentUser => _auth.currentUser;
  String? get uid => currentUser?.id;

  bool get isValidEmail => currentUser?.email != null;

  static bool looksLikeEmail(String value) {
    final email = value.trim();
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) &&
        email.length <= 254;
  }

  // ==================== EMAIL OTP (passwordless) ====================

  /// Requests a one-time sign-in code for [email]. The code is generated and
  /// emailed server-side (Azure ACS); nothing sensitive is returned here.
  ///
  /// Throws [AuthException] with a user-presentable message on failure.
  Future<void> sendEmailOtp(String email) async {
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

  /// Verifies [code] for [email]. On success the returned session is installed
  /// into the Supabase client, so [authStateChanges] fires and the app routes
  /// the user in. Returns whether this was a brand-new account.
  Future<bool> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    final clean = email.trim().toLowerCase();
    final digits = code.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(digits)) {
      throw const AuthException('Enter the 6-digit code.');
    }
    try {
      final response = await supabase.functions.invoke(
        'verify-email-otp',
        body: {'email': clean, 'code': digits},
      );
      if (response.status >= 400) {
        throw AuthException(_functionError(response.data, 'Could not verify the code.'));
      }

      final data = (response.data as Map?) ?? const {};
      final session = data['session'] as Map?;
      final accessToken = session?['access_token'] as String?;
      final refreshToken = session?['refresh_token'] as String?;
      if (accessToken == null || refreshToken == null) {
        throw const AuthException('Could not start your session. Please try again.');
      }

      // Install the server-minted session; this triggers onAuthStateChange.
      await _auth.setSession(refreshToken);

      return data['isNewUser'] == true;
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
