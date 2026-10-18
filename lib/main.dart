import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/theme.dart';

void main() {
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
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(SylvieConstants.appName)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Sylvie scaffold ready.\n\n'
            'Next: Firebase wiring, auth, family setup, map, geofencing.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
