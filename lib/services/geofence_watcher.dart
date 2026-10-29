import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/alert.dart';
import '../models/family_member.dart' as mm;
import '../models/safe_zone.dart';

/// Foreground geofence watcher. Keeps an in-memory map of
/// {zoneId → was-inside} and fires enter/exit alerts into Firestore when
/// the current member crosses a boundary.
///
/// This runs while the Flutter UI is alive; Phase 3 will add the OS-level
/// geofence API so transitions still get caught when the app is killed.
class GeofenceWatcher {
  final FirebaseFirestore _db;
  final Map<String, bool> _insideState = {};
  StreamSubscription<Position>? _sub;

  GeofenceWatcher(this._db);

  Future<void> start({
    required String familyId,
    required String uid,
    required Stream<List<SafeZone>> zonesStream,
    required Stream<Position> positions,
  }) async {
    await stop();

    // Keep the latest zone list in a mutable local so each position tick
    // sees fresh data without rebuilding subscriptions.
    List<SafeZone> currentZones = const [];
    final zoneSub = zonesStream.listen((zs) {
      currentZones = zs;
      // Drop state for zones that no longer exist.
      _insideState.removeWhere((id, _) => zs.every((z) => z.id != id));
    });

    _sub = positions.listen((pos) async {
      for (final z in currentZones) {
        if (!z.active) continue;
        if (!z.appliesToMember(uid)) continue;

        final inside = _isInside(pos, z);
        final wasInside = _insideState[z.id];

        if (wasInside == null) {
          // First observation — just prime the state, no alert.
          _insideState[z.id] = inside;
          continue;
        }

        if (inside == wasInside) continue;

        _insideState[z.id] = inside;

        if (!inside && z.alertOnExit) {
          await _writeAlert(
            familyId: familyId,
            memberId: uid,
            zone: z,
            pos: pos,
            type: AlertType.zoneExit,
          );
        } else if (inside && z.alertOnEnter) {
          await _writeAlert(
            familyId: familyId,
            memberId: uid,
            zone: z,
            pos: pos,
            type: AlertType.zoneEnter,
          );
        }
      }
    });

    // Keep the zone subscription alive as long as we are watching.
    _sub!.onDone(zoneSub.cancel);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _insideState.clear();
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
    const r = 6371000.0; // earth radius, meters
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
    required String memberId,
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
      memberId: memberId,
      type: type,
      timestamp: DateTime.now().toUtc(),
      location: mm.LatLng(pos.latitude, pos.longitude),
      zoneId: zone.id,
      zoneName: zone.name,
    );
    try {
      await alertRef.set(alert.toJson());
    } catch (_) {
      // Network blip — skip; the next transition will produce a fresh alert.
    }
  }
}
