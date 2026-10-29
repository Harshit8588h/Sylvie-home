import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Registers this device's FCM token on the user's member doc so future
/// Cloud Functions (or any Firebase Admin consumer) can push a
/// notification to it. Phase 3 uses local notifications only; this is
/// future-proofing for when the app is fully killed and we need the
/// server to wake the device.
class FcmService {
  final FirebaseFirestore _db;
  FcmService(this._db);

  Future<void> registerFor({
    required String familyId,
    required String uid,
  }) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // iOS/macOS require this; on Android 13+ it also triggers the
      // POST_NOTIFICATIONS permission prompt if not already granted.
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token == null) return;

      await _writeToken(familyId: familyId, uid: uid, token: token);

      // Keep the stored token fresh if FCM rotates it.
      messaging.onTokenRefresh.listen((t) {
        _writeToken(familyId: familyId, uid: uid, token: t);
      });
    } catch (_) {
      // FCM registration is best-effort; local notifications still work
      // without it. Swallow transient failures.
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
