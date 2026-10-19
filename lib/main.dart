import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth_gate.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

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
