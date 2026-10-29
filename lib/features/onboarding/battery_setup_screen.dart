import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/family_member.dart';
import '../../providers/preferences_provider.dart';
import '../../services/oem_detector.dart';

/// First-run wizard that walks the user through disabling OEM battery
/// optimizations for Sylvie. Each OEM gets its own checklist, generated
/// from a shared data structure so adding a brand is one entry.
///
/// When [onDone] is omitted, the wizard marks the "battery setup done"
/// flag in preferences and relies on AuthGate rebuilding to advance.
class BatterySetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onDone;
  const BatterySetupScreen({super.key, this.onDone});

  @override
  ConsumerState<BatterySetupScreen> createState() => _BatterySetupScreenState();
}

class _BatterySetupScreenState extends ConsumerState<BatterySetupScreen> {
  OemReport? _report;
  final Set<int> _confirmed = {};

  @override
  void initState() {
    super.initState();
    _loadOem();
  }

  Future<void> _loadOem() async {
    final r = await OemDetector().detect();
    if (mounted) setState(() => _report = r);
  }

  List<_Step> _stepsFor(PhoneOem oem) => _oemSteps[oem] ?? _oemSteps[PhoneOem.other]!;

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final steps = _stepsFor(report.oem);
    final allDone = _confirmed.length == steps.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Battery setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Phone: ${report.manufacturer} ${report.model}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            report.isAggressiveKiller
                ? 'Yeh phone background apps ko kill karta hai. '
                    'Niche ke steps karne zaruri hain, warna Sylvie location '
                    'bheje bina ruk jaayegi.'
                : 'Yeh phone usually fine hai, phir bhi ek check kar lo.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (i) {
            final s = steps[i];
            final done = _confirmed.contains(i);
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(s.title),
                subtitle: Text(s.detail),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s.openSetting != null)
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'Open settings',
                        onPressed: () => AppSettings.openAppSettings(type: s.openSetting!),
                      ),
                    Checkbox(
                      value: done,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _confirmed.add(i);
                        } else {
                          _confirmed.remove(i);
                        }
                      }),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: allDone ? _finish : null,
            child: Text(allDone ? 'Done — continue' : 'Finish all steps to continue'),
          ),
          TextButton(
            onPressed: _finish,
            child: const Text('Skip for now (not recommended)'),
          ),
        ],
      ),
    );
  }

  Future<void> _finish() async {
    await ref.read(batterySetupDoneProvider.notifier).markDone();
    widget.onDone?.call();
  }
}

class _Step {
  final String title;
  final String detail;
  final AppSettingsType? openSetting;
  const _Step(this.title, this.detail, {this.openSetting});
}

