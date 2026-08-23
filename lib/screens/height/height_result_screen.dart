import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/height_measurement_model.dart';
import '../../services/height_measurement_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/soft_card.dart';

/// Displays the final height measurement results.
/// Shows single measurement or accuracy mode results (all 3 readings, median, average).
class HeightResultScreen extends StatefulWidget {
  const HeightResultScreen({super.key, required this.result});

  final HeightMeasurementResult result;

  @override
  State<HeightResultScreen> createState() => _HeightResultScreenState();
}

class _HeightResultScreenState extends State<HeightResultScreen> {
  bool _saving = false;
  bool _sendingEmail = false;
  bool _saved = false;
  String? _error;

  double get _displayHeight => widget.result.isAccuracyMode
      ? widget.result.median
      : widget.result.measurements.first.valueCm;

  String get _methodLabel {
    if (widget.result.measurements.isEmpty) return 'Unknown';
    final method = widget.result.measurements.first.method;
    switch (method) {
      case 'pose_reference':
        return 'Pose + Reference Object';
      case 'arcore':
        return 'ARCore';
      case 'lidar':
        return 'LiDAR / ToF';
      default:
        return method;
    }
  }

  Future<void> _saveHeight() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final service = context.read<HeightMeasurementService>();
      await service.saveHeight(_displayHeight);
      if (mounted) {
        setState(() {
          _saving = false;
          _saved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Height saved to your profile!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _sendReport() async {
    setState(() {
      _sendingEmail = true;
      _error = null;
    });

    try {
      final service = context.read<HeightMeasurementService>();
      await service.sendHeightReportEmail(result: widget.result);
      if (mounted) {
        setState(() => _sendingEmail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Height report sent to your email!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendingEmail = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurement Result'),
        leading: CircleIconButton(
          icon: Icons.close_rounded,
          iconSize: 20,
          onTap: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.page.copyWith(top: 24, bottom: 32),
          child: Column(
            children: [
              // Main result display
              SoftCard(
                color: isDark ? AppColors.darkCard : AppColors.limeWash,
                border: Border.all(
                  color: AppColors.limeBright.withOpacity(0.3),
                ),
                padding: const EdgeInsets.symmetric(
                    vertical: 32, horizontal: AppSpacing.xxl),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.limeBright.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.straighten_rounded,
                        color: AppColors.limeDeep,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${_displayHeight.toStringAsFixed(1)} cm',
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(
                            color: AppColors.limeBright,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Height',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.grey500,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.grey100,
                        borderRadius: AppRadius.chip,
                      ),
                      child: Text(
                        _methodLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Accuracy mode details
              if (widget.result.isAccuracyMode) ...[
                SoftCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.precision_manufacturing_rounded,
                              size: 18, color: AppColors.limeBright),
                          const SizedBox(width: 8),
                          Text(
                            'Accuracy Mode Results',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // All 3 readings
                      ...List.generate(widget.result.measurements.length, (i) {
                        final m = widget.result.measurements[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: AppColors.limeSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: AppColors.limeDeep,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Reading ${i + 1}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const Spacer(),
                              Text(
                                '${m.valueCm.toStringAsFixed(1)} cm',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        );
                      }),

                      const Divider(height: 24),

                      // Median
                      Row(
                        children: [
                          const Icon(Icons.bar_chart_rounded,
                              size: 18, color: AppColors.protein),
                          const SizedBox(width: 8),
                          Text(
                            'Median',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            '${widget.result.median.toStringAsFixed(1)} cm',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.protein,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Average
                      Row(
                        children: [
                          const Icon(Icons.calculate_rounded,
                              size: 18, color: AppColors.burned),
                          const SizedBox(width: 8),
                          Text(
                            'Average',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            '${widget.result.average.toStringAsFixed(1)} cm',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.burned,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.pastelPink,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action buttons
              PillButton(
                label: _sendingEmail ? 'Sending...' : 'Send Report via Email',
                variant: PillVariant.outline,
                icon: Icons.email_rounded,
                loading: _sendingEmail,
                onPressed: _sendingEmail ? null : _sendReport,
              ),
              const SizedBox(height: 12),

              PillButton(
                label: _saved ? 'Saved!' : 'Save to Profile',
                variant: _saved ? PillVariant.soft : PillVariant.lime,
                icon: _saved ? Icons.check_rounded : Icons.save_rounded,
                loading: _saving,
                onPressed: (_saving || _saved) ? null : _saveHeight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
