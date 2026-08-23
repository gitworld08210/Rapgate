import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A premium haptic feedback wrapper.
/// Wraps any widget and provides haptic feedback on tap.
/// Used throughout the app to give that premium tactile feel.
class HapticButton extends StatelessWidget {
  const HapticButton({
    super.key,
    required this.child,
    this.onPressed,
    this.feedbackType = HapticType.light,
    this.scaleOnPress = true,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final HapticType feedbackType;
  final bool scaleOnPress;

  @override
  Widget build(BuildContext context) {
    if (scaleOnPress) {
      return _ScaleOnTap(
        onTap: () {
          _triggerHaptic();
          onPressed?.call();
        },
        child: child,
      );
    }

    return GestureDetector(
      onTap: () {
        _triggerHaptic();
        onPressed?.call();
      },
      child: child,
    );
  }

  void _triggerHaptic() {
    switch (feedbackType) {
      case HapticType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticType.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }
}

enum HapticType { light, medium, heavy, selection }

/// Internal widget that adds a subtle press-down scale effect.
class _ScaleOnTap extends StatefulWidget {
  const _ScaleOnTap({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<_ScaleOnTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
