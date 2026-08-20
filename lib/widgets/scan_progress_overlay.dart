import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Full-screen overlay shown while food recognition or a barcode lookup runs.
/// The food animation is intentionally built with Flutter primitives and emoji
/// so it stays lightweight and does not add a Lottie/Rive dependency to the APK.
class ScanProgressOverlay extends StatefulWidget {
  const ScanProgressOverlay({super.key, this.barcodeLookup = false});

  final bool barcodeLookup;

  @override
  State<ScanProgressOverlay> createState() => _ScanProgressOverlayState();
}

class _ScanProgressOverlayState extends State<ScanProgressOverlay>
    with SingleTickerProviderStateMixin {
  static const _foodSteps = [
    (text: 'Scanning image…', sub: 'Reading visible food details'),
    (text: 'Finding food items…', sub: 'Separating every dish on the plate'),
    (
      text: 'Analyzing nutrition…',
      sub: 'Estimating calories, protein & macros'
    ),
  ];
  static const _barcodeSteps = [
    (text: 'Reading product code…', sub: 'Checking the package barcode'),
    (text: 'Finding packed food…', sub: 'Searching verified product data'),
    (
      text: 'Loading nutrition…',
      sub: 'Preparing calories & macros per serving'
    ),
  ];

  int _currentStep = 0;
  Timer? _timer;
  late final AnimationController _motion;

  List<({String text, String sub})> get _steps =>
      widget.barcodeLookup ? _barcodeSteps : _foodSteps;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted && _currentStep < _steps.length - 1) {
        setState(() => _currentStep++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: widget.barcodeLookup
                  ? _PackedFoodAnimation(
                      key: const ValueKey('packed-food'),
                      motion: _motion,
                    )
                  : _FoodNutritionAnimation(
                      key: const ValueKey('food-nutrition'),
                      motion: _motion,
                    ),
            ),
            const SizedBox(height: 26),
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                step.text,
                key: ValueKey(_currentStep),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 7),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                step.sub,
                key: ValueKey('sub_$_currentStep'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodNutritionAnimation extends StatelessWidget {
  const _FoodNutritionAnimation({super.key, required this.motion});

  final Animation<double> motion;

  static const _foods = ['🍎', '🍌', '🥚', '🥦'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: motion,
      builder: (context, _) {
        final angle = motion.value * math.pi * 2;
        final pulse = 1 + math.sin(angle * 2) * 0.055;
        return SizedBox(
          width: 154,
          height: 154,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 122,
                height: 122,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.limeBright.withValues(alpha: 0.20),
                      AppColors.limeBright.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.limeBright.withValues(alpha: 0.18),
                  ),
                ),
              ),
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 67,
                  height: 67,
                  decoration: BoxDecoration(
                    color: AppColors.limeBright.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.limeBright.withValues(alpha: 0.15),
                        blurRadius: 24,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: AppColors.limeBright,
                        size: 25,
                      ),
                      Text(
                        'PROTEIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...List.generate(_foods.length, (index) {
                final itemAngle = angle + index * math.pi / 2;
                return Transform.translate(
                  offset: Offset(
                    math.cos(itemAngle) * 61,
                    math.sin(itemAngle) * 61,
                  ),
                  child: Transform.rotate(
                    angle: -itemAngle + index * math.pi / 2,
                    child: Container(
                      width: 39,
                      height: 39,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF20241B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 8),
                        ],
                      ),
                      child: Text(
                        _foods[index],
                        style: const TextStyle(fontSize: 23),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _PackedFoodAnimation extends StatelessWidget {
  const _PackedFoodAnimation({super.key, required this.motion});

  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: motion,
      builder: (context, _) {
        final angle = motion.value * math.pi * 2;
        final sweepY = -35 + (motion.value * 70);
        return SizedBox(
          width: 154,
          height: 154,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: math.sin(angle) * 0.05,
                child: Container(
                  width: 98,
                  height: 116,
                  decoration: BoxDecoration(
                    color: const Color(0xFF20241B),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.limeBright.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🥛', style: TextStyle(fontSize: 38)),
                      SizedBox(height: 8),
                      Icon(Icons.qr_code_2_rounded,
                          color: Colors.white, size: 34),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, sweepY),
                child: Container(
                  width: 118,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.limeBright,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.limeBright.withValues(alpha: 0.65),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
