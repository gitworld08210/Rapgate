/// Supabase runtime configuration.
///
/// Pass these values when building the app:
/// flutter build apk --release \
///   --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<publishable-anon-key> \
///   --dart-define=CLOUDINARY_CLOUD_NAME=<your-cloud> \
///   --dart-define=CLOUDINARY_UPLOAD_PRESET=rapgate-dataset
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
