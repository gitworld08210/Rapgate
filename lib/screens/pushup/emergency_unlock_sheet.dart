import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/pill_button.dart';

/// Premium glassmorphism bottom sheet for emergency unlocks.
///
/// Shows remaining unlocks this week, requires a reason, warns about the fine,
/// and uses a swipe-to-confirm action for the final step.
class EmergencyUnlockSheet extends StatefulWidget {
  final int usedThisWeek;

  const EmergencyUnlockSheet({super.key, required this.usedThisWeek});

  @override
  State<EmergencyUnlockSheet> createState() => _EmergencyUnlockSheetState();
}

class _EmergencyUnlockSheetState extends State<EmergencyUnlockSheet>
    with SingleTickerProviderStateMixin {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  double _swipeProgress = 0.0;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  int get _remainingThisWeek =>
      AppConstants.maxEmergencyUnlocksPerWeek - widget.usedThisWeek;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: EdgeInsets.only(
          bottom: mediaQuery.viewInsets.bottom + 24,
          top: 16,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          // Glassmorphism: translucent dark background with border
          color: AppColors.ink.withOpacity(0.92),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 40,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Animated warning icon with glow
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.danger.withOpacity(_glowAnimation.value * 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.danger.withOpacity(0.15),
                      border: Border.all(
                        color: AppColors.danger.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 28,
                      color: AppColors.danger,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),

            // Title
            Text(
              'Emergency Unlock',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: AppColors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Unlock apps immediately with a fine',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white60),
            ),

            const SizedBox(height: 22),

            // Usage counter
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _remainingThisWeek > 0
                      ? AppColors.warning.withOpacity(0.3)
                      : AppColors.danger.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_repeat_rounded,
                    size: 18,
                    color: _remainingThisWeek > 0
                        ? AppColors.warning
                        : AppColors.danger,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _remainingThisWeek > 0
                          ? '$_remainingThisWeek of ${AppConstants.maxEmergencyUnlocksPerWeek} remaining this week'
                          : 'No emergency unlocks remaining this week',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white.withOpacity(0.85),
                          ),
                    ),
                  ),
                ],
              ),
            ),

            if (_remainingThisWeek <= 0) ...[
              const SizedBox(height: 24),
              PillButton(
                label: 'Close',
                variant: PillVariant.outline,
                onPressed: () => Navigator.pop(context),
              ),
            ] else ...[
              const SizedBox(height: 18),

              // Reason field
              TextField(
                controller: _reasonController,
                maxLength: 200,
                maxLines: 2,
                style: const TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: 'Why do you need emergency access?',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                      color: AppColors.danger,
                      width: 1.5,
                    ),
                  ),
                  counterStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                ),
              ),

              const SizedBox(height: 14),

              // Fine warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.danger.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.currency_rupee_rounded,
                        size: 16, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A fine of \u20b9${(AppConstants.defaultFineAmountPaise / 100).toStringAsFixed(0)} will be created',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Swipe to confirm
              _buildSwipeToConfirm(context),
            ],

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeToConfirm(BuildContext context) {
    const trackHeight = 56.0;
    const thumbSize = 48.0;
    final trackWidth = MediaQuery.of(context).size.width - 48 - 48;

    if (_isSubmitting) {
      return Container(
        height: trackHeight,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.danger,
          ),
        ),
      );
    }

    return Container(
      height: trackHeight,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(trackHeight / 2),
        border: Border.all(
          color: AppColors.danger.withOpacity(0.2 + _swipeProgress * 0.4),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // Progress fill
          AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            width: trackWidth * _swipeProgress,
            height: trackHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.danger.withOpacity(0.15),
                  AppColors.danger.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(trackHeight / 2),
            ),
          ),
          // Label
          Center(
            child: Text(
              'Swipe to confirm unlock',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white.withOpacity(0.5),
                  ),
            ),
          ),
          // Thumb
          Positioned(
            left: (trackWidth - thumbSize) * _swipeProgress,
            top: (trackHeight - thumbSize) / 2,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _swipeProgress += details.delta.dx / (trackWidth - thumbSize);
                  _swipeProgress = _swipeProgress.clamp(0.0, 1.0);
                });
                if (_swipeProgress > 0.3) {
                  HapticFeedback.selectionClick();
                }
              },
              onHorizontalDragEnd: (details) {
                if (_swipeProgress > 0.85) {
                  _confirmUnlock();
                } else {
                  setState(() => _swipeProgress = 0.0);
                }
              },
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: AppColors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUnlock() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _swipeProgress = 0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      final db = context.read<DatabaseService>();
      await db.requestEmergencyUnlock(reason);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency unlock granted for 2 hours'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _swipeProgress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}
