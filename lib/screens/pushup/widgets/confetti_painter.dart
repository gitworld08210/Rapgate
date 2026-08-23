import 'dart:math';
import 'package:flutter/material.dart';

/// A particle in the confetti system.
class _ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double rotationSpeed;
  double size;
  Color color;
  double opacity;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
    this.opacity = 1.0,
  });
}

/// CustomPainter-based confetti celebration animation.
///
/// Draws colored rectangular particles falling with gravity and rotation.
/// Driven by an [AnimationController] passed to [ConfettiWidget].
class ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.opacity <= 0) continue;
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => true;
}

/// A widget that displays a confetti celebration animation.
///
/// Usage:
/// ```dart
/// ConfettiWidget(play: true)
/// ```
class ConfettiWidget extends StatefulWidget {
  /// Whether the confetti animation should play.
  final bool play;

  /// Duration of the confetti burst.
  final Duration duration;

  /// Number of particles.
  final int particleCount;

  const ConfettiWidget({
    super.key,
    this.play = false,
    this.duration = const Duration(milliseconds: 3000),
    this.particleCount = 80,
  });

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  static const List<Color> _colors = [
    Color(0xFFB5E048), // limeBright
    Color(0xFFC4E86B), // lime
    Color(0xFFA3D93F), // limeDeep
    Color(0xFF34C759), // success green
    Color(0xFFFFC107), // gold
    Color(0xFF2196F3), // blue
    Color(0xFFFF9500), // orange
    Color(0xFFE8F5D0), // limeSoft
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.addListener(_updateParticles);
    if (widget.play) _startAnimation();
  }

  @override
  void didUpdateWidget(covariant ConfettiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _initParticles();
    _controller.forward(from: 0.0);
  }

  void _initParticles() {
    _particles.clear();
    final size = MediaQuery.of(context).size;
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(_ConfettiParticle(
        x: size.width * _random.nextDouble(),
        y: -20 - (_random.nextDouble() * 100),
        vx: (_random.nextDouble() - 0.5) * 4,
        vy: 2 + _random.nextDouble() * 5,
        rotation: _random.nextDouble() * pi * 2,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
        size: 6 + _random.nextDouble() * 8,
        color: _colors[_random.nextInt(_colors.length)],
        opacity: 1.0,
      ));
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    final progress = _controller.value;
    const gravity = 0.15;

    for (final p in _particles) {
      p.x += p.vx;
      p.vy += gravity;
      p.y += p.vy;
      p.rotation += p.rotationSpeed;
      // Fade out near end of animation
      if (progress > 0.7) {
        p.opacity = ((1.0 - progress) / 0.3).clamp(0.0, 1.0);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_updateParticles);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.play && _particles.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: CustomPaint(
        painter: ConfettiPainter(
          particles: _particles,
          progress: _controller.value,
        ),
        size: Size.infinite,
      ),
    );
  }
}
