import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/family_member.dart';

class PresenceRepository {
  final FirebaseFirestore _db;
  PresenceRepository(this._db);

  /// Write/overwrite the latest presence doc for a member. One doc per
  /// member, keyed by uid, under /families/{familyId}/presence/{uid}.
  Future<void> updatePresence({
    required String familyId,
    required String uid,
    required LastLocation location,
  }) async {
    await _db
        .collection('families')
        .doc(familyId)
        .collection('presence')
        .doc(uid)
        .set(location.toJson());
  }

  /// Live stream of every member's latest presence doc.
  Stream<Map<String, LastLocation>> watchAllPresence(String familyId) {
    return _db
        .collection('families')
        .doc(familyId)
        .collection('presence')
        .snapshots()
        .map((snap) {
      final out = <String, LastLocation>{};
      for (final d in snap.docs) {
        try {
          out[d.id] = LastLocation.fromJson(d.data());
        } catch (_) {
          // Ignore malformed presence docs instead of crashing the map.
        }
      }
      return out;
    });
  }
}
