import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../providers/health_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/admin_gate.dart';
import '../admin/admin_fines_screen.dart';
import '../blocked_apps/blocked_apps_screen.dart';
import '../fines/fines_screen.dart';
import '../water/water_tracker_screen.dart';
import '../weight/weight_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final health = context.watch<HealthProvider>();
    final user = userProvider.userModel;

    final bmi = (user != null && user.height > 0)
        ? calculateBMI(user.weight, user.height)
        : 0.0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            Padding(
              padding: AppSpacing.page,
              child: Text('Profile',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ---------- Profile card ----------
            Padding(
              padding: AppSpacing.page,
              child: SoftCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.limeSoft,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (user?.name.isNotEmpty ?? false)
                            ? user!.name[0].toUpperCase()
                            : '?',
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(color: AppColors.ink),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(user?.name ?? 'Your profile',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      user == null
                          ? ''
                          : '${user.age} yrs · ${user.gender} · ${user.height.toStringAsFixed(0)} cm',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _metric(context, 'Weight',
                              '${(user?.weight ?? 0).toStringAsFixed(1)} kg'),
                        ),
                        Container(
                            width: 1, height: 34, color: AppColors.grey200),
                        Expanded(
                          child: _metric(
                              context,
                              'BMI',
                              bmi > 0
                                  ? bmi.toStringAsFixed(1)
                                  : '—'),
                        ),
                        Container(
                            width: 1, height: 34, color: AppColors.grey200),
                        Expanded(
                          child: _metric(context, 'Target',
                              '${user?.pushupTarget ?? 10} reps'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---------- Nutrition targets ----------
            Padding(
              padding: AppSpacing.page,
              child: SectionHeader(title: 'Daily targets'),
            ),
            Padding(
              padding: AppSpacing.page,
              child: SoftCard(
                child: Column(
                  children: [
                    _row(
                      context,
                      Icons.local_fire_department_rounded,
                      AppColors.burned,
                      'Calories',
                      '${(user?.dailyCalorieTarget ?? 0).toStringAsFixed(0)} kcal',
                    ),
                    const Divider(height: 22),
                    _row(
                      context,
                      Icons.egg_alt_rounded,
                      AppColors.protein,
                      'Protein',
                      '${(user?.dailyProteinTarget ?? 0).toStringAsFixed(0)} g',
                    ),
                    const Divider(height: 22),
                    _row(
                      context,
                      Icons.water_drop_rounded,
                      AppColors.water,
                      'Water',
                      '${((user?.dailyWaterTargetMl ?? 3000) / 1000).toStringAsFixed(1)} L',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---------- Trackers ----------
            Padding(
              padding: AppSpacing.page,
              child: SectionHeader(title: 'Trackers'),
            ),
            Padding(
              padding: AppSpacing.page,
              child: SoftCard(
                child: Column(
                  children: [
                    _navRow(context, Icons.water_drop_rounded,
                        AppColors.water, 'Water intake',
                        () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const WaterTrackerScreen()),
                            )),
                    const Divider(height: 22),
                    _navRow(context, Icons.monitor_weight_rounded,
                        AppColors.protein, 'Weight progress',
                        () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const WeightScreen()),
                            )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---------- App lock ----------
            Padding(
              padding: AppSpacing.page,
              child: SectionHeader(title: 'App lock'),
            ),
            Padding(
              padding: AppSpacing.page,
              child: SoftCard(
                child: Column(
                  children: [
                    _navRow(
                      context,
                      Icons.block_rounded,
                      AppColors.danger,
                      'Blocked apps',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BlockedAppsScreen()),
                      ),
                      trailing:
                          '${health.blockedAppsConfig?.blockedPackages.length ?? 0}',
                    ),
                    const Divider(height: 22),
                    _navRow(
                      context,
                      Icons.gavel_rounded,
                      AppColors.warning,
                      'My fines',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FinesScreen()),
                      ),
                      trailing: health.outstandingFines.isEmpty
                          ? 'None'
                          : '₹${(health.totalOutstandingFineAmount / 100).toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
            ),

            // ---------- Admin (only rendered for the allowlisted account) ----------
            AdminGate(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  Padding(
                    padding: AppSpacing.page,
                    child: SectionHeader(title: 'Admin'),
                  ),
                  Padding(
                    padding: AppSpacing.page,
                    child: SoftCard(
                      color: AppColors.ink,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.limeBright.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                    Icons.admin_panel_settings_rounded,
                                    color: AppColors.limeBright,
                                    size: 20),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fine review queue',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              color: AppColors.white),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Approve or reject UPI payments',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: Colors.white54),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          PillButton(
                            label: 'Open review queue',
                            variant: PillVariant.lime,
                            icon: Icons.fact_check_outlined,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminFinesScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---------- Privacy ----------
            Padding(
              padding: AppSpacing.page,
              child: SoftCard(
                color: AppColors.pastelGreen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 19, color: AppColors.limeDeep),
                        const SizedBox(width: 9),
                        Text('Privacy',
                            style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Push-up video is processed on-device and never uploaded\n'
                      '• Food photos are stored privately in your own account\n'
                      '• Nutrition values are AI-estimated, not medical advice',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---------- Danger zone ----------
            Padding(
              padding: AppSpacing.page,
              child: SoftCard(
                child: InkWell(
                  onTap: () => _confirmDeleteAccount(context),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.delete_forever_rounded,
                            size: 18, color: AppColors.danger),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          'Delete Account',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: AppColors.danger),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 20, color: AppColors.grey300),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            Padding(
              padding: AppSpacing.page,
              child: PillButton(
                label: 'Sign out',
                variant: PillVariant.outline,
                icon: Icons.logout_rounded,
                onPressed: () => _confirmSignOut(context, userProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _row(BuildContext context, IconData icon, Color tint, String label,
      String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tint.withOpacity(0.13),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: tint),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _navRow(BuildContext context, IconData icon, Color tint,
      String label, VoidCallback onTap,
      {String? trailing}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withOpacity(0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (trailing != null)
            Text(trailing, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.grey300),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              userProvider.signOut();
            },
            child: const Text('Sign out',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    // Capture services and messenger before async gap to avoid using a
    // potentially unmounted BuildContext after awaits.
    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account and all associated data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            // TODO(server-cleanup): A `deleteUserData` Cloud Function triggered
            // on `auth.user().onDelete()` should cascade Firestore document and
            // Cloud Storage cleanup. Currently only the Firebase Auth user is
            // removed; Firestore docs, storage files, and FCM tokens remain
            // orphaned.
            //
            // TODO(requires-recent-login): `FirebaseAuth.currentUser?.delete()`
            // throws `requires-recent-login` if the session is old. The UI
            // currently shows a generic error but does not prompt
            // re-authentication. A re-auth flow (e.g. re-verify phone OTP)
            // should be triggered when this specific error is caught.
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await authService.deleteAccount();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete account: $e'),
                  ),
                );
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
