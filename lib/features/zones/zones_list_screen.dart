import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/family_member.dart' as mm;
import '../../models/safe_zone.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/zone_provider.dart';
import 'create_zone_screen.dart';

class ZonesListScreen extends ConsumerWidget {
  const ZonesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final zones = ref.watch(zonesProvider).valueOrNull ?? const [];
    final members = ref.watch(familyMembersProvider).valueOrNull ?? const [];
    // Multi-admin: role lives on the member doc, not family.admin_id.
    final me = members.where((m) => m.id == uid).firstOrNull;
    final isAdmin = me?.role == mm.FamilyRole.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('Safe zones')),
      body: zones.isEmpty
          ? _EmptyState(isAdmin: isAdmin)
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: zones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _ZoneCard(
                zone: zones[i],
                members: members,
                canEdit: isAdmin,
                onDelete: () => _confirmDelete(context, ref, zones[i]),
              ),
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateZoneScreen()),
              ),
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Add zone'),
            )
          : null,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SafeZone zone,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('"${zone.name}" delete karein?'),
        content: const Text(
          'Yeh zone sab members ke liye hat jaayega. Alerts aur history bhi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final familyId = ref.read(currentFamilyIdProvider).valueOrNull;
    if (familyId == null) return;
    await ref
        .read(zoneRepositoryProvider)
        .deleteZone(familyId: familyId, zoneId: zone.id);
  }
}

class _ZoneCard extends StatelessWidget {
  final SafeZone zone;
  final List<mm.FamilyMember> members;
  final bool canEdit;
  final VoidCallback onDelete;

  const _ZoneCard({
    required this.zone,
    required this.members,
    required this.canEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final applies = zone.appliesTo.isEmpty
        ? 'Sabke liye'
        : members
            .where((m) => zone.appliesTo.contains(m.id))
            .map((m) => m.name)
            .join(', ');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.shield_outlined),
        ),
        title: Text(zone.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${zone.radiusMeters.toStringAsFixed(0)} m radius'),
            Text(applies, style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: canEdit
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isAdmin;
  const _EmptyState({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Abhi koi safe zone nahi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isAdmin
                  ? 'Pehla zone banane ke liye niche "+Add zone" daba. '
                      'Ghar ke around ek zone recommend hai — jab bhi koi '
                      'member us zone ke bahar jaayega, alert aayegi.'
                  : 'Admin se bolo pehla zone banane ko.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
