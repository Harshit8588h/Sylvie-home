import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../data/alert_repository.dart';
import '../data/presence_repository.dart';
import '../models/alert.dart';

/// Periodically checks for two cross-cutting conditions:
///   1. A family member's presence doc hasn't updated in >15 min
///      → their phone is probably offline / app killed / out of coverage
///   2. The local device's battery dropped below 20%
///      → warn family once per crossing
///
/// Alerts are fired at most once per event with simple in-memory
/// hysteresis so we don't spam the alerts collection every tick.
class WatchdogService {
  final AlertRepository _alerts;
  final PresenceRepository _presence;
  final FirebaseFirestore _db;
  final Battery _battery;

  final Set<String> _alertedOffline = <String>{};
  bool _alertedLowBattery = false;

  Timer? _timer;

  WatchdogService(this._alerts, this._presence, this._db, {Battery? battery})
      : _battery = battery ?? Battery();

  Future<void> start({required String familyId, required String uid}) async {
    await stop();
    _timer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _tick(familyId: familyId, uid: uid),
    );
    // Also run once immediately so the first alert fires fast.
    unawaited(_tick(familyId: familyId, uid: uid));
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _alertedOffline.clear();
    _alertedLowBattery = false;
  }

  Future<void> _tick({
    required String familyId,
    required String uid,
  }) async {
    await _checkBattery(familyId: familyId, uid: uid);
    await _checkOffline(familyId: familyId, uid: uid);
  }

  Future<void> _checkBattery({
    required String familyId,
    required String uid,
  }) async {
    try {
      final level = await _battery.batteryLevel;
      if (level < SylvieConstants.lowBatteryThreshold && !_alertedLowBattery) {
        _alertedLowBattery = true;
        await _alerts.createAlert(
          familyId: familyId,
          alert: _mkAlert(uid: uid, type: AlertType.batteryLow),
        );
      } else if (level > SylvieConstants.lowBatteryThreshold + 5) {
        // Hysteresis: only re-arm once we're comfortably above the threshold.
        _alertedLowBattery = false;
      }
    } catch (_) {
      // Battery plugin can fail on some OEMs — ignore and try next tick.
    }
  }

  Future<void> _checkOffline({
    required String familyId,
    required String uid,
  }) async {
    try {
      final snap = await _db
          .collection('families')
          .doc(familyId)
          .collection('presence')
          .get();

      final now = DateTime.now().toUtc();
      final threshold = SylvieConstants.phoneOfflineThreshold;

      for (final d in snap.docs) {
        if (d.id == uid) continue; // don't alert about yourself

        try {
          final ts = DateTime.parse(d.data()['timestamp'] as String);
          final age = now.difference(ts);
          final isOffline = age > threshold;

          if (isOffline && !_alertedOffline.contains(d.id)) {
            _alertedOffline.add(d.id);
            await _alerts.createAlert(
              familyId: familyId,
              alert: _mkAlert(uid: d.id, type: AlertType.phoneOffline),
            );
          } else if (!isOffline) {
            _alertedOffline.remove(d.id);
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      // Firestore blip — try next tick.
    }
  }

  FamilyAlert _mkAlert({required String uid, required AlertType type}) {
    final id = _db
        .collection('families')
        .doc('any')
        .collection('alerts')
        .doc()
        .id;
    return FamilyAlert(
      id: id,
      memberId: uid,
      type: type,
      timestamp: DateTime.now().toUtc(),
    );
  }
}
