import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../providers/health_provider.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/admin_gate.dart';
import '../admin/admin_fines_screen.dart';
import '../admin/admin_settings_screen.dart';
import '../blocked_apps/blocked_apps_screen.dart';
import '../fines/fines_screen.dart';
import '../water/water_tracker_screen.dart';
import '../weight/weight_screen.dart';
import '../profile/achievements_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final health = context.watch<HealthProvider>();
    final user = userProvider.userModel;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                            width: 1, height: 34,
                            color: isDark ? AppColors.darkBorder : AppColors.grey200),
                        Expanded(
                          child: _metric(
                            context,
                            'BMI',
                            bmi > 0 ? bmi.toStringAsFixed(1) : '\u2014',
                            caption: bmi > 0 ? getBMICategory(bmi) : null,
                            captionColor: bmi > 0 ? _bmiColor(bmi) : null,
                          ),
                        ),
                        Container(
                            width: 1, height: 34,
                            color: isDark ? AppColors.darkBorder : AppColors.grey200),
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
                    InkWell(
                      onTap: () => _showWaterTargetSheet(context),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.water.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.water_drop_rounded,
                                size: 18, color: AppColors.water),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text('Water',
                                style: Theme.of(context).textTheme.titleSmall),
                          ),
                          Text(
                            '${((user?.dailyWaterTargetMl ?? 3000) / 1000).toStringAsFixed(1)} L',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_rounded,
                              size: 14,
                              color: isDark ? AppColors.grey500 : AppColors.grey300),
                        ],
                      ),
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
                    const Divider(height: 22),
                    _navRow(context, Icons.emoji_events_rounded,
                        AppColors.burned, 'Achievements',
                        () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AchievementsScreen()),
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
                  const SizedBox(height: 14),
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
                                    Icons.tune_rounded,
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
                                      'App settings',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              color: AppColors.white),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'UPI ID, payee name, fine amount',
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
                            label: 'Edit settings',
                            variant: PillVariant.lime,
                            icon: Icons.edit_rounded,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminSettingsScreen()),
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
                color: isDark ? AppColors.darkCard : AppColors.pastelGreen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 19,
                            color: isDark
                                ? AppColors.limeBright
                                : AppColors.limeDeep),
                        const SizedBox(width: 9),
                        Text('Privacy',
                            style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\u2022 Push-up video is processed on-device and never uploaded\n'
                      '\u2022 Food photos are stored privately in your own account\n'
                      '\u2022 Nutrition values are AI-estimated, not medical advice',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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

            const SizedBox(height: AppSpacing.xxl),

            // ---------- Delete account ----------
            Padding(
              padding: AppSpacing.page,
              child: PillButton(
                label: 'Delete Account',
                variant: PillVariant.danger,
                icon: Icons.delete_forever_rounded,
                onPressed: () => _confirmDeleteAccount(context),
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // ---------- App info footer ----------
            Center(
              child: Column(
                children: [
                  Text(
                    'HealthPush',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Earn your screen time',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value,
      {String? caption, Color? captionColor}) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        if (caption != null) ...[
          const SizedBox(height: 3),
          Text(
            caption,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: captionColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ],
    );
  }

  /// Colour-codes the BMI band so the number has context at a glance.
  static Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppColors.warning;
    if (bmi < 25.0) return AppColors.success;
    if (bmi < 30.0) return AppColors.warning;
    return AppColors.danger;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          Icon(Icons.chevron_right_rounded,
              size: 20, color: isDark ? AppColors.grey500 : AppColors.grey300),
        ],
      ),
    );
  }

  void _showWaterTargetSheet(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final health = context.read<HealthProvider>();
    final db = context.read<DatabaseService>();
    final user = userProvider.userModel;
    if (user == null) return;

    int currentMl = user.dailyWaterTargetMl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (innerContext, setState) {
          final sheetDark = Theme.of(innerContext).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(innerContext).viewInsets.bottom + 24,
              top: 20,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: sheetDark ? AppColors.darkSurface : AppColors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xxl),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetDark ? AppColors.darkBorder : AppColors.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.water.withOpacity(0.2),
                        AppColors.water.withOpacity(0.08),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.water_drop_rounded,
                      color: AppColors.water, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  'Daily Water Goal',
                  style: Theme.of(innerContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Adjust your daily hydration target',
                  style: Theme.of(innerContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 28),
                // Current value display
                Text(
                  '${(currentMl / 1000).toStringAsFixed(1)} L',
                  style: Theme.of(innerContext)
                      .textTheme
                      .displayMedium
                      ?.copyWith(color: AppColors.water),
                ),
                Text(
                  '${currentMl} ml',
                  style: Theme.of(innerContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                // Slider
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.water,
                    inactiveTrackColor: AppColors.water.withOpacity(0.15),
                    thumbColor: AppColors.water,
                    overlayColor: AppColors.water.withOpacity(0.12),
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10),
                  ),
                  child: Slider(
                    value: currentMl.toDouble(),
                    min: 1000,
                    max: 6000,
                    divisions: 20, // 250ml increments
                    onChanged: (value) {
                      setState(() => currentMl = value.round());
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1.0 L',
                        style: Theme.of(innerContext).textTheme.labelSmall),
                    Text('6.0 L',
                        style: Theme.of(innerContext).textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 28),
                PillButton(
                  label: 'Save Goal',
                  icon: Icons.check_rounded,
                  variant: PillVariant.lime,
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(innerContext);
                    try {
                      await db.updateWaterTarget(user.uid, currentMl);
                      health.setWaterTarget(currentMl);
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Delete your account?'),
        content: const Text(
          'This will permanently delete your account and all your data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await context.read<AuthService>().deleteAccount();
              } on Exception catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              }
            },
            child: const Text('Delete permanently',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
