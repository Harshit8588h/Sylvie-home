import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/presence_repository.dart';
import '../services/location_service.dart';
import 'firestore_provider.dart';

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  return PresenceRepository(ref.watch(firestoreProvider));
});

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService(ref.watch(presenceRepositoryProvider));
  ref.onDispose(service.stop);
  return service;
});

/// Rolled-up permission state used by the permissions gate.
enum LocationPermissionLevel {
  /// User denied, or we haven't asked yet.
  denied,

  /// Permission granted but only while using the app.
  whileInUse,

  /// Permission granted all the time (background OK).
  always,

  /// Denied permanently; user has to open Settings to re-grant.
  deniedForever,
}

class LocationPermissionController extends StateNotifier<LocationPermissionLevel> {
  LocationPermissionController() : super(LocationPermissionLevel.denied) {
    refresh();
  }

  Future<void> refresh() async {
    final geo = await Geolocator.checkPermission();
    state = _mapGeo(geo);
  }

  /// Ask the OS. First call usually only grants "while in use"; a second
  /// call is needed to unlock "always" on Android 10+.
  Future<void> request() async {
    var geo = await Geolocator.requestPermission();
    if (geo == LocationPermission.whileInUse ||
        geo == LocationPermission.always) {
      // Second ask for background. The OS treats this as a separate prompt
      // on Android 10+; permission_handler surfaces it cleanly.
      await Permission.locationAlways.request();
      geo = await Geolocator.checkPermission();
    }
    state = _mapGeo(geo);
  }

  LocationPermissionLevel _mapGeo(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
        return LocationPermissionLevel.always;
      case LocationPermission.whileInUse:
        return LocationPermissionLevel.whileInUse;
      case LocationPermission.deniedForever:
        return LocationPermissionLevel.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionLevel.denied;
    }
  }
}

final locationPermissionProvider =
    StateNotifierProvider<LocationPermissionController, LocationPermissionLevel>(
  (ref) => LocationPermissionController(),
);
