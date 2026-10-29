import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/safe_zone.dart';

class ZoneRepository {
  final FirebaseFirestore _db;
  ZoneRepository(this._db);

  CollectionReference<Map<String, dynamic>> _col(String familyId) =>
      _db.collection('families').doc(familyId).collection('zones');

  Stream<List<SafeZone>> watchZones(String familyId) {
    return _col(familyId).snapshots().map(
          (snap) => snap.docs
              .map((d) => SafeZone.fromJson({...d.data(), 'id': d.id}))
              .toList(),
        );
  }

  Future<String> addZone({
    required String familyId,
    required SafeZone zone,
  }) async {
    final ref = _col(familyId).doc();
    final toWrite = SafeZone(
      id: ref.id,
      name: zone.name,
      center: zone.center,
      radiusMeters: zone.radiusMeters,
      appliesTo: zone.appliesTo,
      alertOnExit: zone.alertOnExit,
      alertOnEnter: zone.alertOnEnter,
      active: zone.active,
      createdAt: zone.createdAt,
    );
    await ref.set(toWrite.toJson());
    return ref.id;
  }

  Future<void> updateZone({
    required String familyId,
    required SafeZone zone,
  }) async {
    await _col(familyId).doc(zone.id).set(zone.toJson());
  }

  Future<void> deleteZone({
    required String familyId,
    required String zoneId,
  }) async {
    await _col(familyId).doc(zoneId).delete();
  }
}
