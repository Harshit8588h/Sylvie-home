import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/phone_sign_in_screen.dart';
import '../firebase_options.dart';
import '../providers/auth_provider.dart';

/// Routes based on Firebase + auth state:
///   placeholder Firebase config → setup instructions
///   signed out               → PhoneSignInScreen
///   signed in                → placeholder home (family setup next commit)
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!DefaultFirebaseOptions.isConfigured) {
      return const _FirebaseNotConfiguredScreen();
    }

    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Auth error: $e'))),
      data: (user) {
        if (user == null) return const PhoneSignInScreen();
        return const _SignedInPlaceholder();
      },
    );
  }
}

class _FirebaseNotConfiguredScreen extends StatelessWidget {
  const _FirebaseNotConfiguredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase setup pending')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Firebase project configure karo:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              '1. docs/FIREBASE_SETUP.md follow karo\n'
              '2. `flutterfire configure --project=sylvie-family`\n'
              '3. `google-services.json` ko android/app/ me daalo\n'
              '4. flutter run',
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInPlaceholder extends ConsumerWidget {
  const _SignedInPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sylvie'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(firebaseAuthProvider).signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signed in as ${user?.phoneNumber ?? "?"}'),
            const SizedBox(height: 12),
            const Text('Next: family setup wizard, map, geofencing.'),
          ],
        ),
      ),
    );
  }
}
