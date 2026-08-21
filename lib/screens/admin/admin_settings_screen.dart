import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_settings_model.dart';
import '../../services/app_settings_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/soft_card.dart';

/// Admin screen for editing server-stored UPI / fine configuration.
///
/// Changes take effect immediately for all users because the fine payment
/// screen fetches from the server each time it opens.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _upiIdController = TextEditingController();
  final _payeeNameController = TextEditingController();
  final _amountController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _payeeNameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await context
          .read<AppSettingsService>()
          .getSettings(forceRefresh: true);
      if (!mounted) return;
      _upiIdController.text = settings.upiId;
      _payeeNameController.text = settings.upiPayeeName;
      _amountController.text = settings.fineAmountPaise.toString();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load settings: $e';
      });
    }
  }

  String? _validate() {
    final upiId = _upiIdController.text.trim();
    final payeeName = _payeeNameController.text.trim();
    final amountText = _amountController.text.trim();

    if (upiId.isEmpty || !upiId.contains('@')) {
      return 'UPI ID must contain an "@" (e.g. name@bank)';
    }
    if (payeeName.isEmpty) {
      return 'Payee name cannot be empty';
    }
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      return 'Fine amount must be a positive number (in paise)';
    }
    return null;
  }

  Future<void> _save() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await context.read<AppSettingsService>().updateSettings(
            upiId: _upiIdController.text.trim(),
            upiPayeeName: _payeeNameController.text.trim(),
            fineAmountPaise: int.parse(_amountController.text.trim()),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.pop(context);
    } on AppSettingsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('App Settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UPI Payment Details',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _upiIdController,
                        decoration: const InputDecoration(
                          labelText: 'UPI ID',
                          hintText: 'e.g. name@bank',
                          prefixIcon:
                              Icon(Icons.account_balance_rounded, size: 20),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _payeeNameController,
                        decoration: const InputDecoration(
                          labelText: 'Payee name',
                          hintText: 'e.g. RepGate',
                          prefixIcon: Icon(Icons.person_rounded, size: 20),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fine Amount',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount (paise)',
                          hintText: 'e.g. 5000 for \u20B950',
                          prefixIcon:
                              Icon(Icons.currency_rupee_rounded, size: 20),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _amountPreview(),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.grey500),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
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
                const SizedBox(height: AppSpacing.xxl),
                PillButton(
                  label: 'Save settings',
                  loading: _saving,
                  icon: Icons.check_rounded,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
    );
  }

  String _amountPreview() {
    final paise = int.tryParse(_amountController.text.trim());
    if (paise == null || paise <= 0) return '';
    return '= \u20B9${(paise / 100).toStringAsFixed(2)}';
  }
}
