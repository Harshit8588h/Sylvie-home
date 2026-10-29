import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/geofence_watcher.dart';
import '../services/notification_service.dart';
import '../services/watchdog_service.dart';
import 'alert_provider.dart';
import 'firestore_provider.dart';
import 'location_provider.dart';

/// Singleton services wired to Firestore + Alert repository. The notifier
/// below (ServiceStarter) is the one place every background component
/// gets kicked off once we know the user has a family and permission.

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final s = NotificationService();
  // init() is called from main() — here we just hand out the instance.
  return s;
});

final geofenceWatcherProvider = Provider<GeofenceWatcher>((ref) {
  final w = GeofenceWatcher(ref.watch(firestoreProvider));
  ref.onDispose(w.stop);
  return w;
});

final watchdogServiceProvider = Provider<WatchdogService>((ref) {
  final w = WatchdogService(
    ref.watch(alertRepositoryProvider),
    ref.watch(presenceRepositoryProvider),
    ref.watch(firestoreProvider),
  );
  ref.onDispose(w.stop);
  return w;
});
