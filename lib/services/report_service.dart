import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../models/health_report_model.dart';

/// Client for the `generate-health-report` and `send-health-report-email`
/// Edge Functions.
class ReportService {
  final SupabaseClient _db = supabase;

  /// Fetches a health report of the given [type] ('weekly' or 'monthly').
  ///
  /// Throws [ReportException] on any failure.
  Future<HealthReportModel> fetchReport({required String type}) async {
    try {
      final response = await _db.functions.invoke(
        'generate-health-report',
        body: {'type': type},
      );

      final raw = response.data;
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

      if (response.status == 401) {
        throw ReportException(
            'Your session has expired. Please sign in again.');
      }
      if (response.status >= 400) {
        throw ReportException(
          data['error']?.toString() ?? 'Could not generate the report.',
        );
      }

      return HealthReportModel.fromJson(data);
    } on ReportException {
      rethrow;
    } on FunctionException catch (error) {
      if (error.status == 401) {
        throw ReportException(
            'Your session has expired. Please sign in again.');
      }
      final details = error.details;
      if (details is Map && details['error'] is String) {
        throw ReportException(details['error'] as String);
      }
      throw ReportException('Could not generate the report. Please retry.');
    } catch (_) {
      throw ReportException(
        'Could not reach the server. Check your internet and try again.',
      );
    }
  }

  /// Sends the current report to the user's email address.
  ///
  /// Calls the `send-health-report-email` Edge Function which will render
  /// and deliver the report via email. Throws [ReportException] on failure.
  Future<void> sendReportToEmail({required String type}) async {
    try {
      final response = await _db.functions.invoke(
        'send-health-report-email',
        body: {'type': type},
      );

      final raw = response.data;
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

      if (response.status == 401) {
        throw ReportException(
            'Your session has expired. Please sign in again.');
      }
      if (response.status >= 400) {
        throw ReportException(
          data['error']?.toString() ?? 'Could not send the email.',
        );
      }
    } on ReportException {
      rethrow;
    } on FunctionException catch (error) {
      if (error.status == 401) {
        throw ReportException(
            'Your session has expired. Please sign in again.');
      }
      final details = error.details;
      if (details is Map && details['error'] is String) {
        throw ReportException(details['error'] as String);
      }
      throw ReportException('Could not send the email. Please retry.');
    } catch (_) {
      throw ReportException(
        'Could not reach the server. Check your internet and try again.',
      );
    }
  }
}

class ReportException implements Exception {
  ReportException(this.message);

  final String message;

  @override
  String toString() => message;
}
