import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../models/subscription_model.dart';

/// Manages subscription state and Pro feature gating.
///
/// Reads from the `subscriptions` table. Payment integration will be added
/// once Razorpay/Cashfree is connected.
class SubscriptionService {
  SubscriptionService({SupabaseClient? client}) : _db = client ?? supabase;

  final SupabaseClient _db;

  /// Features available only to Pro subscribers.
  static const List<String> proFeatures = [
    'Unlimited AI food scans',
    'Custom calorie & protein targets',
    'Advanced analytics & insights',
    'Priority support',
    'No ads',
    'Unlimited emergency unlocks',
  ];

  /// Fetches the current subscription for [uid].
  /// Returns `null` if no active subscription exists.
  Future<SubscriptionModel?> getSubscription(String uid) async {
    try {
      final row = await _db
          .from('subscriptions')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return SubscriptionModel.fromMap(row);
    } catch (e) {
      throw SubscriptionException('Could not load subscription: $e');
    }
  }

  /// Whether [uid] has an active Pro or Elite subscription.
  Future<bool> isPro(String uid) async {
    try {
      final sub = await getSubscription(uid);
      if (sub == null) return false;
      return sub.isActive && sub.tier.isPaid;
    } catch (_) {
      return false;
    }
  }
}

/// User-presentable failure from the subscription flow.
class SubscriptionException implements Exception {
  const SubscriptionException(this.message);
  final String message;

  @override
  String toString() => message;
}
