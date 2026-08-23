class HealthSummaryModel {
  final String id;
  final DateTime weekStart;
  final String summaryText;
  final List<String> insights;
  final DateTime createdAt;

  HealthSummaryModel({
    required this.id,
    required this.weekStart,
    required this.summaryText,
    required this.insights,
    required this.createdAt,
  });

  factory HealthSummaryModel.fromMap(String id, Map<String, dynamic> data) =>
      HealthSummaryModel(
        id: id,
        weekStart: DateTime.tryParse(data['week_start']?.toString() ?? '') ??
            DateTime.now(),
        summaryText: data['summary_text'] as String? ?? '',
        insights: ((data['insights'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'week_start': weekStart.toIso8601String().split('T')[0],
        'summary_text': summaryText,
        'insights': insights,
      };
}
