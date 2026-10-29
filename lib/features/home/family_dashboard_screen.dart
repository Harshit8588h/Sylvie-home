import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/presence_provider.dart';
import '../settings/settings_screen.dart';
import 'group_switcher.dart';

class FamilyDashboardScreen extends ConsumerWidget {
  const FamilyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider).valueOrNull;
    final members = ref.watch(familyMembersProvider).valueOrNull ?? const [];
    final codes = ref.watch(familyInviteCodesProvider).valueOrNull ?? const [];
    final presence = ref.watch(familyPresenceProvider).valueOrNull ?? const {};
    final uid = ref.watch(currentUidProvider);
    final me = members.where((m) => m.id == uid).firstOrNull;
    final iAmAdmin = me?.role == FamilyRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => showGroupSwitcher(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    family?.name ?? 'Sylvie',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (iAmAdmin && codes.isNotEmpty) _InviteCard(code: codes.first),
          const SizedBox(height: 16),
          Text(
            'Members (${members.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...members.map(
            (m) => _MemberTile(
              member: m,
              isSelf: m.id == uid,
              presence: presence[m.id],
              iAmAdmin: iAmAdmin,
            ),
          ),
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
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share',
                  onPressed: () async {
                    final text =
                        'Sylvie group mein join ho: invite code $code';
                    final uri =
                        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Yeh code sirf is group ke liye hai. Jisko bulao WhatsApp pe bhej do.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  final FamilyMember member;
  final bool isSelf;
  final LastLocation? presence;
  final bool iAmAdmin;
  const _MemberTile({
    required this.member,
    required this.isSelf,
    required this.presence,
    required this.iAmAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(member.name.characters.first.toUpperCase()),
        ),
        title: Row(
          children: [
            Expanded(child: Text(member.name + (isSelf ? ' (you)' : ''))),
            if (member.role == FamilyRole.admin)
              const Chip(
                label: Text('Admin'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_relationLabel(member.relation)}  ·  ${member.phoneNumber}'),
            if (presence != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _PresenceLine(location: presence!),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('No location yet',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            if (!isSelf)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  children: [
                    _ActionIconButton(
                      icon: Icons.call,
                      label: 'Call',
                      onTap: () => _launch('tel:${member.phoneNumber}'),
                    ),
                    _ActionIconButton(
                      icon: Icons.chat_bubble_outline,
                      label: 'WhatsApp',
                      onTap: () => _launch(
                        'https://wa.me/${member.phoneNumber.replaceAll('+', '')}',
                      ),
                    ),
                    if (iAmAdmin)
                      _ActionIconButton(
                        icon: Icons.more_horiz,
                        label: 'Admin',
                        onTap: () => _showAdminActions(context, ref),
                      ),
                  ],
                ),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showAdminActions(BuildContext context, WidgetRef ref) async {
    final familyId = ref.read(activeGroupIdProvider);
    if (familyId == null) return;
    final isAdmin = member.role == FamilyRole.admin;

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isAdmin ? Icons.remove_moderator : Icons.admin_panel_settings,
              ),
              title: Text(isAdmin ? 'Admin se hatao' : 'Admin banao'),
              onTap: () => Navigator.of(context).pop('toggle_admin'),
            ),
            ListTile(
              leading: Icon(
                Icons.person_remove,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Group se remove karo',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop('remove'),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
    if (choice == null) return;

    final repo = ref.read(familyRepositoryProvider);
    switch (choice) {
      case 'toggle_admin':
        await repo.setMemberRole(
          familyId: familyId,
          memberId: member.id,
          asAdmin: !isAdmin,
        );
      case 'remove':
        if (context.mounted) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('${member.name} ko remove karo?'),
              content: Text(
                'Yeh user is group se nikal jaayega. Unki location is '
                'group pe nahi dikhegi aur alerts band ho jaayenge. '
                'Dusre groups se nahi hatega.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
          if (ok == true) {
            await repo.removeMember(familyId: familyId, memberId: member.id);
          }
        }
    }
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

class _PresenceLine extends StatelessWidget {
  final LastLocation location;
  const _PresenceLine({required this.location});

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().toUtc().difference(location.timestamp);
    final ageStr = _fmtAge(age);
    final bat = location.batteryPercent;
    final isStale = age > const Duration(minutes: 15);
    final isLowBattery = bat >= 0 && bat < 20;

    final chips = <Widget>[
      _SmallChip(
        label: ageStr,
        color:
            isStale ? Colors.red : Theme.of(context).colorScheme.outlineVariant,
      ),
      if (bat >= 0)
        _SmallChip(
          label: '$bat%',
          icon: Icons.battery_std,
          color: isLowBattery
              ? Colors.red
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      if (location.isMoving)
        const _SmallChip(label: 'moving', icon: Icons.directions_walk),
    ];

    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }

  static String _fmtAge(Duration d) {
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  const _SmallChip({required this.label, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.outlineVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: c),
            const SizedBox(width: 2),
          ],
          Text(label, style: TextStyle(fontSize: 10, color: c)),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                )),
          ],
        ),
      ),
    );
  }
}
