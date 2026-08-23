import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/health_summary_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';

class WeeklySummaryScreen extends StatefulWidget {
  const WeeklySummaryScreen({super.key});

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8FDF0),
              Color(0xFFFFFFFF),
              Color(0xFFF0F7FF),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: StreamBuilder<List<HealthSummaryModel>>(
            stream: context.read<DatabaseService>().streamHealthSummaries(uid),
            builder: (context, snapshot) {
              final summaries = snapshot.data ?? [];

              return FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      // Header
                      Padding(
                        padding: AppSpacing.page,
                        child: Row(
                          children: [
                            CircleIconButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              iconSize: 16,
                              bordered: true,
                              onTap: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Weekly Summaries',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                            ),
                            const Text('🧠',
                                style: TextStyle(fontSize: 24)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      Padding(
                        padding: AppSpacing.page,
                        child: Text(
                          'AI-powered insights from your health journey',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      if (summaries.isEmpty) _buildEmptyState(context),

                      for (int i = 0; i < summaries.length; i++) ...[
                        Padding(
                          padding: AppSpacing.page,
                          child: _SummaryGlassCard(
                            summary: summaries[i],
                            index: i,
                          ),
                        ),
                        if (i < summaries.length - 1)
                          const SizedBox(height: AppSpacing.lg),
                      ],

                      const SizedBox(height: AppSpacing.xxl),

                      // Motivational footer
                      if (summaries.isNotEmpty)
                        Padding(
                          padding: AppSpacing.page,
                          child: Center(
                            child: Column(
                              children: [
                                const Text('✨',
                                    style: TextStyle(fontSize: 28)),
                                const SizedBox(height: 8),
                                Text(
                                  'Every week is a new opportunity',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.grey500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: AppSpacing.page,
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          children: [
            const Text('📊', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            Text(
              'No summaries yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Your personalized AI health summary will appear here each week. Keep logging your meals, water, and push-ups!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGlassCard extends StatelessWidget {
  const _SummaryGlassCard({required this.summary, required this.index});

  final HealthSummaryModel summary;
  final int index;

  @override
  Widget build(BuildContext context) {
    final weekLabel = _formatWeekLabel(summary.weekStart);

    return ClipRRect(
      borderRadius: AppRadius.cardLg,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardLg,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.85),
                Colors.white.withOpacity(0.65),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.limeDeep.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Week label
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.limeSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      weekLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.limeDeep,
                          ),
                    ),
                  ),
                  const Spacer(),
                  if (index == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.limeBright, AppColors.limeDeep],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'LATEST',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.white,
                            ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Summary text
              Text(
                summary.summaryText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
              ),

              if (summary.insights.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Divider(height: 1, color: AppColors.grey200),
                const SizedBox(height: 16),

                // Insights
                ...summary.insights.asMap().entries.map((entry) {
                  final icons = ['💡', '🎯', '⚡'];
                  final icon =
                      entry.key < icons.length ? icons[entry.key] : '✦';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(icon, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatWeekLabel(DateTime weekStart) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekEnd = weekStart.add(const Duration(days: 6));
    if (weekStart.month == weekEnd.month) {
      return '${months[weekStart.month - 1]} ${weekStart.day} - ${weekEnd.day}';
    }
    return '${months[weekStart.month - 1]} ${weekStart.day} - ${months[weekEnd.month - 1]} ${weekEnd.day}';
  }
}
