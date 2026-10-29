import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../core/constants.dart';
import '../data/presence_repository.dart';
import '../models/family_member.dart';

/// Streams location updates from the device and pushes them to Firestore.
/// Runs as long as [start] is called with a valid familyId + uid.
///
/// Exposes [positions] so peers (GeofenceWatcher) can subscribe to the
/// same stream instead of opening a second geolocator subscription.
class LocationService {
  final PresenceRepository _presence;
  final Battery _battery;

  final StreamController<Position> _positions =
      StreamController<Position>.broadcast();

  StreamSubscription<Position>? _posSub;
  Timer? _heartbeat;
  Position? _lastPushed;

  LocationService(this._presence, {Battery? battery})
      : _battery = battery ?? Battery();

  /// Broadcast stream of raw position updates. Multiple consumers are fine.
  Stream<Position> get positions => _positions.stream;

  Future<void> start({required String familyId, required String uid}) async {
    await stop();

    _posSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: SylvieConstants.locationUpdateDistanceMeters.toInt(),
      ),
    ).listen((pos) {
      _positions.add(pos); // fan out to geofence watcher etc.
      _push(familyId: familyId, uid: uid, pos: pos);
    });

    _heartbeat = Timer.periodic(const Duration(minutes: 10), (_) async {
      final pos = _lastPushed ?? await _tryCurrent();
      if (pos != null) await _push(familyId: familyId, uid: uid, pos: pos);
    });

    final first = await _tryCurrent();
    if (first != null) {
      _positions.add(first);
      await _push(familyId: familyId, uid: uid, pos: first);
    }
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

    final isMoving = pos.speed > 0.5;
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
