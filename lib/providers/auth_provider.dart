import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

/// Live stream of the signed-in Firebase user, or null when signed out.
///
/// On cold start FirebaseAuth.authStateChanges() can emit `null` before
/// the SDK has finished reading its on-disk cache, which flashed the
/// sign-in screen every time the app was reopened from recents. We
/// poll `currentUser` for up to 2 seconds first and only then let the
/// first value escape — so AuthGate stays on its spinner until auth is
/// actually resolved. The subsequent `yield* authStateChanges()` is
/// what keeps the stream live for sign-ins/sign-outs after that.
final authStateProvider = StreamProvider<User?>((ref) async* {
  final auth = ref.watch(firebaseAuthProvider);

  if (auth.currentUser == null) {
    for (var i = 0; i < 20; i++) {
      if (auth.currentUser != null) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  yield auth.currentUser;
  yield* auth.authStateChanges();
});

/// Convenience: the current UID, or null.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});
