import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/health_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/stat_chart.dart';

class WeightScreen extends StatelessWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final user = context.watch<UserProvider>().userModel;

    // Oldest → newest for the chart
    final logs = health.weightLogs.reversed.toList();
    // `double` annotation required: `(user?.weight ?? 0)` infers as `num`.
    final double current =
        logs.isNotEmpty ? logs.last.weightKg : (user?.weight ?? 0);
    final double start = logs.isNotEmpty ? logs.first.weightKg : current;
    final double delta = current - start;

    final bmi = (user?.height ?? 0) > 0
        ? calculateBMI(current, user!.height)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 16,
            bordered: true,
            onTap: () => Navigator.pop(context),
          ),
        ),
        leadingWidth: 74,
        title: const Text('Weight Progress'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ---------- Current weight + trend ----------
          SoftCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current weight',
                              style:
                                  Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(current.toStringAsFixed(1),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium),
                              Text(' kg',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (logs.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: delta <= 0
                              ? AppColors.limeSoft
                              : AppColors.pastelOrange,
                          borderRadius: AppRadius.chip,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              delta <= 0
                                  ? Icons.trending_down_rounded
                                  : Icons.trending_up_rounded,
                              size: 15,
                              color: delta <= 0
                                  ? AppColors.limeDeep
                                  : AppColors.burned,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: delta <= 0
                                    ? AppColors.limeDeep
                                    : AppColors.burned,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                MiniLineChart(values: logs.map((l) => l.weightKg).toList()),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ---------- BMI ----------
          if (bmi > 0)
            SoftCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.protein.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.straighten_rounded,
                        color: AppColors.protein, size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BMI',
                            style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 2),
                        Text(
                          '${bmi.toStringAsFixed(1)}  ·  ${getBMICategory(bmi)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.lg),

          PillButton(
            label: 'Log today\'s weight',
            icon: Icons.add_rounded,
            onPressed: () => _showLogSheet(context, current),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ---------- History ----------
          SectionHeader(title: 'History'),
          if (health.weightLogs.isEmpty)
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Text('⚖️', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text('No entries yet',
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            )
          else
            SoftCard(
              child: Column(
                children: [
                  for (var i = 0; i < health.weightLogs.length; i++) ...[
                    if (i > 0) const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatDate(health.weightLogs[i].loggedAt),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          formatWeight(health.weightLogs[i].weightKg),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showLogSheet(BuildContext context, double current) {
    final controller =
        TextEditingController(text: current.toStringAsFixed(1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 22,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Log weight',
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext).textTheme.displayMedium,
              decoration: const InputDecoration(suffixText: 'kg'),
            ),
            const SizedBox(height: 22),
            PillButton(
              label: 'Save',
              onPressed: () async {
                final value = double.tryParse(controller.text);
                if (value == null || value <= 0 || value > 500) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(content: Text('Enter a valid weight')),
                  );
                  return;
                }
                await context.read<HealthProvider>().addWeight(value);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }
}
