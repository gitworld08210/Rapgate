import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';

/// Screen for managing daily reminder notifications (push-ups, food, water).
class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  // TODO: Persist these preferences with SharedPreferences
  bool _pushupEnabled = false;
  bool _foodLogEnabled = false;
  bool _waterEnabled = false;
  TimeOfDay _pushupTime = const TimeOfDay(hour: 7, minute: 0);

  final _notificationService = NotificationService.instance;

  Future<void> _togglePushup(bool value) async {
    setState(() => _pushupEnabled = value);
    if (value) {
      await _notificationService.scheduleDailyPushupReminder(_pushupTime);
    } else {
      await _notificationService.cancelPushupReminder();
    }
  }

  Future<void> _toggleFoodLog(bool value) async {
    setState(() => _foodLogEnabled = value);
    if (value) {
      await _notificationService.scheduleDailyFoodLogReminder();
    } else {
      await _notificationService.cancelFoodLogReminders();
    }
  }

  Future<void> _toggleWater(bool value) async {
    setState(() => _waterEnabled = value);
    if (value) {
      await _notificationService.scheduleWaterReminders();
    } else {
      await _notificationService.cancelWaterReminders();
    }
  }

  Future<void> _pickPushupTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _pushupTime,
    );
    if (picked != null) {
      setState(() => _pushupTime = picked);
      if (_pushupEnabled) {
        await _notificationService.scheduleDailyPushupReminder(picked);
      }
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
        title: const Text('Reminders'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ---------- Push-up reminder ----------
          SoftCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.limeBright.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.fitness_center_rounded,
                          color: AppColors.limeDeep, size: 20),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Push-up Reminder',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            'Daily reminder to complete your push-ups',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _pushupEnabled,
                      onChanged: _togglePushup,
                      activeColor: AppColors.limeBright,
                    ),
                  ],
                ),
                if (_pushupEnabled) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickPushupTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 18, color: AppColors.grey500),
                        const SizedBox(width: 10),
                        Text(
                          'Reminder time',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.grey100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _pushupTime.format(context),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ---------- Food log reminder ----------
          SoftCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.burned.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.restaurant_rounded,
                      color: AppColors.burned, size: 20),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Food Log Reminders',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        '8 AM, 12 PM & 7 PM daily',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _foodLogEnabled,
                  onChanged: _toggleFoodLog,
                  activeColor: AppColors.limeBright,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ---------- Water reminder ----------
          SoftCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.water.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.water_drop_rounded,
                      color: AppColors.water, size: 20),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Water Reminders',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Every 2 hours (8 AM - 10 PM)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _waterEnabled,
                  onChanged: _toggleWater,
                  activeColor: AppColors.limeBright,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ---------- Info note ----------
          SoftCard(
            color: AppColors.pastelGreen,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.limeDeep),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reminders use local notifications and work offline. '
                    'Make sure notifications are enabled in your device settings.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
