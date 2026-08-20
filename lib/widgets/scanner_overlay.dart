import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Corner-bracket viewfinder frame + horizontal scan line, matching the
/// "Scanner" screen in the reference UI.
class ScannerFrame extends StatefulWidget {
  const ScannerFrame({
    super.key,
    this.size = 280,
    this.animate = true,
  });

  final double size;
  final bool animate;

  @override
  State<ScannerFrame> createState() => _ScannerFrameState();
}

class _ScannerFrameState extends State<ScannerFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          // Four corner brackets
          _corner(Alignment.topLeft),
          _corner(Alignment.topRight),
          _corner(Alignment.bottomLeft),
          _corner(Alignment.bottomRight),

          // Animated scan line
          if (widget.animate)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Align(
                  alignment: Alignment(0, _controller.value * 2 - 1),
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.limeBright,
                          AppColors.limeBright,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.25, 0.75, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.limeBright.withOpacity(0.6),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _corner(Alignment alignment) {
    const len = 34.0;
    const thick = 3.5;
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: len,
        height: len,
        child: CustomPaint(
          painter: _CornerPainter(
            isTop: isTop,
            isLeft: isLeft,
            thickness: thick,
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({
    required this.isTop,
    required this.isLeft,
    required this.thickness,
  });

  final bool isTop;
  final bool isLeft;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const r = 12.0;
    final path = Path();

    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, r);
      path.quadraticBezierTo(0, 0, r, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width - r, 0);
      path.quadraticBezierTo(size.width, 0, size.width, r);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - r);
      path.quadraticBezierTo(0, size.height, r, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height - r);
      path.quadraticBezierTo(
          size.width, size.height, size.width - r, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

/// Scan mode selector chips — "Scan Food / Barcode / Food Label / Library"
class ScanModeChips extends StatelessWidget {
  const ScanModeChips({
    super.key,
    required this.modes,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<({String label, IconData icon})> modes;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(modes.length, (i) {
        final selected = i == selectedIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.limeBright
                    : Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? AppColors.limeBright
                      : Colors.white.withOpacity(0.25),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    modes[i].icon,
                    size: 17,
                    color: selected ? AppColors.ink : Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    modes[i].label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.ink : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Large camera shutter button with concentric ring.
class ShutterButton extends StatelessWidget {
  const ShutterButton({
    super.key,
    this.onTap,
    this.busy = false,
    this.size = 72,
  });

  final VoidCallback? onTap;
  final bool busy;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 3.5),
        ),
        padding: const EdgeInsets.all(5),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.ink,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
