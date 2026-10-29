import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../core/constants.dart';
import '../data/presence_repository.dart';
import '../models/family_member.dart';

/// Streams location updates from the device and pushes them to every group
/// the user currently belongs to. Each push writes
/// /families/{groupId}/presence/{uid} — same shape per group — so a user
/// visible across multiple circles has a fresh presence doc in each one.
///
/// Exposes [positions] so peers (GeofenceWatcher) can subscribe to the
/// same stream instead of opening a second geolocator subscription.
class LocationService {
  final PresenceRepository _presence;
  final Battery _battery;

  final StreamController<Position> _positions =
      StreamController<Position>.broadcast();

  StreamSubscription<Position>? _posSub;
  StreamSubscription<List<String>>? _groupsSub;
  Timer? _heartbeat;
  Position? _lastPushed;

  /// Snapshot of groups to write presence into. Rewritten when the
  /// upstream groupIds stream emits.
  List<String> _currentGroups = const [];
  String _uid = '';

  LocationService(this._presence, {Battery? battery})
      : _battery = battery ?? Battery();

  Stream<Position> get positions => _positions.stream;

  /// Start writing presence for every group id in [initialGroupIds] plus
  /// every update [groupIdsStream] emits. Seeding with the initial value
  /// matters because Riverpod's provider.stream only delivers FUTURE
  /// changes — without seeding the service would silently write to zero
  /// groups until the next membership edit, which is why new joiners
  /// weren't appearing on each other's maps.
  Future<void> start({
    required List<String> initialGroupIds,
    required Stream<List<String>> groupIdsStream,
    required String uid,
  }) async {
    await stop();
    _uid = uid;
    _currentGroups = initialGroupIds;

    _groupsSub = groupIdsStream.listen((ids) {
      _currentGroups = ids;
      final pos = _lastPushed;
      if (pos != null) unawaited(_push(pos));
    });

    _posSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: SylvieConstants.locationUpdateDistanceMeters.toInt(),
      ),
    ).listen((pos) {
      _positions.add(pos);
      unawaited(_push(pos));
    });

    _heartbeat = Timer.periodic(const Duration(minutes: 10), (_) async {
      final pos = _lastPushed ?? await _tryCurrent();
      if (pos != null) await _push(pos);
    });

    final first = await _tryCurrent();
    if (first != null) {
      _positions.add(first);
      await _push(first);
    }
  }

  Future<void> stop() async {
    await _posSub?.cancel();
    await _groupsSub?.cancel();
    _heartbeat?.cancel();
    _posSub = null;
    _groupsSub = null;
    _heartbeat = null;
    _lastPushed = null;
    _currentGroups = const [];
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

  Future<void> _push(Position pos) async {
    if (_currentGroups.isEmpty) return;
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

    for (final gid in _currentGroups) {
      try {
        await _presence.updatePresence(
          familyId: gid,
          uid: _uid,
          location: location,
        );
      } catch (_) {
        // Per-group blip — the next tick will retry.
      }
    }
    _lastPushed = pos;
  }
}
