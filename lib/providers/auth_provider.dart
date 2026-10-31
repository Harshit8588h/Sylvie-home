import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

/// Live stream of the signed-in Firebase user, or null when signed out.
///
/// Reverted to the original simple shape — the complex waiting logic
/// previously added here was fighting Firebase's internal subscription
/// lifecycle and not actually resolving the cold-start flash. The real
/// wait now lives in main() where it can block UI mount until the SDK
/// has had a chance to restore the cached user, so by the time this
/// provider is first observed the stream's first emission is usually
/// the restored user, not a transient null.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Convenience: the current UID, or null.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});
