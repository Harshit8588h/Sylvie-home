import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/alert_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/service_providers.dart';
import '../alerts/alerts_screen.dart';
import '../map/map_screen.dart';
import '../zones/zones_list_screen.dart';
import 'family_dashboard_screen.dart';

/// Family / Map / Zones / Alerts tabs. Also the single place where every
/// background service gets started once we have:
///   - a signed-in user with a uid
///   - at least one group id in /user_memberships/{uid}
///   - any location permission
///
/// Services now take the full group-id stream so a user who belongs to
/// multiple groups is tracked and watched across all of them.
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
    final groupIds = ref.watch(userGroupIdsProvider).valueOrNull ?? const [];
    final perm = ref.watch(locationPermissionProvider);

    final hasPerm = perm == LocationPermissionLevel.whileInUse ||
        perm == LocationPermissionLevel.always;

    if (!_servicesStarted &&
        uid != null &&
        groupIds.isNotEmpty &&
        hasPerm) {
      _servicesStarted = true;
      _startServices(uid: uid);
    }

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

  Future<void> _startServices({required String uid}) async {
    // Snapshot the current group ids NOW — Riverpod's provider.stream
    // only emits future updates, so services need the initial value
    // handed in explicitly or they stay stuck on an empty list until
    // the next membership edit.
    final currentIds =
        ref.read(userGroupIdsProvider).valueOrNull ?? const <String>[];
    final groupsStream = ref.read(userGroupIdsProvider.stream);

    final location = ref.read(locationServiceProvider);
    await location.start(
      initialGroupIds: currentIds,
      groupIdsStream: groupsStream,
      uid: uid,
    );

    final watcher = ref.read(geofenceWatcherProvider);
    await watcher.start(
      uid: uid,
      initialGroupIds: currentIds,
      groupIdsStream: groupsStream,
      positions: location.positions,
    );

    final watchdog = ref.read(watchdogServiceProvider);
    await watchdog.start(
      initialGroupIds: currentIds,
      groupIdsStream: groupsStream,
      uid: uid,
    );

    await ref
        .read(fcmServiceProvider)
        .registerFor(familyIds: currentIds, uid: uid);
  }
}
