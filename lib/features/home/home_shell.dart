import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/location_provider.dart';
import '../map/map_screen.dart';
import 'family_dashboard_screen.dart';

/// Wraps Dashboard + Map in bottom-nav scaffolding. Also kicks off the
/// location service once the user has a family + the right permission.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool _serviceStarted = false;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final familyId = ref.watch(currentFamilyIdProvider).valueOrNull;
    final perm = ref.watch(locationPermissionProvider);

    // Start location updates once we have a family + any location permission.
    // Phase 1 runs while the UI is alive; Phase 2 will promote to a true
    // Android foreground service.
    final hasPerm = perm == LocationPermissionLevel.whileInUse ||
        perm == LocationPermissionLevel.always;
    if (!_serviceStarted && uid != null && familyId != null && hasPerm) {
      _serviceStarted = true;
      // Fire-and-forget; service manages its own lifecycle.
      ref
          .read(locationServiceProvider)
          .start(familyId: familyId, uid: uid);
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          FamilyDashboardScreen(),
          MapScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Family',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
      ),
    );
  }
}
