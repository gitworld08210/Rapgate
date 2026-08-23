import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../models/referral_model.dart';

class ReferralService {
  final SupabaseClient _db = supabase;

  /// Fetches the current user's referral code, total count, and leaderboard.
  Future<ReferralStats> getMyReferralStats() async {
    try {
      final response = await _db.functions.invoke(
        'get-referral-stats',
        body: {},
      );

      if (response.status >= 400) {
        final data = response.data as Map?;
        throw Exception(
            data?['error']?.toString() ?? 'Failed to load referral stats.');
      }

      final data = response.data as Map<String, dynamic>;
      return ReferralStats.fromMap(data);
    } on FunctionException catch (e) {
      throw Exception(
          _extractError(e, 'Could not load referral stats.'));
    }
  }

  /// Applies a referral code for the current user.
  Future<String> applyReferralCode(String code) async {
    try {
      final response = await _db.functions.invoke(
        'apply-referral',
        body: {'code': code.trim().toUpperCase()},
      );

      if (response.status >= 400) {
        final data = response.data as Map?;
        throw Exception(
            data?['error']?.toString() ?? 'Failed to apply referral code.');
      }

      final data = response.data as Map<String, dynamic>;
      return data['message'] as String? ??
          'Referral applied! Both you and your friend get 7 days fine-free.';
    } on FunctionException catch (e) {
      throw Exception(_extractError(e, 'Could not apply referral code.'));
    }
  }

  /// Shares the referral link via the system share sheet.
  Future<void> shareReferralLink(String code) async {
    final message =
        'Join RepGate with my code: $code\n\nDo pushups, track nutrition, stay accountable.\n\nDownload: https://repgate.app/join/$code';
    await Share.share(message);
  }

  String _extractError(FunctionException error, String fallback) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return fallback;
  }
}
