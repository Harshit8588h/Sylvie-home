import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../data/alert_repository.dart';
import '../data/presence_repository.dart';
import '../models/alert.dart';

/// Periodically checks:
///   1. For each group the user is in, any OTHER member whose presence
///      doc is older than 15 min → phoneOffline alert in that group
///   2. Local device battery < 20 % → batteryLow alert in every group
///      (friends want to know, so does family)
///
/// In-memory hysteresis prevents spam: an alert fires once per
/// (group, memberId, condition) crossing and re-arms when the condition
/// clears.
class WatchdogService {
  final AlertRepository _alerts;
  final PresenceRepository _presence;
  final FirebaseFirestore _db;
  final Battery _battery;

  final Set<String> _alertedOffline = <String>{}; // "groupId|memberId"
  final Set<String> _alertedBattery = <String>{}; // "groupId"

  Timer? _timer;
  StreamSubscription<List<String>>? _groupsSub;
  List<String> _currentGroups = const [];
  String _uid = '';

  WatchdogService(this._alerts, this._presence, this._db, {Battery? battery})
      : _battery = battery ?? Battery();

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
      _alertedOffline.removeWhere((k) => !ids.contains(k.split('|').first));
      _alertedBattery.removeWhere((g) => !ids.contains(g));
    });

    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _tick());
    unawaited(_tick());
  }

  Future<void> stop() async {
    _timer?.cancel();
    await _groupsSub?.cancel();
    _timer = null;
    _groupsSub = null;
    _alertedOffline.clear();
    _alertedBattery.clear();
    _currentGroups = const [];
  }

  Future<void> _tick() async {
    if (_currentGroups.isEmpty) return;
    await _checkBattery();
    await _checkOffline();
  }

  Future<void> _checkBattery() async {
    int level;
    try {
      level = await _battery.batteryLevel;
    } catch (_) {
      return;
    }
    final lowNow = level < SylvieConstants.lowBatteryThreshold;
    final recoveredNow = level > SylvieConstants.lowBatteryThreshold + 5;

    for (final gid in _currentGroups) {
      if (lowNow && !_alertedBattery.contains(gid)) {
        _alertedBattery.add(gid);
        await _alerts.createAlert(
          familyId: gid,
          alert: _mkAlert(uid: _uid, type: AlertType.batteryLow),
        );
      } else if (recoveredNow) {
        _alertedBattery.remove(gid);
      }
    }
  }

  Future<void> _checkOffline() async {
    final now = DateTime.now().toUtc();
    final threshold = SylvieConstants.phoneOfflineThreshold;

    for (final gid in _currentGroups) {
      try {
        final snap = await _db
            .collection('families')
            .doc(gid)
            .collection('presence')
            .get();

        for (final d in snap.docs) {
          if (d.id == _uid) continue;
          try {
            final ts = DateTime.parse(d.data()['timestamp'] as String);
            final isOffline = now.difference(ts) > threshold;
            final key = '$gid|${d.id}';
            if (isOffline && !_alertedOffline.contains(key)) {
              _alertedOffline.add(key);
              await _alerts.createAlert(
                familyId: gid,
                alert: _mkAlert(uid: d.id, type: AlertType.phoneOffline),
              );
            } else if (!isOffline) {
              _alertedOffline.remove(key);
            }
          } catch (_) {
            continue;
          }
        }
      } catch (_) {
        // Firestore blip — next tick.
      }
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
