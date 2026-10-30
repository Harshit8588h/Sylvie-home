import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

/// Live stream of the signed-in Firebase user, or null when signed out.
///
/// On cold start FirebaseAuth.authStateChanges() frequently emits `null`
/// synchronously BEFORE the SDK has finished reading its persisted
/// user from disk, which flashed the sign-in screen on every reopen.
/// We race the stream against a 3-second timeout waiting for the first
/// NON-null emission — if the cached user restores in that window the
/// gate sees it directly, otherwise we treat the account as signed-out
/// and proceed to the sign-in screen. The follow-up `yield*` keeps the
/// stream live for subsequent sign-ins / sign-outs.
final authStateProvider = StreamProvider<User?>((ref) async* {
  final auth = ref.watch(firebaseAuthProvider);

  // Fast path: cached user already in memory.
  if (auth.currentUser != null) {
    yield auth.currentUser;
    yield* auth.authStateChanges();
    return;
  }

  User? restored;
  try {
    restored = await auth
        .authStateChanges()
        .firstWhere((u) => u != null)
        .timeout(const Duration(seconds: 3));
  } on TimeoutException {
    restored = null; // genuinely signed out
  }

  yield restored;
  yield* auth.authStateChanges();
});

/// Convenience: the current UID, or null.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});
