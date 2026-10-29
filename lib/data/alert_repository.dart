import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/alert.dart';

class AlertRepository {
  final FirebaseFirestore _db;
  AlertRepository(this._db);

  CollectionReference<Map<String, dynamic>> _col(String familyId) =>
      _db.collection('families').doc(familyId).collection('alerts');

  /// Live stream of alerts for the family, newest first.
  Stream<List<FamilyAlert>> watchAlerts(String familyId) {
    return _col(familyId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => FamilyAlert.fromJson({...d.data(), 'id': d.id}))
              .toList(),
        );
  }

  Future<void> createAlert({
    required String familyId,
    required FamilyAlert alert,
  }) async {
    await _col(familyId).doc(alert.id).set(alert.toJson());
  }

  /// Add [uid] to the acknowledged_by list on the given alert.
  Future<void> acknowledge({
    required String familyId,
    required String alertId,
    required String uid,
  }) async {
    await _col(familyId).doc(alertId).update({
      'acknowledged_by': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> resolve({
    required String familyId,
    required String alertId,
  }) async {
    await _col(familyId).doc(alertId).update({'resolved': true});
  }
}
