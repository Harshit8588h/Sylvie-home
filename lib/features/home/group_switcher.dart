import 'package:flutter/material.dart';
// hide riverpod's internal Family type so our model wins unambiguously.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../models/family.dart';
import '../../providers/family_provider.dart';
import '../../providers/preferences_provider.dart';
import '../onboarding/create_family_screen.dart';
import '../onboarding/join_family_screen.dart';

/// Bottom sheet that lists every group the user belongs to, with a radio
/// select for the active one, plus actions to create or join another.
Future<void> showGroupSwitcher(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _GroupSwitcherSheet(),
  );
}

class _GroupSwitcherSheet extends ConsumerWidget {
  const _GroupSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(userGroupsListProvider).valueOrNull ?? const [];
    final active = ref.watch(activeGroupIdProvider);
    final controller = ref.read(activeGroupPrefProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Your groups',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...groups.map((g) => _GroupTile(
                group: g,
                isActive: g.id == active,
                onTap: () {
                  controller.set(g.id);
                  Navigator.of(context).pop();
                },
              )),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.add_home_outlined),
            title: const Text('Create new group'),
            subtitle: const Text('Admin ban + invite code generate'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateFamilyScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.group_add_outlined),
            title: const Text('Join another group'),
            subtitle: const Text('Invite code daalkar'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JoinFamilyScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final Family group;
  final bool isActive;
  final VoidCallback onTap;
  const _GroupTile({
    required this.group,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.groups,
          color: isActive
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      title: Text(group.name),
      trailing: isActive
          ? Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
