import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    // Wait briefly for FirebaseAuth to restore the cached user before we
    // mount the UI. Without this, authStateChanges() can emit null
    // before the SDK has finished reading its on-disk cache, which
    // flashes the sign-in screen for a few hundred ms on every cold
    // start — reported in the field as "login maangta hai every time".
    try {
      await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Proceed anyway — the stream will emit when ready.
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
