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
    anonKey: SupabaseConfig.anonKey,
    debug: false,
  );
}
