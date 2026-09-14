import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_config.dart';

SupabaseClient get supabase => Supabase.instance.client;

Future<void> initializeSupabase() async {
  if (!SupabaseConfig.isConfigured) {
    throw StateError(
      'Supabase is not configured. Supply SUPABASE_URL and SUPABASE_ANON_KEY '
      'with --dart-define when building the app.',
    );
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    // Accepts a modern publishable key (sb_publishable_...) or a legacy anon
    // JWT — both are safe to ship in the client.
    publishableKey: SupabaseConfig.anonKey,
    debug: false,
  );
}
