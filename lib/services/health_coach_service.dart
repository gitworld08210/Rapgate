import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../models/coach_message_model.dart';

/// Client for the `chat-health-coach` Edge Function.
///
/// The function assembles the nutrition context server-side from the user's own
/// rows, so nothing about their intake is sent from the device and the model
/// cannot be fed forged numbers.
class HealthCoachService {
  final SupabaseClient _db = supabase;

  /// Turns sent back for continuity. The server also caps this, but trimming
  /// here keeps the request small on mobile data.
  static const _historyTurns = 8;

  Future<CoachReply> send({
    required String message,
    required List<CoachMessage> history,
  }) async {
    // Pending and failed bubbles are UI state, not part of the conversation.
    final turns = history
        .where((m) => !m.isPending && !m.hasFailed && m.text.isNotEmpty)
        .map((m) => CoachTurn(role: m.role, text: m.text))
        .toList();
    final recent = turns.length > _historyTurns
        ? turns.sublist(turns.length - _historyTurns)
        : turns;

    try {
      final response = await _db.functions.invoke(
        'chat-health-coach',
        body: {
          'message': message,
          'history': recent.map((t) => t.toMap()).toList(),
        },
      );

      final raw = response.data;
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

      if (response.status == 401) {
        throw CoachException('Your session has expired. Please sign in again.');
      }
      if (response.status >= 400) {
        throw CoachException(
          data['error']?.toString() ?? 'The coach could not answer.',
        );
      }

      final reply = data['reply']?.toString().trim() ?? '';
      if (reply.isEmpty) {
        throw CoachException('The coach returned an empty answer.');
      }

      return CoachReply(
        reply: reply,
        suggestions: ((data['suggestions'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) =>
                MealSuggestion.fromMap(Map<String, dynamic>.from(item)))
            .toList(),
      );
    } on CoachException {
      rethrow;
    } on FunctionException catch (error) {
      if (error.status == 401) {
        throw CoachException('Your session has expired. Please sign in again.');
      }
      final details = error.details;
      if (details is Map && details['error'] is String) {
        throw CoachException(details['error'] as String);
      }
      throw CoachException('The coach could not answer. Please retry.');
    } catch (_) {
      throw CoachException(
        'Could not reach the coach. Check your internet and try again.',
      );
    }
  }

  /// Loads the stored conversation, oldest first.
  Future<List<CoachMessage>> loadHistory(String uid, {int limit = 50}) async {
    final rows = await _db
        .from('coach_messages')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .map<CoachMessage>(
            (row) => CoachMessage.fromMap(Map<String, dynamic>.from(row)))
        .toList()
        .reversed
        .toList();
  }

  Future<void> clearHistory(String uid) async {
    await _db.from('coach_messages').delete().eq('user_id', uid);
  }
}

class CoachReply {
  const CoachReply({required this.reply, required this.suggestions});

  final String reply;
  final List<MealSuggestion> suggestions;
}

class CoachException implements Exception {
  CoachException(this.message);

  final String message;

  @override
  String toString() => message;
}
