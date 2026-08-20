import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fine_model.dart';
import '../../services/fine_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/soft_card.dart';

/// Admin review queue for manually-settled UPI fines.
///
/// Visibility here is a convenience only — `approveFine` / `rejectFine` are
/// Cloud Functions that re-verify the admin claim server-side, so reaching
/// this screen without the claim grants no actual power.
class AdminFinesScreen extends StatefulWidget {
  const AdminFinesScreen({super.key});

  @override
  State<AdminFinesScreen> createState() => _AdminFinesScreenState();
}

class _AdminFinesScreenState extends State<AdminFinesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Fine Review'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SegmentedToggle(
              options: const ['Pending', 'Reviewed'],
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<FineModel>>(
              stream: _tab == 0
                  ? fineService.streamReviewQueue()
                  : fineService.streamRecentlyReviewed(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(error: '${snapshot.error}');
                }

                final fines = snapshot.data ?? const <FineModel>[];
                if (fines.isEmpty) {
                  return _EmptyState(
                    emoji: _tab == 0 ? '✅' : '📭',
                    title: _tab == 0
                        ? 'Nothing to review'
                        : 'No reviewed fines yet',
                    subtitle: _tab == 0
                        ? 'Submitted payments will appear here.'
                        : 'Approved and rejected fines show up here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  itemCount: fines.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) => _ReviewCard(
                    fine: fines[i],
                    reviewable: _tab == 0,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.fine, required this.reviewable});

  final FineModel fine;
  final bool reviewable;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _busy = false;

  Future<void> _approve() async {
    final confirmed = await _confirm(
      title: 'Approve this fine?',
      body: 'The fine will be marked paid and the user gets a 24-hour unlock.',
      confirmLabel: 'Approve',
      danger: false,
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await context.read<FineService>().approveFine(
            targetUid: widget.fine.uid,
            fineId: widget.fine.id,
          );
      _toast('Fine approved — marked as paid.');
    } on FineException catch (e) {
      _toast(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await _askReason();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      await context.read<FineService>().rejectFine(
            targetUid: widget.fine.uid,
            fineId: widget.fine.id,
            reason: reason,
          );
      _toast('Fine rejected — still unpaid.');
    } on FineException catch (e) {
      _toast(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    required bool danger,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: danger ? AppColors.danger : AppColors.limeDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Reject payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The user will see this reason and can resubmit.',
              style: TextStyle(fontSize: 13, color: AppColors.grey500),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. UTR not found in my statement',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Reject',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _viewScreenshot(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InteractiveViewer(
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 220,
                    color: AppColors.grey100,
                    alignment: Alignment.center,
                    child: const Text('Could not load screenshot'),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 220,
                      color: AppColors.grey100,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            PillButton(
              label: 'Close',
              variant: PillVariant.lime,
              expand: false,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fine = widget.fine;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- Amount + status ----------
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fine.amountLabel,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(fine.reasonLabel,
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              if (!widget.reviewable)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: fine.status == FineStatus.approved
                        ? AppColors.limeSoft
                        : AppColors.pastelPink,
                    borderRadius: AppRadius.chip,
                  ),
                  child: Text(
                    fine.status.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: fine.status == FineStatus.approved
                          ? AppColors.limeDeep
                          : AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // ---------- Proof ----------
          _kv(context, 'User', fine.uid, mono: true),
          const SizedBox(height: 8),
          _kv(
            context,
            'UTR',
            fine.upiUtr ?? '— not provided —',
            mono: fine.upiUtr != null,
            emphasise: fine.upiUtr != null,
          ),
          const SizedBox(height: 8),
          _kv(
            context,
            'Submitted',
            fine.submittedAt != null
                ? formatDateTime(fine.submittedAt!)
                : '—',
          ),

          if (fine.screenshotUrl != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _viewScreenshot(fine.screenshotUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Stack(
                  children: [
                    Image.network(
                      fine.screenshotUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 150,
                        color: AppColors.grey100,
                        alignment: Alignment.center,
                        child: const Text('Screenshot unavailable'),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 150,
                          color: AppColors.grey100,
                        );
                      },
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: AppRadius.chip,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.zoom_in_rounded,
                                size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Tap to zoom',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ---------- Review note (already-reviewed tab) ----------
          if (!widget.reviewable &&
              (fine.reviewNote?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Note: ${fine.reviewNote}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],

          // ---------- Actions ----------
          if (widget.reviewable) ...[
            const SizedBox(height: 18),
            if (_busy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Reject',
                      variant: PillVariant.outline,
                      onPressed: _reject,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PillButton(
                      label: 'Approve',
                      variant: PillVariant.lime,
                      onPressed: _approve,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _kv(
    BuildContext context,
    String label,
    String value, {
    bool mono = false,
    bool emphasise = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: mono ? 'monospace' : null,
                  fontWeight: emphasise ? FontWeight.w800 : FontWeight.w500,
                  color: emphasise ? AppColors.ink : null,
                ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 50)),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    // A missing composite index is the most common first-run failure here.
    final looksLikeIndexError = error.contains('index');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 42, color: AppColors.warning),
            const SizedBox(height: 16),
            Text(
              looksLikeIndexError
                  ? 'Firestore index required'
                  : 'Could not load the queue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              looksLikeIndexError
                  ? 'Deploy firestore.indexes.json, or open the link in the '
                      'error below to create the collection-group index.'
                  : error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
