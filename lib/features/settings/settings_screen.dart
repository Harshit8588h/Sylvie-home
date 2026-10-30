import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// hide riverpod's internal Family type so our model wins unambiguously.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../models/family.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/firestore_provider.dart';
import '../../providers/preferences_provider.dart';
import '../onboarding/battery_setup_screen.dart';
import '../onboarding/create_family_screen.dart';
import '../onboarding/join_family_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final activeGroupId = ref.watch(activeGroupIdProvider);
    final members = ref.watch(familyMembersProvider).valueOrNull ?? const [];
    final groups = ref.watch(userGroupsListProvider).valueOrNull ?? const [];
    final activeGroup = groups
        .where((g) => g.id == activeGroupId)
        .cast<Family?>()
        .firstOrNull;

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
            onChanged: (uid == null || activeGroupId == null)
                ? null
                : (v) =>
                    _toggleSharing(ref, activeGroupId, uid, v),
          ),
          const Divider(),
          const _SectionHeader('Groups'),
          ListTile(
            leading: const Icon(Icons.add_home_outlined),
            title: const Text('Create new group'),
            subtitle: const Text('Alag circle banao — jaise college friends'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateFamilyScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.group_add_outlined),
            title: const Text('Join another group'),
            subtitle: const Text('Invite code daalkar'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const JoinFamilyScreen()),
            ),
          ),
          if (activeGroup != null)
            ListTile(
              leading: Icon(
                Icons.exit_to_app,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Leave "${activeGroup.name}"',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text(
                'Group ke members tujhe map pe nahi dekhenge aur tera data remove ho jaayega',
              ),
              onTap: () => _confirmLeave(context, ref, activeGroup, uid),
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

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    Family group,
    String? uid,
  ) async {
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Leave "${group.name}"?'),
        content: const Text(
          'Tera naam, location aur presence sab is group se nikal jaayenge. '
          'Dubara join karne ke liye invite code chahiye hoga.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(familyRepositoryProvider).leaveGroup(
          familyId: group.id,
          uid: uid,
        );
    // If this was the active group, clear the persisted choice so the
    // next active falls back to another membership (or returns to the
    // Create-or-Join screen if none remain).
    await ref.read(activeGroupPrefProvider.notifier).set(null);
    if (context.mounted) Navigator.of(context).pop();
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
    // Clear the "was signed in" flag so the next cold start goes
    // straight to the sign-in screen without a 10-second patient wait.
    await ref.read(hasSignedInBeforeProvider.notifier).set(false);
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
