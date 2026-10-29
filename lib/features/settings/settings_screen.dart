import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/firestore_provider.dart';
import '../../providers/preferences_provider.dart';
import '../onboarding/battery_setup_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final familyId = ref.watch(currentFamilyIdProvider).valueOrNull;
    final members = ref.watch(familyMembersProvider).valueOrNull ?? const [];

    final me = members.where((m) => m.id == uid).firstOrNull;
    final isSharing = me?.isSharingLocation ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Location sharing'),
          SwitchListTile(
            title: const Text('Share my location with family'),
            subtitle: Text(isSharing
                ? 'Family map pe tu dikh raha hai'
                : 'Tu invisible hai — koi tujhe map pe nahi dekh paa raha'),
            value: isSharing,
            onChanged: (uid == null || familyId == null)
                ? null
                : (v) => _toggleSharing(ref, familyId, uid, v),
          ),
          const Divider(),
          const _SectionHeader('Phone setup'),
          ListTile(
            leading: const Icon(Icons.battery_charging_full),
            title: const Text('Battery optimisation guide'),
            subtitle:
                const Text('Phone-specific steps to keep Sylvie running'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BatterySetupScreen(
                  onDone: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          const Divider(),
          const _SectionHeader('Account'),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Sign out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSharing(
    WidgetRef ref,
    String familyId,
    String uid,
    bool value,
  ) async {
    try {
      await ref
          .read(firestoreProvider)
          .collection('families')
          .doc(familyId)
          .collection('members')
          .doc(uid)
          .update({'is_sharing_location': value});
    } on FirebaseException {
      // No throw to UI — toggle will snap back on next member stream tick.
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Phone pe se app sign-out ho jaayega. Dubara sign-in karne ke '
          'liye phone number + OTP chahiye hoga.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(firebaseAuthProvider).signOut();
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
