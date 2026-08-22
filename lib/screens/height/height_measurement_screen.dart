import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/height_measurement_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/soft_card.dart';
import 'accuracy_mode_screen.dart';
import 'arcore_height_screen.dart';
import 'lidar_height_screen.dart';
import 'pose_height_screen.dart';

/// Main entry screen for height measurement.
/// Shows 3 measurement method options + accuracy mode toggle.
class HeightMeasurementScreen extends StatefulWidget {
  const HeightMeasurementScreen({super.key});

  @override
  State<HeightMeasurementScreen> createState() =>
      _HeightMeasurementScreenState();
}

class _HeightMeasurementScreenState extends State<HeightMeasurementScreen> {
  bool _accuracyMode = false;
  bool _checkingARCore = false;
  bool _checkingLiDAR = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Measure Height'),
        leading: CircleIconButton(
          icon: Icons.arrow_back_rounded,
          iconSize: 20,
          onTap: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.page.copyWith(top: 16, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a method',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Select how you want to measure your height',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey500,
                    ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Option 1: Pose + Reference Object
              _MethodCard(
                icon: Icons.accessibility_new_rounded,
                iconColor: AppColors.limeBright,
                iconBg: AppColors.limeSoft,
                title: 'Pose + Reference Object',
                subtitle:
                    'Use camera with A4 paper or credit card for calibration',
                tag: 'Recommended',
                tagColor: AppColors.limeBright,
                onTap: () => _startMethod('pose'),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Option 2: ARCore
              _MethodCard(
                icon: Icons.view_in_ar_rounded,
                iconColor: AppColors.protein,
                iconBg: AppColors.pastelBlue,
                title: 'ARCore Measurement',
                subtitle: 'Uses augmented reality depth sensing',
                tag: 'Limited availability',
                tagColor: AppColors.grey500,
                onTap: () => _startMethod('arcore'),
                loading: _checkingARCore,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Option 3: LiDAR / ToF
              _MethodCard(
                icon: Icons.sensors_rounded,
                iconColor: AppColors.burned,
                iconBg: AppColors.pastelOrange,
                title: 'LiDAR / ToF Sensor',
                subtitle: 'Uses time-of-flight depth sensor',
                tag: 'Limited availability',
                tagColor: AppColors.grey500,
                onTap: () => _startMethod('lidar'),
                loading: _checkingLiDAR,
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Accuracy Mode Toggle
              SoftCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                color: isDark ? AppColors.darkCard : AppColors.limeWash,
                border: Border.all(
                  color: _accuracyMode
                      ? AppColors.limeBright
                      : (isDark ? AppColors.darkBorder : AppColors.grey200),
                  width: 1.5,
                ),
                onTap: () => setState(() => _accuracyMode = !_accuracyMode),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _accuracyMode
                            ? AppColors.limeBright
                            : (isDark ? AppColors.darkBorder : AppColors.grey100),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.precision_manufacturing_rounded,
                        size: 22,
                        color:
                            _accuracyMode ? AppColors.ink : AppColors.grey500,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accuracy Mode',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Measure 3 times, get median & average',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.grey500,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _accuracyMode,
                      onChanged: (val) => setState(() => _accuracyMode = val),
                      activeColor: AppColors.limeBright,
                      activeTrackColor: AppColors.limeDeep,
                    ),
                  ],
                ),
              ),

              if (_accuracyMode) ...[
                const SizedBox(height: AppSpacing.lg),
                PillButton(
                  label: 'Start Accuracy Measurement',
                  variant: PillVariant.lime,
                  icon: Icons.precision_manufacturing_rounded,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccuracyModeScreen(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startMethod(String method) async {
    final service = context.read<HeightMeasurementService>();

    switch (method) {
      case 'pose':
        if (_accuracyMode) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccuracyModeScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PoseHeightScreen()),
          );
        }
        break;

      case 'arcore':
        setState(() => _checkingARCore = true);
        final available = await service.isARCoreAvailable();
        setState(() => _checkingARCore = false);

        if (!mounted) return;
        if (available) {
          // Would navigate to ARCore screen if available
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ARCoreHeightScreen()),
          );
        }
        break;

      case 'lidar':
        setState(() => _checkingLiDAR = true);
        final available = await service.isLiDARAvailable();
        setState(() => _checkingLiDAR = false);

        if (!mounted) return;
        if (available) {
          // Would navigate to LiDAR screen if available
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LiDARHeightScreen()),
          );
        }
        break;
    }
  }
}

/// Card widget for each measurement method option.
class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tag,
    this.tagColor,
    this.loading = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String? tag;
  final Color? tagColor;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: loading ? null : onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (tagColor ?? AppColors.grey500)
                              .withOpacity(0.15),
                          borderRadius: AppRadius.chip,
                        ),
                        child: Text(
                          tag!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: tagColor ?? AppColors.grey500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey500,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.grey300),
        ],
      ),
    );
  }
}
