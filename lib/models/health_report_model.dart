/// Data model representing a generated health report (weekly or monthly).
///
/// Parses the structured JSON returned by the `generate-health-report`
/// Edge Function into strongly-typed Dart objects.
class HealthReportModel {
  const HealthReportModel({
    required this.type,
    required this.header,
    required this.topStats,
    required this.nutritionSummary,
    required this.dailyTrends,
    required this.pushupLog,
    required this.mostLoggedFoods,
    required this.progressSummary,
    required this.weeklyBreakdown,
    required this.disciplineSummary,
    required this.insight,
    required this.footer,
  });

  final String type; // 'weekly' | 'monthly'
  final ReportHeader header;
  final ReportTopStats topStats;
  final List<NutritionRow> nutritionSummary;
  final List<DailyTrend> dailyTrends;
  final List<PushupLogEntry> pushupLog;
  final List<MostLoggedFood> mostLoggedFoods;
  final ReportProgressSummary progressSummary;
  final List<WeeklyBreakdownRow> weeklyBreakdown; // monthly only
  final DisciplineSummary? disciplineSummary; // monthly only
  final String insight;
  final String footer;

  bool get isWeekly => type == 'weekly';
  bool get isMonthly => type == 'monthly';

  factory HealthReportModel.fromJson(Map<String, dynamic> json) {
    return HealthReportModel(
      type: json['type'] as String? ?? 'weekly',
      header: ReportHeader.fromJson(
        Map<String, dynamic>.from(json['header'] as Map? ?? {}),
      ),
      topStats: ReportTopStats.fromJson(
        Map<String, dynamic>.from(json['top_stats'] as Map? ?? {}),
      ),
      nutritionSummary: ((json['nutrition_summary'] as List?) ?? [])
          .map((e) => NutritionRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      dailyTrends: ((json['daily_trends'] as List?) ?? [])
          .map((e) => DailyTrend.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      pushupLog: ((json['pushup_log'] as List?) ?? [])
          .map(
              (e) => PushupLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      mostLoggedFoods: ((json['most_logged_foods'] as List?) ?? [])
          .map((e) =>
              MostLoggedFood.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      progressSummary: ReportProgressSummary.fromJson(
        Map<String, dynamic>.from(json['progress_summary'] as Map? ?? {}),
      ),
      weeklyBreakdown: ((json['weekly_breakdown'] as List?) ?? [])
          .map((e) =>
              WeeklyBreakdownRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      disciplineSummary: json['discipline_summary'] != null
          ? DisciplineSummary.fromJson(
              Map<String, dynamic>.from(json['discipline_summary'] as Map))
          : null,
      insight: json['insight'] as String? ?? '',
      footer: json['footer'] as String? ??
          'Nutrition values are AI-estimated from food photos and are not a substitute for medical or dietetic advice. Generated automatically by Repgate.',
    );
  }
}

class ReportHeader {
  const ReportHeader({
    required this.dateRange,
    required this.startDate,
    required this.endDate,
    required this.userName,
    this.monthLabel,
  });

  final String dateRange;
  final String startDate;
  final String endDate;
  final String userName;
  final String? monthLabel; // monthly only

  factory ReportHeader.fromJson(Map<String, dynamic> json) {
    return ReportHeader(
      dateRange: json['date_range'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
      monthLabel: json['month_label'] as String?,
    );
  }
}

class ReportTopStats {
  const ReportTopStats({
    required this.pushupDays,
    required this.pushupDaysTotal,
    required this.totalReps,
    required this.avgCaloriesPerDay,
    required this.avgProteinPerDay,
    this.currentStreak,
  });

  final int pushupDays;
  final int pushupDaysTotal;
  final int totalReps;
  final double avgCaloriesPerDay;
  final double avgProteinPerDay;
  final int? currentStreak; // monthly only

  factory ReportTopStats.fromJson(Map<String, dynamic> json) {
    final pushupDaysRaw = json['pushup_days'];
    int days = 0;
    int total = 7;
    if (pushupDaysRaw is Map) {
      days = (pushupDaysRaw['value'] as num?)?.toInt() ?? 0;
      total = (pushupDaysRaw['total'] as num?)?.toInt() ?? 7;
    }

    return ReportTopStats(
      pushupDays: days,
      pushupDaysTotal: total,
      totalReps: (json['total_reps'] as num?)?.toInt() ?? 0,
      avgCaloriesPerDay:
          (json['avg_calories_per_day'] as num?)?.toDouble() ?? 0,
      avgProteinPerDay:
          (json['avg_protein_per_day'] as num?)?.toDouble() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt(),
    );
  }
}

class NutritionRow {
  const NutritionRow({
    required this.metric,
    required this.dailyAverage,
    required this.target,
    required this.status,
  });

  final String metric;
  final String dailyAverage;
  final String target;
  final String status;

  factory NutritionRow.fromJson(Map<String, dynamic> json) {
    return NutritionRow(
      metric: json['metric'] as String? ?? '',
      dailyAverage: _stringify(json['daily_average']),
      target: _stringify(json['target']),
      status: json['status'] as String? ?? '',
    );
  }
}

class DailyTrend {
  const DailyTrend({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.waterMl,
  });

  final String date;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double waterMl;

  factory DailyTrend.fromJson(Map<String, dynamic> json) {
    return DailyTrend(
      date: json['date'] as String? ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      waterMl: (json['water_ml'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PushupLogEntry {
  const PushupLogEntry({
    required this.date,
    required this.completed,
    required this.reps,
    required this.fineAmountPaise,
  });

  final String date;
  final bool completed;
  final int reps;
  final int fineAmountPaise;

  factory PushupLogEntry.fromJson(Map<String, dynamic> json) {
    return PushupLogEntry(
      date: json['date'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      fineAmountPaise: (json['fine_amount_paise'] as num?)?.toInt() ?? 0,
    );
  }
}

class MostLoggedFood {
  const MostLoggedFood({
    required this.name,
    required this.frequency,
    required this.calories,
    required this.protein,
  });

  final String name;
  final int frequency;
  final double calories;
  final double protein;

  factory MostLoggedFood.fromJson(Map<String, dynamic> json) {
    return MostLoggedFood(
      name: json['name'] as String? ?? '',
      frequency: (json['frequency'] as num?)?.toInt() ?? 0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReportProgressSummary {
  const ReportProgressSummary({
    required this.startingWeight,
    required this.currentWeight,
    required this.weightChange,
    required this.currentStreak,
    required this.longestStreak,
  });

  final double startingWeight;
  final double currentWeight;
  final double weightChange;
  final int currentStreak;
  final int longestStreak;

  factory ReportProgressSummary.fromJson(Map<String, dynamic> json) {
    return ReportProgressSummary(
      startingWeight: (json['starting_weight'] as num?)?.toDouble() ?? 0,
      currentWeight: (json['current_weight'] as num?)?.toDouble() ?? 0,
      weightChange: (json['weight_change'] as num?)?.toDouble() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
    );
  }
}

class WeeklyBreakdownRow {
  const WeeklyBreakdownRow({
    required this.label,
    required this.avgCalories,
    required this.avgProtein,
    required this.pushupDays,
    required this.avgWaterMl,
  });

  final String label;
  final double avgCalories;
  final double avgProtein;
  final int pushupDays;
  final double avgWaterMl;

  factory WeeklyBreakdownRow.fromJson(Map<String, dynamic> json) {
    return WeeklyBreakdownRow(
      label: json['label'] as String? ?? '',
      avgCalories: (json['avg_calories'] as num?)?.toDouble() ?? 0,
      avgProtein: (json['avg_protein'] as num?)?.toDouble() ?? 0,
      pushupDays: (json['pushup_days'] as num?)?.toInt() ?? 0,
      avgWaterMl: (json['avg_water_ml'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DisciplineSummary {
  const DisciplineSummary({
    required this.totalReps,
    required this.currentStreak,
    required this.longestStreakThisMonth,
    required this.missedDays,
    required this.totalFinesPaise,
  });

  final int totalReps;
  final int currentStreak;
  final int longestStreakThisMonth;
  final int missedDays;
  final int totalFinesPaise;

  factory DisciplineSummary.fromJson(Map<String, dynamic> json) {
    return DisciplineSummary(
      totalReps: (json['total_reps'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreakThisMonth:
          (json['longest_streak_this_month'] as num?)?.toInt() ?? 0,
      missedDays: (json['missed_days'] as num?)?.toInt() ?? 0,
      totalFinesPaise: (json['total_fines_paise'] as num?)?.toInt() ?? 0,
    );
  }
}

String _stringify(dynamic value) {
  if (value == null) return '-';
  if (value is String) return value;
  if (value is num) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
  return value.toString();
}
