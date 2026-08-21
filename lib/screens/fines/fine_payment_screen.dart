import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/app_settings_model.dart';
import '../../models/fine_model.dart';
import '../../services/app_settings_service.dart';
import '../../services/fine_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/soft_card.dart';

/// Pay a fine by UPI, then submit proof (UTR number and/or screenshot)
/// for manual admin review.
class FinePaymentScreen extends StatefulWidget {
  const FinePaymentScreen({super.key, required this.fine});

  final FineModel fine;

  @override
  State<FinePaymentScreen> createState() => _FinePaymentScreenState();
}

class _FinePaymentScreenState extends State<FinePaymentScreen> {
  final _utrController = TextEditingController();

  XFile? _screenshot;
  bool _submitting = false;
  String? _error;
  String? _utrError;

  /// Server-fetched settings; null while loading or on failure.
  AppSettings? _settings;
  bool _settingsLoading = true;

  /// At least one form of proof is required.
  bool get _canSubmit =>
      _utrController.text.trim().isNotEmpty || _screenshot != null;

  /// The UPI ID to display and encode, preferring server value.
  String get _effectiveUpiId => _settings?.upiId ?? AppConstants.upiId;

  /// The payee name to encode, preferring server value.
  String get _effectivePayeeName =>
      _settings?.upiPayeeName ?? AppConstants.upiPayeeName;

  /// UPI deep link - also what the QR encodes.
  String get _upiUri {
    final amount = widget.fine.amountInRupees.toStringAsFixed(2);
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': _effectiveUpiId,
        'pn': _effectivePayeeName,
        'am': amount,
        'cu': AppConstants.currency,
        'tn': 'RepGate fine ${widget.fine.id}',
      },
    ).toString();
  }

  @override
  void initState() {
    super.initState();
    _utrController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final settings = await context.read<AppSettingsService>().getSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _settingsLoading = false;
      });
    } catch (_) {
      // Fall back to AppConstants silently.
      if (mounted) setState(() => _settingsLoading = false);
    }
  }

  @override
  void dispose() {
    _utrController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final picked = await context.read<FineService>().pickScreenshot();
      if (picked != null && mounted) {
        setState(() {
          _screenshot = picked;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open gallery: $e');
    }
  }

  Future<void> _submit() async {
    final utr = _utrController.text.trim();

    // Validate the UTR only if one was entered.
    final utrError = FineService.validateUtr(utr);
    if (utrError != null) {
      setState(() => _utrError = utrError);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _utrError = null;
    });

    try {
      await context.read<FineService>().submitPaymentProof(
            fineId: widget.fine.id,
            utr: utr.isEmpty ? null : utr,
            screenshot: _screenshot,
          );

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proof submitted — awaiting approval.'),
        ),
      );
    } on FineException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong: $e';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fine = widget.fine;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 16,
            bordered: true,
            onTap: () => Navigator.pop(context),
          ),
        ),
        leadingWidth: 74,
        title: const Text('Pay Fine'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ---------- Amount ----------
          SoftCard(
            color: AppColors.ink,
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Column(
              children: [
                Text(
                  'Amount due',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  fine.amountLabel,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  fine.reasonLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.limeBright,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ---------- Step 1: pay ----------
          _stepLabel(context, 1, 'Scan and pay'),
          const SizedBox(height: 12),

          SoftCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: _settingsLoading
                      ? const SizedBox(
                          width: 190,
                          height: 190,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : AppConstants.upiQrAssetPath != null
                          ? Image.asset(
                              AppConstants.upiQrAssetPath!,
                              width: 190,
                              height: 190,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _generatedQr(),
                            )
                          : _generatedQr(),
                ),
                const SizedBox(height: 18),

                // UPI ID with copy affordance
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: _effectiveUpiId),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('UPI ID copied')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: AppRadius.chip,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _effectiveUpiId,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded,
                            size: 15, color: AppColors.grey500),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Scan with any UPI app — GPay, PhonePe, Paytm.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ---------- Step 2: proof ----------
          _stepLabel(context, 2, 'Submit proof of payment'),
          const SizedBox(height: 6),
          Text(
            'Add the UTR number or a screenshot — either one works.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),

          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _utrController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'UTR / reference number',
                    hintText: 'e.g. 402912345678',
                    prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                    errorText: _utrError,
                  ),
                  onChanged: (_) {
                    if (_utrError != null) setState(() => _utrError = null);
                  },
                ),

                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('AND / OR',
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 18),

                if (_screenshot == null)
                  PillButton(
                    label: 'Attach screenshot',
                    icon: Icons.image_outlined,
                    variant: PillVariant.outline,
                    onPressed: _pickScreenshot,
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Image.file(
                          File(_screenshot!.path),
                          height: 170,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 170,
                            color: AppColors.grey100,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Screenshot attached',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.success),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _screenshot = null),
                            child: Text(
                              'Remove',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.pastelPink,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 17, color: AppColors.danger),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _error!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          PillButton(
            label: 'Submit for approval',
            loading: _submitting,
            onPressed: _canSubmit && !_submitting ? _submit : null,
          ),

          const SizedBox(height: AppSpacing.lg),

          // ---------- Honest expectation setting ----------
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.pastelOrange,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 18, color: AppColors.burned),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Payments are verified manually, so approval is not instant. '
                    'Your apps stay locked until the fine is approved — or until '
                    'you complete your push-ups.',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.grey700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _generatedQr() {
    return QrImageView(
      data: _upiUri,
      version: QrVersions.auto,
      size: 190,
      backgroundColor: AppColors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: AppColors.ink,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: AppColors.ink,
      ),
    );
  }

  Widget _stepLabel(BuildContext context, int step, String title) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.limeBright,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$step',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
