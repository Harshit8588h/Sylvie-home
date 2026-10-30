import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

/// Live stream of the signed-in Firebase user, or null when signed out.
///
/// On aggressive-killer OEMs (Realme / Vivo / Xiaomi) FirebaseAuth can
/// take a surprising amount of time to read its on-disk cache after a
/// cold start — long enough that `authStateChanges()` emits `null`
/// first and the gate flashes the sign-in screen before the real user
/// finally arrives. We work around it by remembering, in a plain
/// SharedPreferences flag, whether the LAST session ended with a user
/// signed in. If yes, we wait patiently (up to 10 s) for a non-null
/// emission before giving up and showing sign-in; if no, we only wait
/// a brief 2 s so first-time users don't stare at a spinner.
///
/// Set the flag true on successful OTP verify, false on explicit sign-out.
final authStateProvider = StreamProvider<User?>((ref) async* {
  final auth = ref.watch(firebaseAuthProvider);

  // Fast path: cached user is already warm in memory.
  if (auth.currentUser != null) {
    yield auth.currentUser;
    yield* auth.authStateChanges();
    return;
  }

  // Read the "last session was signed in" flag directly (not via
  // Riverpod) because the Riverpod notifier is itself async.
  bool expectedSignedIn = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    expectedSignedIn = prefs.getBool('has_signed_in_before') ?? false;
  } catch (_) {
    expectedSignedIn = false;
  }

  final waitBudget = expectedSignedIn
      ? const Duration(seconds: 10)
      : const Duration(seconds: 2);

  User? restored;
  try {
    restored = await auth
        .authStateChanges()
        .firstWhere((u) => u != null)
        .timeout(waitBudget);
  } on TimeoutException {
    restored = null;
  }

  yield restored;
  yield* auth.authStateChanges();
});

/// Convenience: the current UID, or null.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});
