import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/soft_card.dart';

/// Screen for managing notification preferences.
/// Each toggle updates the notification_preferences table via NotificationService.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _saving = false;

  bool _lunchReminder = true;
  bool _pushupReminder = true;
  bool _streakAlerts = true;
  bool _proteinTips = true;
  bool _weeklySummary = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs =
        await NotificationService.instance.getNotificationPreferences();
    if (prefs != null && mounted) {
      setState(() {
        _lunchReminder = prefs['lunch_reminder'] ?? true;
        _pushupReminder = prefs['pushup_reminder'] ?? true;
        _streakAlerts = prefs['streak_alerts'] ?? true;
        _proteinTips = prefs['protein_tips'] ?? true;
        _weeklySummary = prefs['weekly_summary'] ?? true;
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _savePreference(String key, bool value) async {
    setState(() => _saving = true);
    await NotificationService.instance.updateNotificationPreferences(
      <String, dynamic>{key: value},
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              children: [
                Text(
                  'Smart Reminders',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Contextual notifications based on your daily habits.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                SoftCard(
                  child: Column(
                    children: [
                      _buildToggle(
                        icon: Icons.restaurant_rounded,
                        color: AppColors.warning,
                        title: 'Lunch reminder',
                        subtitle: 'Remind at 2pm if lunch not logged',
                        value: _lunchReminder,
                        onChanged: (v) {
                          setState(() => _lunchReminder = v);
                          _savePreference('lunch_reminder', v);
                        },
                      ),
                      const Divider(height: 24),
                      _buildToggle(
                        icon: Icons.fitness_center_rounded,
                        color: AppColors.protein,
                        title: 'Pushup reminder',
                        subtitle: 'Notify at your usual workout time',
                        value: _pushupReminder,
                        onChanged: (v) {
                          setState(() => _pushupReminder = v);
                          _savePreference('pushup_reminder', v);
                        },
                      ),
                      const Divider(height: 24),
                      _buildToggle(
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.burned,
                        title: 'Streak alerts',
                        subtitle: 'Celebrate streaks and encourage consistency',
                        value: _streakAlerts,
                        onChanged: (v) {
                          setState(() => _streakAlerts = v);
                          _savePreference('streak_alerts', v);
                        },
                      ),
                      const Divider(height: 24),
                      _buildToggle(
                        icon: Icons.egg_alt_rounded,
                        color: AppColors.success,
                        title: 'Protein tips',
                        subtitle: 'Evening reminder if protein is low',
                        value: _proteinTips,
                        onChanged: (v) {
                          setState(() => _proteinTips = v);
                          _savePreference('protein_tips', v);
                        },
                      ),
                      const Divider(height: 24),
                      _buildToggle(
                        icon: Icons.bar_chart_rounded,
                        color: AppColors.water,
                        title: 'Weekly summary',
                        subtitle: 'Sunday recap of your week',
                        value: _weeklySummary,
                        onChanged: (v) {
                          setState(() => _weeklySummary = v);
                          _savePreference('weekly_summary', v);
                        },
                      ),
                    ],
                  ),
                ),
                if (_saving) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.13),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.limeBright,
        ),
      ],
    );
  }
}
