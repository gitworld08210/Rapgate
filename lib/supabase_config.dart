/// Supabase runtime configuration.
///
/// Values default to the Rapgate hosted project but can be overridden at build
/// time (recommended for CI / alternate environments):
///
/// flutter build apk --release \
///   --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<publishable-anon-key> \
///   --dart-define=CLOUDINARY_CLOUD_NAME=<your-cloud> \
///   --dart-define=CLOUDINARY_UPLOAD_PRESET=rapgate-dataset
///
/// Only the publishable/anon key belongs here — never the service-role key.
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hjxesslwvimpgxazwmep.supabase.co',
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_vsXMWCP8igeSQZ-T-OfDcg_cKZe-WTc',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
