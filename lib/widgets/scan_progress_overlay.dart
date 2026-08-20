import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Full-screen overlay that cycles through analysis steps while the AI scan
/// runs, so the user sees progress instead of a static spinner.
///
/// Steps auto-advance every [stepDuration]; the calling code simply shows
/// the widget while [busy] is true and removes it when the result arrives.
class ScanProgressOverlay extends StatefulWidget {
  const ScanProgressOverlay({super.key});

  @override
  State<ScanProgressOverlay> createState() => _ScanProgressOverlayState();
}

class _ScanProgressOverlayState extends State<ScanProgressOverlay>
    with SingleTickerProviderStateMixin {
  static const _steps = [
    (icon: Icons.camera_alt_rounded, text: 'Scanning image…', sub: 'Capturing food details'),
    (icon: Icons.search_rounded, text: 'Finding food items…', sub: 'Identifying dishes on plate'),
    (icon: Icons.auto_awesome, text: 'Analyzing nutrition…', sub: 'Estimating calories & macros'),
  ];

  int _currentStep = 0;
  Timer? _timer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (_currentStep < _steps.length - 1) {
        setState(() => _currentStep++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon
            FadeTransition(
              opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_pulse),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.limeBright.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(step.icon, color: AppColors.limeBright, size: 32),
              ),
            ),
            const SizedBox(height: 24),

            // Step indicator dots
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_steps.length, (i) {
                final active = i <= _currentStep;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.limeBright : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Main text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                step.text,
                key: ValueKey(_currentStep),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                step.sub,
                key: ValueKey('sub_$_currentStep'),
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
