import 'package:flutter/material.dart';

import '../../models/height_measurement_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/soft_card.dart';
import 'height_result_screen.dart';

/// Accuracy mode screen that guides the user through 3 measurements.
/// After all 3, it calculates and displays median and average.
class AccuracyModeScreen extends StatefulWidget {
  const AccuracyModeScreen({super.key});

  @override
  State<AccuracyModeScreen> createState() => _AccuracyModeScreenState();
}

class _AccuracyModeScreenState extends State<AccuracyModeScreen> {
  final List<HeightMeasurement> _measurements = [];

  int get _currentMeasurement => _measurements.length + 1;
  bool get _allDone => _measurements.length >= 3;

  void _startNextMeasurement() async {
    final result = await Navigator.push<HeightMeasurement>(
      context,
      MaterialPageRoute(
        builder: (_) => _AccuracyPoseCaptureScreen(
          measurementNumber: _currentMeasurement,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _measurements.add(result);
      });

      if (_allDone) {
        _showResults();
      }
    }
  }

  void _showResults() {
    final result = HeightMeasurementResult.fromMeasurements(_measurements);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HeightResultScreen(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accuracy Mode'),
        leading: CircleIconButton(
          icon: Icons.arrow_back_rounded,
          iconSize: 20,
          onTap: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.page.copyWith(top: 24, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              Row(
                children: List.generate(3, (i) {
                  final done = i < _measurements.length;
                  final current = i == _measurements.length;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                      height: 6,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.limeBright
                            : (current
                                ? AppColors.lime.withOpacity(0.4)
                                : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.grey200)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              Text(
                _allDone
                    ? 'All measurements done!'
                    : 'Measurement $_currentMeasurement of 3',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _allDone
                    ? 'Calculating your results...'
                    : 'Take 3 separate measurements for better accuracy. Move slightly between each measurement.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey500,
                    ),
              ),
              const SizedBox(height: 32),

              // Show completed measurements
              if (_measurements.isNotEmpty) ...[
                Text(
                  'Completed',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.grey500,
                      ),
                ),
                const SizedBox(height: 12),
                ...List.generate(_measurements.length, (i) {
                  final m = _measurements[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.limeSoft,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: AppColors.limeDeep,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${m.valueCm.toStringAsFixed(1)} cm',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                Text(
                                  'Pose + Reference Object',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.grey500),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 22),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],

              const Spacer(),

              // Action button
              if (!_allDone)
                PillButton(
                  label: _measurements.isEmpty
                      ? 'Start Measurement 1'
                      : 'Start Measurement $_currentMeasurement',
                  variant: PillVariant.lime,
                  icon: Icons.camera_alt_rounded,
                  onPressed: _startNextMeasurement,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Camera-based pose capture screen for accuracy mode.
/// Returns a HeightMeasurement to the caller via Navigator.pop.
class _AccuracyPoseCaptureScreen extends StatefulWidget {
  const _AccuracyPoseCaptureScreen({required this.measurementNumber});

  final int measurementNumber;

  @override
  State<_AccuracyPoseCaptureScreen> createState() =>
      _AccuracyPoseCaptureScreenState();
}

class _AccuracyPoseCaptureScreenState
    extends State<_AccuracyPoseCaptureScreen> {
  double _heightValue = 170;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('Measurement ${widget.measurementNumber}/3'),
        leading: CircleIconButton(
          icon: Icons.arrow_back_rounded,
          iconSize: 20,
          background: Colors.white.withOpacity(0.2),
          iconColor: Colors.white,
          onTap: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.limeSoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${widget.measurementNumber}',
                    style: const TextStyle(
                      color: AppColors.limeDeep,
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Position for measurement',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Stand straight with reference object at your feet. Adjust the slider to match your pose-detected height.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Text(
                '${_heightValue.toStringAsFixed(1)} cm',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: AppColors.limeBright,
                ),
              ),
              const SizedBox(height: 20),
              Slider(
                value: _heightValue,
                min: 100,
                max: 220,
                activeColor: AppColors.limeBright,
                inactiveColor: AppColors.grey700,
                onChanged: (val) => setState(() => _heightValue = val),
              ),
              const SizedBox(height: 8),
              const Text(
                'Adjust to match detected height',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 40),
              PillButton(
                label: 'Confirm Measurement ${widget.measurementNumber}',
                variant: PillVariant.lime,
                icon: Icons.check_rounded,
                onPressed: () {
                  Navigator.pop(
                    context,
                    HeightMeasurement(
                      method: 'pose_reference',
                      valueCm: _heightValue,
                      referenceObjectType: 'a4_paper',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
