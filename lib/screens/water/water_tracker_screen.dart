import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/health_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/macro_widgets.dart';
import '../../widgets/animated_counter.dart';

class WaterTrackerScreen extends StatefulWidget {
  const WaterTrackerScreen({super.key});

  @override
  State<WaterTrackerScreen> createState() => _WaterTrackerScreenState();
}

class _WaterTrackerScreenState extends State<WaterTrackerScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _splashController;
  late Animation<double> _splashAnimation;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _splashController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _splashAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _splashController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _splashController.dispose();
    super.dispose();
  }

  void _triggerSplash() {
    HapticFeedback.mediumImpact();
    _splashController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final total = health.todayWaterIntakeMl;
    final progress = health.waterProgress;
    final glasses = (total / 250).floor();
    final targetMl = health.dailyWaterTargetMl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        title: const Text('Water Intake'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ---------- Hero bottle visual with wave animation ----------
          AnimatedBuilder(
            animation: _splashAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _splashAnimation.value,
                child: child,
              );
            },
            child: SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Column(
                children: [
                  // Fill visual with wave animation
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 116,
                        height: 190,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.grey100,
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: SizedBox(
                          width: 116,
                          height: (190 * progress.clamp(0.0, 1.0)),
                          child: AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _WavePainter(
                                  animation: _waveController.value,
                                  fillProgress: progress.clamp(0.0, 1.0),
                                ),
                                size: Size(116, 190 * progress.clamp(0.0, 1.0)),
                              );
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 68,
                        child: Column(
                          children: [
                            Text(
                              '${(progress * 100).clamp(0, 999).toStringAsFixed(0)}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: progress > 0.45
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.white
                                            : AppColors.ink),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  AnimatedCounter(
                    value: total.toDouble(),
                    suffix: ' ml',
                    style: Theme.of(context).textTheme.displayMedium,
                    duration: const Duration(milliseconds: 600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'of ${formatWaterMl(targetMl)} target  \u00b7  $glasses glasses',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  SoftProgressBar(
                    progress: progress,
                    height: 10,
                    color: AppColors.water,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ---------- Quick add ----------
          SectionHeader(title: 'Quick add'),
          Row(
            children: AppConstants.waterQuickAddOptions.map((ml) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: ml == AppConstants.waterQuickAddOptions.last ? 0 : 10,
                  ),
                  child: SoftCard(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    onTap: () async {
                      _triggerSplash();
                      await health.addWater(ml);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('+${ml}ml logged \u{1F4A7}')),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.water.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.water_drop_rounded,
                              color: AppColors.water, size: 19),
                        ),
                        const SizedBox(height: 8),
                        Text('+$ml',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text('ml',
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ---------- Today's log ----------
          SectionHeader(title: "Today's log"),
          if (health.todayWaterLogs.isEmpty)
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Text('\u{1F4A7}', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text('No water logged yet',
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            )
          else
            SoftCard(
              child: Column(
                children: [
                  for (var i = 0; i < health.todayWaterLogs.length; i++) ...[
                    if (i > 0) const Divider(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.water.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.water_drop_rounded,
                              size: 17, color: AppColors.water),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            formatWaterMl(health.todayWaterLogs[i].amountMl),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          formatTime(health.todayWaterLogs[i].loggedAt),
                          style: Theme.of(context).textTheme.labelSmall,
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
}

/// Custom painter for wave animation inside the water bottle.
class _WavePainter extends CustomPainter {
  final double animation;
  final double fillProgress;

  _WavePainter({required this.animation, required this.fillProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          AppColors.water,
          AppColors.water.withOpacity(0.55),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final waveHeight = 6.0;
    final offset = animation * 2 * math.pi;

    path.moveTo(0, size.height);
    path.lineTo(0, waveHeight);

    for (double x = 0; x <= size.width; x++) {
      final y = waveHeight +
          math.sin((x / size.width * 2 * math.pi) + offset) * waveHeight * 0.5 +
          math.cos((x / size.width * 4 * math.pi) + offset * 1.5) *
              waveHeight *
              0.25;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => true;
}
