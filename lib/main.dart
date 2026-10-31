import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth_gate.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Only block if the LAST session ended with a signed-in user. First
    // launches / explicit sign-outs go straight to the sign-in screen
    // without a wait. Everyone else sits on the Flutter splash while
    // FirebaseAuth reads its cache from disk — up to 10 s on aggressive
    // OEMs — so the gate never sees a transient `null` emission and
    // never flashes PhoneSignInScreen on reopen from recents.
    bool wasSignedIn = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      wasSignedIn = prefs.getBool('has_signed_in_before') ?? false;
    } catch (_) {
      wasSignedIn = false;
    }

    if (wasSignedIn && FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        // Give up and let the sign-in screen appear.
      }
    }
  }

  await NotificationService().init();

  runApp(const ProviderScope(child: SylvieApp()));
}

class SylvieApp extends StatelessWidget {
  const SylvieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: SylvieConstants.appName,
      theme: SylvieTheme.light(),
      darkTheme: SylvieTheme.dark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}
