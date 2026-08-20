import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/health_provider.dart';
import '../../services/platform_channel_service.dart';
import '../../models/blocked_apps_config_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';

class BlockedAppsScreen extends StatefulWidget {
  const BlockedAppsScreen({super.key});

  @override
  State<BlockedAppsScreen> createState() => _BlockedAppsScreenState();
}

class _BlockedAppsScreenState extends State<BlockedAppsScreen> {
  Set<String> _blocked = {};
  List<Map<String, String>> _installed = [];
  bool _loading = true;
  bool _saving = false;

  /// The blocked-apps config arrives asynchronously over a Firestore stream,
  /// so it is usually still null on first build. We seed the switches the
  /// first time it actually lands — otherwise every toggle would render off
  /// and saving would wipe the user's existing selection.
  bool _hydrated = false;

  // Permission state
  bool _accessibility = false;
  bool _overlay = false;
  bool _battery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final native = context.read<PlatformChannelService>();
    try {
      final results = await Future.wait([
        native.getInstalledApps(),
        native.isAccessibilityServiceEnabled(),
        native.hasOverlayPermission(),
        native.isBatteryOptimizationDisabled(),
      ]);
      if (!mounted) return;
      setState(() {
        _installed = results[0] as List<Map<String, String>>;
        _accessibility = results[1] as bool;
        _overlay = results[2] as bool;
        _battery = results[3] as bool;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Installed apps if native returned them; otherwise the curated suggestions.
  List<({String package, String name})> get _candidates {
    if (_installed.isNotEmpty) {
      return _installed
          .map((a) => (
                package: a['packageName'] ?? '',
                name: a['appName'] ?? a['packageName'] ?? '',
              ))
          .where((a) =>
              a.package.isNotEmpty &&
              !AppConstants.defaultAllowlistPackages.contains(a.package))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return AppConstants.suggestedBlockApps.entries
        .map((e) => (package: e.key, name: e.value))
        .toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final health = context.read<HealthProvider>();
    final native = context.read<PlatformChannelService>();

    final existing = health.blockedAppsConfig;
    final config = BlockedAppsConfigModel(
      blockedPackages: _blocked.toList(),
      allowlistPackages:
          existing?.allowlistPackages ?? AppConstants.defaultAllowlistPackages,
      lastUnlockedAt: existing?.lastUnlockedAt,
    );

    try {
      await health.updateBlockedApps(config);
      await native.updateBlockedApps(config.blockedPackages);
      await native.updateAllowlist(config.allowlistPackages);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_blocked.length} apps will be blocked')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Seed the selection the first time the streamed config arrives.
    // Safe to assign during build: we consume the new value immediately
    // in this same pass, so no setState is needed.
    final config = context.watch<HealthProvider>().blockedAppsConfig;
    if (!_hydrated && config != null) {
      _hydrated = true;
      _blocked = {...config.blockedPackages};
    }

    final allPermissionsOk = _accessibility && _overlay && _battery;

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
        title: const Text('Blocked Apps'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                // ---------- Permissions gate ----------
                if (!allPermissionsOk) ...[
                  SoftCard(
                    color: AppColors.pastelOrange,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.burned, size: 20),
                            const SizedBox(width: 9),
                            Text('Setup required',
                                style:
                                    Theme.of(context).textTheme.titleSmall),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'App blocking needs these permissions to work reliably.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        _permRow(
                          'Accessibility Service',
                          'Detects which app is in the foreground',
                          _accessibility,
                          () => context
                              .read<PlatformChannelService>()
                              .openAccessibilitySettings(),
                        ),
                        const SizedBox(height: 10),
                        _permRow(
                          'Display over other apps',
                          'Draws the lock screen over blocked apps',
                          _overlay,
                          () => context
                              .read<PlatformChannelService>()
                              .requestOverlayPermission(),
                        ),
                        const SizedBox(height: 10),
                        _permRow(
                          'Disable battery optimisation',
                          'Stops Xiaomi/Oppo/Vivo from killing the service',
                          _battery,
                          () => context
                              .read<PlatformChannelService>()
                              .requestDisableBatteryOptimization(),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Re-check permissions'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // ---------- Known limitation disclosure ----------
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: AppColors.grey500),
                          const SizedBox(width: 9),
                          Text('Known limitation',
                              style: Theme.of(context).textTheme.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Blocking only works on this device. If you open these apps on '
                        'another phone, tablet, or the web, they will not be blocked. '
                        'This system relies on your own commitment, not perfect enforcement.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                SectionHeader(
                  title: 'Select apps to block',
                  actionLabel: '${_blocked.length} selected',
                ),

                SoftCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < _candidates.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _appRow(_candidates[i]),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ---------- Allowlist info ----------
                SoftCard(
                  color: AppColors.pastelGreen,
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          size: 19, color: AppColors.limeDeep),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Calls, SMS, payment apps and emergency dialler are always '
                          'allowed and can never be blocked.',
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: PillButton(
          label: 'Save selection',
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }

  Widget _permRow(
      String title, String subtitle, bool granted, VoidCallback onFix) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 19,
          color: granted ? AppColors.success : AppColors.grey300,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        if (!granted)
          GestureDetector(
            onTap: onFix,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: AppRadius.chip,
              ),
              child: const Text(
                'Grant',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _appRow(({String package, String name}) app) {
    final selected = _blocked.contains(app.package);
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: selected,
      activeColor: AppColors.limeDeep,
      title: Text(app.name, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(
        app.package,
        style: Theme.of(context).textTheme.labelSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onChanged: (v) {
        setState(() {
          if (v) {
            _blocked.add(app.package);
          } else {
            _blocked.remove(app.package);
          }
        });
      },
    );
  }
}
