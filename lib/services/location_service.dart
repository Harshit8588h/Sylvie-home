import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../core/constants.dart';
import '../data/presence_repository.dart';
import '../models/family_member.dart';

/// Streams location updates from the device and pushes them to Firestore.
/// Runs as long as [start] is called with a valid familyId + uid.
///
/// For v0.1 the service runs while the app is in the foreground (bound to
/// the Flutter UI lifecycle). Phase 2 will swap this out for a true
/// Android foreground service so we keep tracking when the UI is gone.
class LocationService {
  final PresenceRepository _presence;
  final Battery _battery;

  StreamSubscription<Position>? _posSub;
  Timer? _heartbeat;
  Position? _lastPushed;

  LocationService(this._presence, {Battery? battery})
      : _battery = battery ?? Battery();

  /// Call once permissions are known-granted. Idempotent — calling again
  /// resets the subscriptions.
  Future<void> start({required String familyId, required String uid}) async {
    await stop();

    // Movement-triggered updates: fire whenever the device moves >= 50 m.
    _posSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: SylvieConstants.locationUpdateDistanceMeters.toInt(),
      ),
    ).listen((pos) => _push(familyId: familyId, uid: uid, pos: pos));

    // Heartbeat so family still see a fresh "last seen" even when nobody
    // is moving. Every 10 minutes we re-push whatever we have.
    _heartbeat = Timer.periodic(const Duration(minutes: 10), (_) async {
      final pos = _lastPushed ?? await _tryCurrent();
      if (pos != null) await _push(familyId: familyId, uid: uid, pos: pos);
    });

    // Prime an immediate push on start.
    final first = await _tryCurrent();
    if (first != null) await _push(familyId: familyId, uid: uid, pos: first);
  }

  Future<void> stop() async {
    await _posSub?.cancel();
    _heartbeat?.cancel();
    _posSub = null;
    _heartbeat = null;
    _lastPushed = null;
  }

  Future<Position?> _tryCurrent() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _push({
    required String familyId,
    required String uid,
    required Position pos,
  }) async {
    int battery;
    try {
      battery = await _battery.batteryLevel;
    } catch (_) {
      battery = -1;
    }

    final isMoving = pos.speed > 0.5; // m/s — ~1.8 km/h, walking threshold
    final location = LastLocation(
      position: LatLng(pos.latitude, pos.longitude),
      accuracyMeters: pos.accuracy,
      timestamp: DateTime.now().toUtc(),
      batteryPercent: battery,
      isMoving: isMoving,
    );

    try {
      await _presence.updatePresence(
        familyId: familyId,
        uid: uid,
        location: location,
      );
      _lastPushed = pos;
    } catch (_) {
      // Network blip — the next tick will retry.
    }
  }
}
