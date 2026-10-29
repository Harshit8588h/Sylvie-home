import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Registers this device's FCM token on the user's member doc in every
/// group they belong to, so a future Cloud Function pushing an alert in
/// any one of those groups can reach this device.
class FcmService {
  final FirebaseFirestore _db;
  FcmService(this._db);

  Future<void> registerFor({
    required List<String> familyIds,
    required String uid,
  }) async {
    if (familyIds.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token == null) return;

      for (final gid in familyIds) {
        await _writeToken(familyId: gid, uid: uid, token: token);
      }

      messaging.onTokenRefresh.listen((t) async {
        for (final gid in familyIds) {
          await _writeToken(familyId: gid, uid: uid, token: t);
        }
      });
    } catch (_) {
      // Best-effort — local notifications still work without FCM.
    }
  }

  Future<void> _writeToken({
    required String familyId,
    required String uid,
    required String token,
  }) async {
    try {
      await _db
          .collection('families')
          .doc(familyId)
          .collection('members')
          .doc(uid)
          .update({'fcm_token': token});
    } catch (_) {
      // Non-fatal.
    }
  }
}
