import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/alert.dart';
import '../models/family_member.dart' as mm;
import '../models/safe_zone.dart';

/// Foreground geofence watcher that spans every group the user belongs to.
///
/// Maintains an in-memory {(groupId, zoneId) → was-inside} map; a crossing
/// writes a FamilyAlert into the ORIGINATING group's /alerts collection so
/// isolation is preserved — a zone exit in your Family group never leaks
/// into your Friends group.
class GeofenceWatcher {
  final FirebaseFirestore _db;
  final Map<String, bool> _insideState = {};

  // One zone subscription per group (added as groups come in, removed when
  // the user leaves them).
  final Map<String, StreamSubscription<List<SafeZone>>> _zoneSubs = {};
  final Map<String, List<SafeZone>> _zonesByGroup = {};

  StreamSubscription<Position>? _posSub;
  StreamSubscription<List<String>>? _groupsSub;
  String _uid = '';

  GeofenceWatcher(this._db);

  Future<void> start({
    required String uid,
    required Stream<List<String>> groupIdsStream,
    required Stream<Position> positions,
  }) async {
    await stop();
    _uid = uid;

    _groupsSub = groupIdsStream.listen(_syncGroupSubscriptions);

    _posSub = positions.listen(_evaluate);
  }

  Future<void> stop() async {
    await _posSub?.cancel();
    await _groupsSub?.cancel();
    for (final s in _zoneSubs.values) {
      await s.cancel();
    }
    _posSub = null;
    _groupsSub = null;
    _zoneSubs.clear();
    _zonesByGroup.clear();
    _insideState.clear();
  }

  void _syncGroupSubscriptions(List<String> ids) {
    // Add subs for new groups.
    for (final id in ids) {
      if (_zoneSubs.containsKey(id)) continue;
      final stream = _db
          .collection('families')
          .doc(id)
          .collection('zones')
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => SafeZone.fromJson({...d.data(), 'id': d.id}))
              .toList());
      _zoneSubs[id] = stream.listen((zs) => _zonesByGroup[id] = zs);
    }
    // Drop subs for groups we no longer belong to.
    final toRemove = _zoneSubs.keys.where((id) => !ids.contains(id)).toList();
    for (final id in toRemove) {
      _zoneSubs.remove(id)?.cancel();
      _zonesByGroup.remove(id);
      // Clear state entries for that group.
      _insideState.removeWhere((key, _) => key.startsWith('$id|'));
    }
  }

  void _evaluate(Position pos) {
    for (final entry in _zonesByGroup.entries) {
      final groupId = entry.key;
      for (final z in entry.value) {
        if (!z.active) continue;
        if (!z.appliesToMember(_uid)) continue;

        final key = '$groupId|${z.id}';
        final inside = _isInside(pos, z);
        final wasInside = _insideState[key];

        if (wasInside == null) {
          _insideState[key] = inside;
          continue;
        }
        if (inside == wasInside) continue;
        _insideState[key] = inside;

        if (!inside && z.alertOnExit) {
          unawaited(_writeAlert(
            familyId: groupId,
            zone: z,
            pos: pos,
            type: AlertType.zoneExit,
          ));
        } else if (inside && z.alertOnEnter) {
          unawaited(_writeAlert(
            familyId: groupId,
            zone: z,
            pos: pos,
            type: AlertType.zoneEnter,
          ));
        }
      }
    }
  }

  bool _isInside(Position pos, SafeZone z) {
    final d = _haversineMeters(
      pos.latitude,
      pos.longitude,
      z.center.lat,
      z.center.lng,
    );
    return d <= z.radiusMeters;
  }

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double d) => d * math.pi / 180;

  Future<void> _writeAlert({
    required String familyId,
    required SafeZone zone,
    required Position pos,
    required AlertType type,
  }) async {
    final alertRef = _db
        .collection('families')
        .doc(familyId)
        .collection('alerts')
        .doc();
    final alert = FamilyAlert(
      id: alertRef.id,
      memberId: _uid,
      type: type,
      timestamp: DateTime.now().toUtc(),
      location: mm.LatLng(pos.latitude, pos.longitude),
      zoneId: zone.id,
      zoneName: zone.name,
    );
    try {
      await alertRef.set(alert.toJson());
    } catch (_) {
      // Blip — next transition will retry.
    }
  }
}
