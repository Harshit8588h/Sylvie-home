import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/phone_sign_in_screen.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/create_or_join_screen.dart';
import '../features/permissions/location_permissions_screen.dart';
import '../firebase_options.dart';
import '../providers/auth_provider.dart';
import '../providers/family_provider.dart';
import '../providers/location_provider.dart';

/// Top-level router. Decides which screen to show based on:
///   1. Is Firebase actually configured?
///   2. Is a user signed in?
///   3. Does the signed-in user have a family yet?
///   4. Have they granted location permission?
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!DefaultFirebaseOptions.isConfigured) {
      return const _FirebaseNotConfiguredScreen();
    }

    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const _CenterSpinner(),
      error: (e, _) => _CenterMessage('Auth error: $e'),
      data: (user) {
        if (user == null) return const PhoneSignInScreen();
        return const _MembershipGate();
      },
    );
  }
}

class _MembershipGate extends ConsumerWidget {
  const _MembershipGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyIdAsync = ref.watch(currentFamilyIdProvider);
    return familyIdAsync.when(
      loading: () => const _CenterSpinner(),
      error: (e, _) => _CenterMessage('Membership load error: $e'),
      data: (familyId) {
        if (familyId == null) return const CreateOrJoinScreen();
        return const _PermissionGate();
      },
    );
  }
}

class _PermissionGate extends ConsumerWidget {
  const _PermissionGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perm = ref.watch(locationPermissionProvider);
    // We accept "while in use" as good enough to show the home shell —
    // user can be nudged to upgrade to "always" later. Only denied/
    // deniedForever blocks entry.
    if (perm == LocationPermissionLevel.denied ||
        perm == LocationPermissionLevel.deniedForever) {
      return const LocationPermissionsScreen();
    }
    return const HomeShell();
  }
}

class _CenterSpinner extends StatelessWidget {
  const _CenterSpinner();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _CenterMessage extends StatelessWidget {
  final String message;
  const _CenterMessage(this.message);
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message),
          ),
        ),
      );
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
