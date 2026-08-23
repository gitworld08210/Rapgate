import 'package:flutter/material.dart';

import '../../services/referral_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';

/// A bottom sheet that prompts the user to enter a referral code after signup.
/// This is optional and can be skipped.
///
/// Usage:
/// ```dart
/// ReferralCodeDialog.show(context);
/// ```
class ReferralCodeDialog extends StatefulWidget {
  const ReferralCodeDialog({super.key});

  /// Show the referral code bottom sheet. Returns true if code was applied.
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ReferralCodeDialog(),
    );
    return result ?? false;
  }

  @override
  State<ReferralCodeDialog> createState() => _ReferralCodeDialogState();
}

class _ReferralCodeDialogState extends State<ReferralCodeDialog> {
  final _codeController = TextEditingController();
  final _referralService = ReferralService();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _applyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a referral code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final message = await _referralService.applyReferralCode(code);
      if (!mounted) return;
      setState(() {
        _success = message;
        _loading = false;
      });

      // Auto-dismiss after a short delay on success
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _skip() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: bottomInset + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Title
          Text(
            'Have a referral code? 🎁',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'Enter a friend\'s code and both of you get 7 days fine-free!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey500,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Code input field
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
            decoration: InputDecoration(
              hintText: 'e.g. RAHUL4521',
              hintStyle: TextStyle(
                color: AppColors.grey500,
                letterSpacing: 1,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.grey100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),

          // Error message
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.danger,
                  ),
              textAlign: TextAlign.center,
            ),
          ],

          // Success message
          if (_success != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _success!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.limeDeep,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // Apply button
          PillButton(
            label: 'Apply Code',
            icon: Icons.check_circle_outline,
            variant: PillVariant.lime,
            loading: _loading,
            onPressed: _loading ? null : _applyCode,
          ),

          const SizedBox(height: AppSpacing.md),

          // Skip button
          PillButton(
            label: 'Skip',
            variant: PillVariant.outline,
            onPressed: _loading ? null : _skip,
          ),
        ],
      ),
    );
  }
}
