import 'dart:async';
import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../widgets/pill_button.dart';

/// A warm-up exercise definition.
class _WarmupExercise {
  final String emoji;
  final String name;
  final String description;
  final int durationSeconds;

  const _WarmupExercise({
    required this.emoji,
    required this.name,
    required this.description,
    required this.durationSeconds,
  });
}

/// Modal bottom sheet with 3-4 warm-up exercises before a push-up session.
///
/// Each exercise has a brief timer (15s). The user can skip individual
/// exercises or start the session directly.
class WarmupGuideSheet extends StatefulWidget {
  /// Callback invoked when the user finishes warm-up or taps 'Start session'.
  final VoidCallback onStartSession;

  const WarmupGuideSheet({super.key, required this.onStartSession});

  @override
  State<WarmupGuideSheet> createState() => _WarmupGuideSheetState();

  /// Shows the warm-up guide as a modal bottom sheet.
  static Future<void> show(BuildContext context, {required VoidCallback onStartSession}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WarmupGuideSheet(onStartSession: onStartSession),
    );
  }
}

class _WarmupGuideSheetState extends State<WarmupGuideSheet> {
  static const List<_WarmupExercise> _exercises = [
    _WarmupExercise(
      emoji: '\u{1F44B}',
      name: 'Wrist Circles',
      description: 'Rotate both wrists clockwise, then counter-clockwise. Loosens up the joints.',
      durationSeconds: 15,
    ),
    _WarmupExercise(
      emoji: '\u{1F4AA}',
      name: 'Arm Stretches',
      description: 'Extend each arm across your chest and hold. Stretches shoulders and triceps.',
      durationSeconds: 15,
    ),
    _WarmupExercise(
      emoji: '\u{1F3CB}',
      name: 'Shoulder Rolls',
      description: 'Roll shoulders forward 5 times, then backward 5 times. Warms up rotator cuffs.',
      durationSeconds: 15,
    ),
    _WarmupExercise(
      emoji: '\u{1F9D8}',
      name: 'Plank Hold',
      description: 'Hold a plank position with arms extended. Activates your core and chest.',
      durationSeconds: 15,
    ),
  ];

  int _currentExerciseIndex = 0;
  int _remainingSeconds = 15;
  Timer? _timer;
  bool _timerRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _remainingSeconds = _exercises[_currentExerciseIndex].durationSeconds;
      _timerRunning = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        t.cancel();
        _nextExercise();
      }
    });
  }

  void _nextExercise() {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      if (_currentExerciseIndex < _exercises.length - 1) {
        _currentExerciseIndex++;
        _remainingSeconds = _exercises[_currentExerciseIndex].durationSeconds;
      } else {
        // All exercises done
        _startSession();
      }
    });
  }

  void _startSession() {
    Navigator.pop(context);
    widget.onStartSession();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = _exercises[_currentExerciseIndex];
    final progress = _currentExerciseIndex / _exercises.length;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Warm Up',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Prepare your body to avoid injury',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),

          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_exercises.length, (i) {
              return Container(
                width: i == _currentExerciseIndex ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i <= _currentExerciseIndex
                      ? AppColors.limeBright
                      : AppColors.grey200,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),

          // Exercise card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.pastelGreen,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              children: [
                Text(
                  exercise.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 12),
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  exercise.description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey700,
                      ),
                ),
                const SizedBox(height: 18),
                // Timer display
                if (_timerRunning)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.soft,
                    ),
                    child: Center(
                      child: Text(
                        '$_remainingSeconds',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.limeDeep,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  )
                else
                  Text(
                    '${exercise.durationSeconds}s',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.limeDeep,
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          if (!_timerRunning)
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Start Timer',
                    icon: Icons.play_arrow_rounded,
                    variant: PillVariant.lime,
                    onPressed: _startTimer,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Skip',
                    variant: PillVariant.outline,
                    onPressed: _nextExercise,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'Start Session',
                  icon: Icons.fitness_center_rounded,
                  variant: PillVariant.dark,
                  onPressed: _startSession,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
