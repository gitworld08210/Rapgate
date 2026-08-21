import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../models/app_settings_model.dart';

/// Fetches and updates admin-configurable app settings stored in the
/// `app_settings` table via Edge Functions.
class AppSettingsService {
  AppSettingsService({SupabaseClient? client}) : _db = client ?? supabase;

  final SupabaseClient _db;

  /// In-memory cache so repeat reads within the same session are instant.
  AppSettings? _cached;

  /// Returns the current app settings from the server.
  ///
  /// The result is cached after the first successful fetch; pass
  /// [forceRefresh] to bypass the cache.
  Future<AppSettings> getSettings({bool forceRefresh = false}) async {
    if (_cached != null && !forceRefresh) return _cached!;

    final response = await _db.functions.invoke('get-app-settings');
    if (response.status >= 400) {
      final msg = (response.data as Map?)?['error']?.toString() ??
          'Could not load app settings.';
      throw AppSettingsException(msg);
    }

    final data = response.data as Map<String, dynamic>;
    _cached = AppSettings.fromMap(data);
    return _cached!;
  }

  /// Updates one or more settings fields. Only admins may call this
  /// (enforced server-side by `requireAdmin`).
  Future<AppSettings> updateSettings({
    String? upiId,
    String? upiPayeeName,
    int? fineAmountPaise,
  }) async {
    final body = <String, dynamic>{};
    if (upiId != null) body['upiId'] = upiId;
    if (upiPayeeName != null) body['upiPayeeName'] = upiPayeeName;
    if (fineAmountPaise != null) body['fineAmountPaise'] = fineAmountPaise;

    final response =
        await _db.functions.invoke('update-app-settings', body: body);
    if (response.status >= 400) {
      final msg = (response.data as Map?)?['error']?.toString() ??
          'Could not update app settings.';
      throw AppSettingsException(msg);
    }

    final data = response.data as Map<String, dynamic>;
    _cached = AppSettings.fromMap(data);
    return _cached!;
  }
}

/// User-presentable failure from the settings flow.
class AppSettingsException implements Exception {
  const AppSettingsException(this.message);
  final String message;

  @override
  String toString() => message;
}
