import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fine_model.dart';
import '../../services/auth_service.dart';
import '../../services/fine_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/soft_card.dart';
import 'fine_payment_screen.dart';

/// The user's own fines and their review status.
class FinesScreen extends StatelessWidget {
  const FinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    final fineService = context.read<FineService>();

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
        title: const Text('Fines'),
      ),
      body: uid == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<List<FineModel>>(
              stream: fineService.streamMyFines(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load fines: ${snapshot.error}'),
                    ),
                  );
                }

                final fines = snapshot.data ?? const <FineModel>[];
                if (fines.isEmpty) return const _NoFines();

                final outstanding =
                    fines.where((f) => f.status.isOutstanding).toList();
                final totalDue = outstanding.fold<int>(
                    0, (sum, f) => sum + f.amount);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    if (outstanding.isNotEmpty) ...[
                      SoftCard(
                        color: AppColors.pastelPink,
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.danger.withOpacity(0.13),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.gavel_rounded,
                                  color: AppColors.danger, size: 21),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '₹${(totalDue / 100).toStringAsFixed(0)} outstanding',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${outstanding.length} unpaid fine${outstanding.length == 1 ? '' : 's'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    for (final fine in fines) ...[
                      _FineCard(fine: fine),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _NoFines extends StatelessWidget {
  const _NoFines();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 16),
            Text('No fines', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Keep showing up and it stays this way.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FineCard extends StatelessWidget {
  const _FineCard({required this.fine});

  final FineModel fine;

  ({Color bg, Color fg, IconData icon}) get _statusStyle =>
      switch (fine.status) {
        FineStatus.pending => (
            bg: AppColors.pastelPink,
            fg: AppColors.danger,
            icon: Icons.error_outline_rounded,
          ),
        FineStatus.submitted => (
            bg: AppColors.pastelOrange,
            fg: AppColors.burned,
            icon: Icons.hourglass_top_rounded,
          ),
        FineStatus.approved => (
            bg: AppColors.limeSoft,
            fg: AppColors.limeDeep,
            icon: Icons.check_circle_rounded,
          ),
        FineStatus.rejected => (
            bg: AppColors.pastelPink,
            fg: AppColors.danger,
            icon: Icons.cancel_rounded,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fine.amountLabel,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      '${fine.reasonLabel} · ${formatDate(fine.createdAt)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: AppRadius.chip,
                ),
                child: Row(
                  children: [
                    Icon(style.icon, size: 14, color: style.fg),
                    const SizedBox(width: 5),
                    Text(
                      fine.status.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: style.fg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Submitted proof summary
          if (fine.upiUtr != null || fine.screenshotUrl != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      size: 16, color: AppColors.grey500),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      fine.upiUtr != null
                          ? 'UTR ${fine.upiUtr}'
                          : 'Screenshot submitted',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  if (fine.screenshotUrl != null && fine.upiUtr != null)
                    const Icon(Icons.image_rounded,
                        size: 15, color: AppColors.grey500),
                ],
              ),
            ),
          ],

          // Admin's rejection reason
          if (fine.status == FineStatus.rejected &&
              (fine.reviewNote?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.pastelPink,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      fine.reviewNote!,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action
          if (fine.status.isOutstanding) ...[
            const SizedBox(height: 16),
            PillButton(
              label: fine.status == FineStatus.rejected
                  ? 'Resubmit payment'
                  : 'Pay this fine',
              icon: Icons.qr_code_rounded,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FinePaymentScreen(fine: fine),
                ),
              ),
            ),
          ] else if (fine.status.isAwaitingReview) ...[
            const SizedBox(height: 12),
            Text(
              'Submitted ${fine.submittedAt != null ? formatDateTime(fine.submittedAt!) : ''} — waiting for approval.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