/// Canonical step lists per OEM. Menu wording changes between OS versions,
/// so each step keeps the detail short and generic; the "open settings"
/// icon jumps the user to the closest system screen we can deep-link to.
const Map<PhoneOem, List<_Step>> _oemSteps = {
  PhoneOem.vivo: [
    _Step(
      'Allow background activity',
      'Settings → Battery → Background power consumption → Sylvie → Allow',
      openSetting: AppSettingsType.batteryOptimization,
    ),
    _Step(
      'Enable Autostart',
      'Settings → Apps → Sylvie → Autostart → ON',
      openSetting: AppSettingsType.appSettings,
    ),
    _Step(
      'Location: Allow all the time',
      'Settings → Apps → Sylvie → Permissions → Location → Allow all the time',
      openSetting: AppSettingsType.location,
    ),
    _Step(
      'Lock in recents',
      'Open recent apps, pull down the Sylvie card, tap the lock icon',
    ),
  ],
  PhoneOem.oppo: [
    _Step(
      'Allow background activity + auto-launch',
      'Settings → Battery → App Battery Management → Sylvie → Allow both',
      openSetting: AppSettingsType.batteryOptimization,
    ),
    _Step(
      'Location: Allow all the time',
      'Settings → Privacy → Permission Manager → Location → Sylvie',
      openSetting: AppSettingsType.location,
    ),
    _Step(
      'Lock in recents',
      'Open recents, long-press Sylvie card, tap lock',
    ),
  ],
  PhoneOem.realme: [
    _Step(
      'Allow background activity + auto-launch',
      'Settings → Battery → App Battery Management → Sylvie → Allow both',
      openSetting: AppSettingsType.batteryOptimization,
    ),
    _Step(
      'Location: Allow all the time',
      'Settings → Privacy → Permission Manager → Location',
      openSetting: AppSettingsType.location,
    ),
    _Step('Lock in recents', 'Open recents, long-press Sylvie card, tap lock'),
  ],
  PhoneOem.xiaomi: [
    _Step(
      'No battery restrictions',
      'Settings → Apps → Manage apps → Sylvie → Battery saver → No restrictions',
      openSetting: AppSettingsType.batteryOptimization,
    ),
    _Step(
      'Enable Autostart',
      'Settings → Apps → Manage apps → Sylvie → Autostart → ON',
      openSetting: AppSettingsType.appSettings,
    ),
    _Step(
      'Location: Allow all the time',
      'Settings → Apps → Manage apps → Sylvie → Permissions → Location',
      openSetting: AppSettingsType.location,
    ),
    _Step('Lock in recents', 'Open recents, pull down Sylvie card, tap lock'),
  ],
  PhoneOem.samsung: [
    _Step(
      'Battery: Unrestricted',
      'Settings → Apps → Sylvie → Battery → Unrestricted',
      openSetting: AppSettingsType.batteryOptimization,
    ),
    _Step(
      'Location: Allow all the time',
      'Settings → Apps → Sylvie → Permissions → Location',
      openSetting: AppSettingsType.location,
    ),
    _Step(
      'Never sleeping apps',
      'Settings → Device care → Battery → Background usage limits → Never sleeping apps → add Sylvie',
      openSetting: AppSettingsType.batteryOptimization,
    ),
  ],
  PhoneOem.oneplus: [
    _Step(
      "Don't optimise battery",
      'Settings → Battery → Battery optimisation → Sylvie → Don\'t optimise',
      openSetting: AppSettingsType.batteryOptimization,
    ),
    _Step(
      'Location: Allow all the time',
      'Settings → Apps → Sylvie → Permissions → Location',
      openSetting: AppSettingsType.location,
    ),
    _Step('Lock in recents', 'Open recents, long-press Sylvie card, tap lock'),
  ],
  PhoneOem.pixel: [
    _Step(
      'Battery: Unrestricted',
      'Settings → Apps → Sylvie → App battery usage → Unrestricted',
      openSetting: AppSettingsType.batteryOptimization,
    ),
    _Step(
      'Location: Allow all the time',
      'Settings → Apps → Sylvie → Permissions → Location',
      openSetting: AppSettingsType.location,
    ),
  ],
  PhoneOem.motorola: [
    _Step(
      "Don't optimise battery",
      'Settings → Battery → Battery optimisation → Sylvie',
      openSetting: AppSettingsType.batteryOptimization,
    ),
    _Step(
      'Location: Allow all the time',
      'Settings → Apps → Sylvie → Permissions → Location',
      openSetting: AppSettingsType.location,
    ),
  ],
  PhoneOem.nothing: [
    _Step(
      'Battery: Unrestricted',
      'Settings → Apps → Sylvie → Battery → Unrestricted',
      openSetting: AppSettingsType.batteryOptimization,
    ),
    _Step(
      'Location: Allow all the time',
      'Settings → Apps → Sylvie → Permissions → Location',
      openSetting: AppSettingsType.location,
    ),
  ],
  PhoneOem.other: [
    _Step(
      'Battery optimisation OFF for Sylvie',
      "In Settings → Apps → Sylvie, remove any battery restrictions.",
      openSetting: AppSettingsType.batteryOptimization,
    ),
    _Step(
      'Location: Allow all the time',
      'Grant Sylvie location permission as "Allow all the time", not just "While using".',
      openSetting: AppSettingsType.location,
    ),
  ],
};
