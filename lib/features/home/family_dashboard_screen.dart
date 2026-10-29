import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';

class FamilyDashboardScreen extends ConsumerWidget {
  const FamilyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider).valueOrNull;
    final members = ref.watch(familyMembersProvider).valueOrNull ?? const [];
    final codes = ref.watch(familyInviteCodesProvider).valueOrNull ?? const [];
    final uid = ref.watch(currentUidProvider);
    final isAdmin = family != null && family.adminId == uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(family?.name ?? 'Sylvie'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(firebaseAuthProvider).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isAdmin && codes.isNotEmpty) _InviteCard(code: codes.first),
          const SizedBox(height: 16),
          Text(
            'Members (${members.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...members.map((m) => _MemberTile(member: m, isSelf: m.id == uid)),
          const SizedBox(height: 24),
          _NextStepsCard(),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final String code;
  const _InviteCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invite code',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      fontSize: 32,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copy ho gaya')),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Family members ko ye code bhej — WhatsApp pe share kar sakte ho.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final FamilyMember member;
  final bool isSelf;
  const _MemberTile({required this.member, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(member.name.characters.first.toUpperCase())),
        title: Text(member.name + (isSelf ? ' (you)' : '')),
        subtitle: Text('${_relationLabel(member.relation)}  ·  ${member.phoneNumber}'),
        trailing: member.role == FamilyRole.admin
            ? const Chip(label: Text('Admin'), visualDensity: VisualDensity.compact)
            : null,
      ),
    );
  }

  static String _relationLabel(Relation r) {
    switch (r) {
      case Relation.self:
        return 'Self';
      case Relation.mother:
        return 'Mummy';
      case Relation.father:
        return 'Papa';
      case Relation.sister:
        return 'Didi';
      case Relation.brother:
        return 'Bhai';
      case Relation.grandmother:
        return 'Dadi';
      case Relation.grandfather:
        return 'Dada';
      case Relation.other:
        return 'Other';
    }
  }
}

class _NextStepsCard extends StatelessWidget {
  const _NextStepsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Aage kya aane wala hai:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('• Live map — sab members ki location'),
            Text('• Safe zones (ghar + AIIMS)'),
            Text('• Zone exit alerts + phone-offline watchdog'),
            Text('• Per-OEM battery setup wizard'),
          ],
        ),
      ),
    );
  }
}
