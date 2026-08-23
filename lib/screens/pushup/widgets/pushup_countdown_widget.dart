import 'dart:async';
import 'package:flutter/material.dart';
import '../../../utils/app_theme.dart';

/// Animated countdown widget with scale + fade transitions and motivational
/// messages. Displays 3, 2, 1 with a pulsing circle before the session starts.
class PushupCountdownWidget extends StatefulWidget {
  const PushupCountdownWidget({
    super.key,
    required this.countdown,
  });

  /// Current countdown value (3, 2, 1). When 0, shows nothing.
  final int countdown;

  @override
  State<PushupCountdownWidget> createState() => _PushupCountdownWidgetState();
}

class _PushupCountdownWidgetState extends State<PushupCountdownWidget>
    with SingleTickerProviderStateMixin {
  int _displayedCount = 0;
  double _scale = 0.3;
  double _opacity = 0.0;
  double _circleScale = 0.8;

  Timer? _animTimer;

  @override
  void initState() {
    super.initState();
    _displayedCount = widget.countdown;
    _triggerAnimation();
  }

  @override
  void didUpdateWidget(covariant PushupCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countdown != widget.countdown) {
      _displayedCount = widget.countdown;
      _triggerAnimation();
    }
  }

  void _triggerAnimation() {
    _animTimer?.cancel();

    // Reset to initial state
    setState(() {
      _scale = 0.3;
      _opacity = 0.0;
      _circleScale = 0.8;
    });

    // Animate in after a brief delay (allows the implicit animations to kick)
    _animTimer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      setState(() {
        _scale = 1.0;
        _opacity = 1.0;
        _circleScale = 1.2;
      });
    });
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  String _motivationalText(int count) {
    switch (count) {
      case 3:
        return 'Ready...';
      case 2:
        return 'Set...';
      case 1:
        return 'Go!';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_displayedCount <= 0) return const SizedBox.shrink();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing circle background
          AnimatedScale(
            scale: _circleScale,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.limeBright.withOpacity(0.15),
                border: Border.all(
                  color: AppColors.limeBright.withOpacity(0.4),
                  width: 3,
                ),
              ),
              child: Center(
                // Animated number
                child: AnimatedScale(
                  scale: _scale,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: _opacity,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '$_displayedCount',
                      style: const TextStyle(
                        fontSize: 100,
                        fontWeight: FontWeight.w800,
                        color: AppColors.limeBright,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Motivational text
          AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 400),
            child: Text(
              _motivationalText(_displayedCount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 500),
            child: const Text(
              'Get into push-up position',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
