/// A meal the coach recommends, rendered as a card under its reply.
class MealSuggestion {
  const MealSuggestion({
    required this.name,
    required this.protein,
    required this.calories,
    required this.note,
  });

  final String name;
  final double protein;
  final double calories;

  /// Short portion hint, e.g. "1 katori" or "100 g".
  final String note;

  factory MealSuggestion.fromMap(Map<String, dynamic> map) => MealSuggestion(
        name: map['name'] as String? ?? '',
        protein: (map['protein'] as num?)?.toDouble() ?? 0,
        calories: (map['calories'] as num?)?.toDouble() ?? 0,
        note: map['note'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'protein': protein,
        'calories': calories,
        'note': note,
      };
}

enum CoachRole { user, model }

class CoachMessage {
  CoachMessage({
    required this.role,
    required this.text,
    this.suggestions = const [],
    DateTime? createdAt,
    this.isPending = false,
    this.hasFailed = false,
  }) : createdAt = createdAt ?? DateTime.now();

  final CoachRole role;
  final String text;
  final List<MealSuggestion> suggestions;
  final DateTime createdAt;

  /// True while the coach is still composing this reply, so the UI can show a
  /// typing indicator in the message's own place in the list rather than
  /// bolting a separate spinner onto the screen.
  final bool isPending;

  /// Set when the send failed, which lets the bubble offer a retry instead of
  /// silently dropping what the user typed.
  final bool hasFailed;

  bool get isUser => role == CoachRole.user;

  factory CoachMessage.fromMap(Map<String, dynamic> map) => CoachMessage(
        role: map['role'] == 'model' ? CoachRole.model : CoachRole.user,
        text: map['text'] as String? ?? '',
        suggestions: ((map['suggestions'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => MealSuggestion.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList(),
        createdAt:
            DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal(),
      );

  CoachMessage copyWith({
    String? text,
    List<MealSuggestion>? suggestions,
    bool? isPending,
    bool? hasFailed,
  }) =>
      CoachMessage(
        role: role,
        text: text ?? this.text,
        suggestions: suggestions ?? this.suggestions,
        createdAt: createdAt,
        isPending: isPending ?? this.isPending,
        hasFailed: hasFailed ?? this.hasFailed,
      );
}

/// One turn of the conversation as sent back to the model for continuity.
class CoachTurn {
  const CoachTurn({required this.role, required this.text});

  final CoachRole role;
  final String text;

  Map<String, dynamic> toMap() => {
        'role': role == CoachRole.model ? 'model' : 'user',
        'text': text,
      };
}
