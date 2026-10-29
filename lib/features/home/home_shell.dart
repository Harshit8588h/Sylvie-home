import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/alert_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/zone_provider.dart';
import '../alerts/alerts_screen.dart';
import '../map/map_screen.dart';
import '../zones/zones_list_screen.dart';
import 'family_dashboard_screen.dart';

/// Family / Map / Zones / Alerts tabs. Also the single place where every
/// background service gets started once we have:
///   - a signed-in user with a uid
///   - a family id in /user_memberships/{uid}
///   - any location permission
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool _servicesStarted = false;
  Set<String>? _seenAlertIds;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final familyId = ref.watch(currentFamilyIdProvider).valueOrNull;
    final perm = ref.watch(locationPermissionProvider);

    final hasPerm = perm == LocationPermissionLevel.whileInUse ||
        perm == LocationPermissionLevel.always;

    if (!_servicesStarted &&
        uid != null &&
        familyId != null &&
        hasPerm) {
      _servicesStarted = true;
      _startServices(familyId: familyId, uid: uid);
    }

    // Notification firing: watch the alerts stream and show a system
    // notification for any alert id we haven't seen before. On the first
    // emission after a cold start we only prime the baseline so stale
    // alerts don't all pop at once.
    ref.listen(alertsProvider, (prev, next) {
      final alerts = next.valueOrNull;
      if (alerts == null) return;

      if (_seenAlertIds == null) {
        _seenAlertIds = alerts.map((a) => a.id).toSet();
        return;
      }

      final members =
          ref.read(familyMembersProvider).valueOrNull ?? const [];
      final byId = {for (final m in members) m.id: m};
      final notifier = ref.read(notificationServiceProvider);

      for (final a in alerts) {
        if (_seenAlertIds!.contains(a.id)) continue;
        _seenAlertIds!.add(a.id);
        if (a.resolved) continue;
        notifier.showAlert(a, byId[a.memberId]);
      }
    });

    final unresolved = ref.watch(unresolvedAlertsProvider);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          FamilyDashboardScreen(),
          MapScreen(),
          ZonesListScreen(),
          AlertsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Family',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          const NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Zones',
          ),
          NavigationDestination(
            icon: Badge(
              label: unresolved.isEmpty ? null : Text('${unresolved.length}'),
              isLabelVisible: unresolved.isNotEmpty,
              child: const Icon(Icons.notifications_none),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }

  Future<void> _startServices({
    required String familyId,
    required String uid,
  }) async {
    final location = ref.read(locationServiceProvider);
    await location.start(familyId: familyId, uid: uid);

    final watcher = ref.read(geofenceWatcherProvider);
    await watcher.start(
      familyId: familyId,
      uid: uid,
      zonesStream:
          ref.read(zoneRepositoryProvider).watchZones(familyId),
      positions: location.positions,
    );

    final watchdog = ref.read(watchdogServiceProvider);
    await watchdog.start(familyId: familyId, uid: uid);

    // Register FCM token on member doc — unused in Phase 4 (we rely on
    // local notifications) but future Cloud Functions can push to killed
    // apps without a schema change.
    await ref
        .read(fcmServiceProvider)
        .registerFor(familyId: familyId, uid: uid);
  }
}
