import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/health_report_model.dart';
import '../../services/report_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/report_charts.dart';
import '../../widgets/report_table.dart';
import '../../widgets/soft_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _tabIndex = 0; // 0 = weekly, 1 = monthly
  final ReportService _reportService = ReportService();

  HealthReportModel? _weeklyReport;
  HealthReportModel? _monthlyReport;

  bool _loading = false;
  String? _error;
  bool _sendingEmail = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReport());
  }

  /// Maps raw status strings from the API (on_track, below_target, info) to
  /// human-readable labels with emoji for display in the nutrition table.
  String _mapNutritionStatus(String status) {
    switch (status) {
      case 'on_track':
        return '\u2705 On Track';
      case 'below_target':
        return '\u26A0\uFE0F Below';
      case 'info':
        return '\u2014';
      default:
        return status;
    }
  }

  String get _currentType => _tabIndex == 0 ? 'weekly' : 'monthly';

  HealthReportModel? get _currentReport =>
      _tabIndex == 0 ? _weeklyReport : _monthlyReport;

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final report = await _reportService.fetchReport(type: _currentType);
      if (!mounted) return;
      setState(() {
        if (_tabIndex == 0) {
          _weeklyReport = report;
        } else {
          _monthlyReport = report;
        }
        _loading = false;
      });
    } on ReportException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _shareReport() async {
    final report = _currentReport;
    if (report == null) return;

    final buffer = StringBuffer();
    buffer.writeln('REPGATE ${report.isWeekly ? "Weekly" : "Monthly"} Report');
    buffer.writeln(report.header.dateRange.isNotEmpty
        ? report.header.dateRange
        : report.header.monthLabel ?? '');
    buffer.writeln('');
    buffer.writeln(
        'Push-up Days: ${report.topStats.pushupDays}/${report.topStats.pushupDaysTotal}');
    buffer.writeln('Total Reps: ${report.topStats.totalReps}');
    buffer.writeln(
        'Avg Calories: ${report.topStats.avgCaloriesPerDay.toStringAsFixed(0)} kcal');
    buffer.writeln(
        'Avg Protein: ${report.topStats.avgProteinPerDay.toStringAsFixed(0)}g');
    buffer.writeln('');
    if (report.insight.isNotEmpty) {
      buffer.writeln('Insight: ${report.insight}');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report copied to clipboard')),
    );
  }

  Future<void> _sendEmail() async {
    setState(() => _sendingEmail = true);
    try {
      await _reportService.sendReportToEmail(type: _currentType);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent to your email')),
      );
    } on ReportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadReport,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              // --- Header bar ---
              Padding(
                padding: AppSpacing.page,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reports',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.email_outlined,
                      bordered: true,
                      onTap: _sendingEmail ? null : _sendEmail,
                    ),
                    const SizedBox(width: 10),
                    CircleIconButton(
                      icon: Icons.copy_rounded,
                      bordered: true,
                      onTap: _currentReport != null ? _shareReport : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // --- Tab toggle ---
              Padding(
                padding: AppSpacing.page,
                child: SegmentedToggle(
                  options: const ['Weekly', 'Monthly'],
                  selectedIndex: _tabIndex,
                  onChanged: (i) {
                    setState(() => _tabIndex = i);
                    // Load if not yet fetched
                    if (_currentReport == null) _loadReport();
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // --- Content ---
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _buildErrorState()
              else if (_currentReport != null)
                _buildReport(_currentReport!)
              else
                _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: AppSpacing.page,
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.error_outline_rounded, size: 48, color: AppColors.grey300),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          PillButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            variant: PillVariant.outline,
            expand: false,
            onPressed: _loadReport,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: AppSpacing.page,
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.bar_chart_rounded, size: 48, color: AppColors.grey300),
          const SizedBox(height: 16),
          Text(
            'No report available yet.\nLog your meals and push-ups to generate a report.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          PillButton(
            label: 'Generate Report',
            icon: Icons.auto_awesome_rounded,
            variant: PillVariant.dark,
            expand: false,
            onPressed: _loadReport,
          ),
        ],
      ),
    );
  }

  Widget _buildReport(HealthReportModel report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Report Header ---
        _buildReportHeader(report),
        const SizedBox(height: AppSpacing.xl),

        // --- Top Stats ---
        _buildTopStats(report),
        const SizedBox(height: AppSpacing.xl),

        // --- Section: Nutrition & Trends ---
        Padding(
          padding: AppSpacing.page,
          child: SectionHeader(title: 'Nutrition & Trends'),
        ),

        // --- Nutrition Summary Table ---
        if (report.nutritionSummary.isNotEmpty) ...[
          Padding(
            padding: AppSpacing.page,
            child: SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nutrition Summary',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ReportTable(
                    headers: const ['Metric', 'Avg', 'Target', 'Status'],
                    columnFlex: const [3, 2, 2, 2],
                    rows: report.nutritionSummary
                        .map((r) => [
                              r.metric,
                              r.dailyAverage,
                              r.target,
                              _mapNutritionStatus(r.status),
                            ])
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // --- Calorie & Protein Trend Chart ---
        if (report.dailyTrends.isNotEmpty) ...[
          Padding(
            padding: AppSpacing.page,
            child: SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.isWeekly
                        ? 'Daily Calorie & Protein Trend'
                        : 'Weekly Comparison - Calories & Protein',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  CalorieProteinBarChart(
                    labels: report.dailyTrends.map((d) {
                      if (d.date.length >= 10) {
                        try {
                          final dt = DateTime.parse(d.date);
                          return DateFormat('E').format(dt).substring(0, 3);
                        } catch (_) {}
                      }
                      return d.date.length > 3
                          ? d.date.substring(0, 3)
                          : d.date;
                    }).toList(),
                    calorieValues:
                        report.dailyTrends.map((d) => d.calories).toList(),
                    proteinValues:
                        report.dailyTrends.map((d) => d.protein).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // --- Monthly: Weekly Comparison - Push-up Days ---
        if (report.isMonthly && report.weeklyBreakdown.isNotEmpty) ...[
          Padding(
            padding: AppSpacing.page,
            child: SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Comparison - Push-up Days',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  PushupDaysChart(
                    labels: report.weeklyBreakdown
                        .map((w) => w.label)
                        .toList(),
                    values: report.weeklyBreakdown
                        .map((w) => w.pushupDays)
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // --- Monthly: Weekly Breakdown Table ---
        if (report.isMonthly && report.weeklyBreakdown.isNotEmpty) ...[
          Padding(
            padding: AppSpacing.page,
            child: SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Breakdown',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ReportTable(
                    headers: const [
                      'Week',
                      'Avg Cal',
                      'Avg Protein',
                      'Push-up Days',
                      'Water'
                    ],
                    columnFlex: const [2, 2, 2, 2, 2],
                    rows: report.weeklyBreakdown
                        .map((w) => [
                              w.label,
                              w.avgCalories.toStringAsFixed(0),
                              '${w.avgProtein.toStringAsFixed(0)}g',
                              '${w.pushupDays}',
                              '${(w.avgWaterMl / 1000).toStringAsFixed(1)}L',
                            ])
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // --- Push-up Discipline Log ---
        if (report.pushupLog.isNotEmpty) ...[
          Padding(
            padding: AppSpacing.page,
            child: SectionHeader(title: 'Discipline'),
          ),
          Padding(
            padding: AppSpacing.page,
            child: SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Push-up Discipline Log',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ReportTable(
                    headers: const ['Day', 'Completed', 'Reps', 'Fine'],
                    columnFlex: const [3, 2, 2, 2],
                    rows: report.pushupLog.map((entry) {
                      String dayLabel = entry.date;
                      if (entry.date.length >= 10) {
                        try {
                          final dt = DateTime.parse(entry.date);
                          dayLabel = DateFormat('E, MMM d').format(dt);
                        } catch (_) {}
                      }
                      return [
                        dayLabel,
                        entry.completed ? 'Yes' : 'No',
                        '${entry.reps}',
                        entry.fineAmountPaise > 0
                            ? '\u20B9${(entry.fineAmountPaise / 100).toStringAsFixed(0)}'
                            : '-',
                      ];
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // --- Most Logged Foods ---
        if (report.mostLoggedFoods.isNotEmpty) ...[
          Padding(
            padding: AppSpacing.page,
            child: SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.isWeekly
                        ? 'Most Logged Foods This Week'
                        : 'Most Logged Foods This Month',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ReportTable(
                    headers: const ['Food', 'Freq', 'Calories', 'Protein'],
                    columnFlex: const [4, 1, 2, 2],
                    rows: report.mostLoggedFoods
                        .map((f) => [
                              f.name,
                              '${f.frequency}',
                              '${f.calories.toStringAsFixed(0)}',
                              '${f.protein.toStringAsFixed(0)}g',
                            ])
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // --- Monthly: Discipline Summary ---
        if (report.isMonthly && report.disciplineSummary != null) ...[
          _buildDisciplineSummary(report.disciplineSummary!),
          const SizedBox(height: AppSpacing.xl),
        ],

        // --- Progress Summary ---
        _buildProgressSummary(report),
        const SizedBox(height: AppSpacing.xl),

        // --- AI Insight ---
        if (report.insight.isNotEmpty) ...[
          Padding(
            padding: AppSpacing.page,
            child: SoftCard(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkCard
                  : AppColors.limeSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: AppColors.limeDeep,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        report.isWeekly ? 'Weekly Insight' : 'Monthly Insight',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report.insight,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // --- Footer Disclaimer ---
        Padding(
          padding: AppSpacing.page,
          child: Text(
            report.footer,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.grey500,
                  height: 1.5,
                ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildReportHeader(HealthReportModel report) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: AppSpacing.page,
      child: SoftCard(
        color: isDark ? AppColors.darkCard : AppColors.ink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REPGATE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppColors.limeBright,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              report.isWeekly ? 'Weekly Health Report' : 'Monthly Health Report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              report.header.dateRange.isNotEmpty
                  ? report.header.dateRange
                  : report.header.monthLabel ?? '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.grey300,
              ),
            ),
            if (report.header.userName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                report.header.userName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopStats(HealthReportModel report) {
    final stats = report.topStats;
    return Padding(
      padding: AppSpacing.page,
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              emoji: '💪',
              value: report.isMonthly && stats.currentStreak != null
                  ? '${stats.currentStreak}'
                  : '${stats.pushupDays}/${stats.pushupDaysTotal}',
              label: report.isMonthly ? 'Streak' : 'Push-up days',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatChip(
              emoji: '🏋️',
              value: '${stats.totalReps}',
              label: 'Total reps',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatChip(
              emoji: '🔥',
              value: stats.avgCaloriesPerDay.toStringAsFixed(0),
              label: 'Avg kcal',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatChip(
              emoji: '🥩',
              value: '${stats.avgProteinPerDay.toStringAsFixed(0)}g',
              label: 'Avg protein',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisciplineSummary(DisciplineSummary disc) {
    return Padding(
      padding: AppSpacing.page,
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discipline Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            _InfoRow(label: 'Total push-up reps', value: '${disc.totalReps}'),
            _InfoRow(label: 'Current streak', value: '${disc.currentStreak} days'),
            _InfoRow(
                label: 'Longest streak this month',
                value: '${disc.longestStreakThisMonth} days'),
            _InfoRow(
                label: 'Missed days (fine paid)',
                value: '${disc.missedDays}'),
            _InfoRow(
              label: 'Total fines paid',
              value:
                  '\u20B9${(disc.totalFinesPaise / 100).toStringAsFixed(0)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummary(HealthReportModel report) {
    final prog = report.progressSummary;
    final hasWeight = prog.startingWeight > 0 || prog.currentWeight > 0;

    return Padding(
      padding: AppSpacing.page,
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            if (hasWeight) ...[
              _InfoRow(
                label: 'Starting weight',
                value: '${prog.startingWeight.toStringAsFixed(1)} kg',
              ),
              _InfoRow(
                label: 'Current weight',
                value: '${prog.currentWeight.toStringAsFixed(1)} kg',
              ),
              _InfoRow(
                label: report.isWeekly
                    ? 'Change this week'
                    : 'Change this month',
                value:
                    '${prog.weightChange >= 0 ? "+" : ""}${prog.weightChange.toStringAsFixed(1)} kg',
              ),
            ],
            if (!report.isMonthly) ...[
              _InfoRow(
                  label: 'Current streak',
                  value: '${prog.currentStreak} days'),
              _InfoRow(
                  label: 'Longest streak',
                  value: '${prog.longestStreak} days'),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small stat chip used in the top-stats row.
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A key-value row in summary sections.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey500,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
