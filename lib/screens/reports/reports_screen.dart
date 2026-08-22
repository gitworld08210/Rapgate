import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/health_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/food_log_model.dart';
import '../../models/pushup_session_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/macro_widgets.dart';
import '../../widgets/stat_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _range = 0; // 0 = week, 1 = month

  List<FoodLogModel> _foodLogs = [];
  List<PushupSessionModel> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final uid = context.read<AuthService>().uid;
    if (uid == null) return;
    final firestore = context.read<FirestoreService>();

    setState(() => _loading = true);

    final now = DateTime.now();
    final days = _range == 0 ? 7 : 30;
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));

    try {
      final results = await Future.wait([
        firestore.getFoodLogsForRange(uid, start, end),
        firestore.getPushupSessionsForRange(uid, start, end),
      ]);
      if (!mounted) return;
      setState(() {
        _foodLogs = results[0] as List<FoodLogModel>;
        _sessions = results[1] as List<PushupSessionModel>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().userModel;
    final streaks = context.watch<UserProvider>().streaks;
    final health = context.watch<HealthProvider>();

    final days = _range == 0 ? 7 : 30;
    // `double` annotations required so `calorieTarget * 1.25` stays `double`
    // for GradientBarChart.maxValue (a `num` would not be assignable).
    final double calorieTarget = user?.dailyCalorieTarget ?? 2000;
    final double proteinTarget = user?.dailyProteinTarget ?? 100;

    final dailyCalories = _bucketByDay(days, (log) => log.totalCalories);
    final dailyProtein = _bucketByDay(days, (log) => log.totalProtein);

    final loggedDays = dailyCalories.where((c) => c > 0).length;
    final avgCalories = loggedDays == 0
        ? 0.0
        : dailyCalories.reduce((a, b) => a + b) / loggedDays;
    final avgProtein = loggedDays == 0
        ? 0.0
        : dailyProtein.reduce((a, b) => a + b) / loggedDays;

    final verifiedDays = _verifiedPushupDays();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              Padding(
                padding: AppSpacing.page,
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Statistics',
                          style:
                              Theme.of(context).textTheme.headlineMedium),
                    ),
                    CircleIconButton(
                      icon: Icons.more_horiz_rounded,
                      bordered: true,
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ---------- Range toggle ----------
              Padding(
                padding: AppSpacing.page,
                child: SegmentedToggle(
                  options: const ['This week', 'This month'],
                  selectedIndex: _range,
                  onChanged: (i) {
                    setState(() => _range = i);
                    _load();
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                // ---------- Calories bar chart ----------
                Padding(
                  padding: AppSpacing.page,
                  child: SoftCard(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🔥',
                                style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              avgCalories.toStringAsFixed(0),
                              style:
                                  Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('kcal avg',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                            ),
                            const Spacer(),
                            Text(
                              'Target ${calorieTarget.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        GradientBarChart(
                          values: dailyCalories,
                          labels: _range == 0
                              ? _dayLabels(7)
                              : _monthDayLabels(30),
                          activeIndex: dailyCalories.length - 1,
                          maxValue: calorieTarget * 1.25,
                          tooltipLabel:
                              '${dailyCalories.last.toStringAsFixed(0)}',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ---------- Averages ----------
                Padding(
                  padding: AppSpacing.page,
                  child: Row(
                    children: [
                      Expanded(
                        child: QuickStatTile(
                          label: 'Avg protein',
                          value: avgProtein.toStringAsFixed(0),
                          unit: 'g',
                          icon: Icons.egg_alt_rounded,
                          tint: AppColors.protein,
                          progress: proteinTarget <= 0
                              ? 0
                              : avgProtein / proteinTarget,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: QuickStatTile(
                          label: 'Days logged',
                          value: '$loggedDays',
                          unit: '/ $days',
                          icon: Icons.event_available_rounded,
                          tint: AppColors.limeDeep,
                          progress: loggedDays / days,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ---------- Streaks ----------
                Padding(
                  padding: AppSpacing.page,
                  child: SoftCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: _streakStat(
                            context,
                            '🔥',
                            '${streaks?.currentPushupStreak ?? 0}',
                            'Current streak',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 42,
                          color: AppColors.grey200,
                        ),
                        Expanded(
                          child: _streakStat(
                            context,
                            '🏆',
                            '${streaks?.longestPushupStreak ?? 0}',
                            'Longest streak',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 42,
                          color: AppColors.grey200,
                        ),
                        Expanded(
                          child: _streakStat(
                            context,
                            '🍽️',
                            '${streaks?.currentFoodLogStreak ?? 0}',
                            'Food log',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ---------- Push-up heatmap ----------
                Padding(
                  padding: AppSpacing.page,
                  child: SectionHeader(title: 'Push-up consistency'),
                ),
                Padding(
                  padding: AppSpacing.page,
                  child: SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heatmap(
                          days: _range == 0 ? 7 : 30,
                          completedDays: verifiedDays,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _legendDot(AppColors.limeBright, 'Verified'),
                            const SizedBox(width: 14),
                            _legendDot(AppColors.grey200, 'Missed'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ---------- Pending fines ----------
                if (health.outstandingFines.isNotEmpty)
                  Padding(
                    padding: AppSpacing.page,
                    child: SoftCard(
                      color: AppColors.pastelPink,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.gavel_rounded,
                                color: AppColors.danger, size: 21),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${health.outstandingFines.length} pending fine${health.outstandingFines.length == 1 ? '' : 's'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${(health.totalOutstandingFineAmount / 100).toStringAsFixed(0)} total',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _streakStat(
      BuildContext context, String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 19)),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  /// Sum a food-log field per day over the last [days] days (oldest first).
  List<double> _bucketByDay(int days, double Function(FoodLogModel) extract) {
    final now = DateTime.now();
    final buckets = List<double>.filled(days, 0);

    for (final log in _foodLogs) {
      final logDay = DateTime(
          log.loggedAt.year, log.loggedAt.month, log.loggedAt.day);
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(logDay).inDays;
      final idx = days - 1 - diff;
      if (idx >= 0 && idx < days) buckets[idx] += extract(log);
    }
    return buckets;
  }

  /// Set of day-offsets (0 = today) that have a verified push-up session.
  Set<int> _verifiedPushupDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <int>{};

    for (final s in _sessions) {
      if (s.status != PushupSessionStatus.verified) continue;
      final d = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
      result.add(today.difference(d).inDays);
    }
    return result;
  }

  List<String> _dayLabels(int count) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      final d = now.subtract(Duration(days: count - 1 - i));
      return DateFormat('E').format(d).substring(0, 1);
    });
  }

  /// Labels for 30-day view: show day number every 5th day, empty otherwise.
  List<String> _monthDayLabels(int count) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      final d = now.subtract(Duration(days: count - 1 - i));
      // Show label every 5th position and always the last day
      if (i % 5 == 0 || i == count - 1) {
        return '${d.day}';
      }
      return '';
    });
  }
}

/// Calendar-style heatmap of completed days.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.days, required this.completedDays});

  final int days;

  /// Day offsets from today (0 = today) that were completed.
  final Set<int> completedDays;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(days, (i) {
        // Oldest first
        final offset = days - 1 - i;
        final done = completedDays.contains(offset);
        final date = DateTime.now().subtract(Duration(days: offset));

        return Tooltip(
          message: DateFormat('d MMM').format(date),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: done ? AppColors.limeBright : AppColors.grey100,
              borderRadius: BorderRadius.circular(8),
              border: offset == 0
                  ? Border.all(color: AppColors.ink, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: done ? AppColors.ink : AppColors.grey500,
              ),
            ),
          ),
        );
      }),
    );
  }
}
