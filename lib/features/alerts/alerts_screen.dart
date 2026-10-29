import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/alert.dart';
import '../../models/family_member.dart';
import '../../providers/alert_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider).valueOrNull ?? const [];
    final members = ref.watch(familyMembersProvider).valueOrNull ?? const [];
    final uid = ref.watch(currentUidProvider);

    final membersById = {for (final m in members) m.id: m};

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: alerts.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _AlertCard(
                alert: alerts[i],
                member: membersById[alerts[i].memberId],
                currentUid: uid,
                onAcknowledge: () async {
                  final familyId =
                      ref.read(currentFamilyIdProvider).valueOrNull;
                  if (familyId == null || uid == null) return;
                  await ref.read(alertRepositoryProvider).acknowledge(
                        familyId: familyId,
                        alertId: alerts[i].id,
                        uid: uid,
                      );
                },
                onResolve: () async {
                  final familyId =
                      ref.read(currentFamilyIdProvider).valueOrNull;
                  if (familyId == null) return;
                  await ref.read(alertRepositoryProvider).resolve(
                        familyId: familyId,
                        alertId: alerts[i].id,
                      );
                },
              ),
            ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final FamilyAlert alert;
  final FamilyMember? member;
  final String? currentUid;
  final VoidCallback onAcknowledge;
  final VoidCallback onResolve;

  const _AlertCard({
    required this.alert,
    required this.member,
    required this.currentUid,
    required this.onAcknowledge,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final name = member?.name ?? 'Unknown';
    final acknowledged =
        currentUid != null && alert.acknowledgedBy.contains(currentUid);

    final (icon, color, title) = _typeInfo(context, alert.type, name);

    return Card(
      color: alert.resolved
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: alert.resolved
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                Text(
                  _fmtAge(alert.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (alert.zoneName != null) ...[
              const SizedBox(height: 4),
              Text('Zone: ${alert.zoneName}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (alert.location != null) ...[
              const SizedBox(height: 2),
              Text(
                'at ${alert.location!.lat.toStringAsFixed(5)}, '
                '${alert.location!.lng.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!alert.resolved && !acknowledged)
                  TextButton(
                    onPressed: onAcknowledge,
                    child: const Text('Acknowledge'),
                  ),
                if (!alert.resolved)
                  FilledButton.tonal(
                    onPressed: onResolve,
                    child: const Text('Resolve'),
                  ),
                if (alert.resolved)
                  const Chip(
                    label: Text('Resolved'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static (IconData, Color, String) _typeInfo(
    BuildContext context,
    AlertType t,
    String name,
  ) {
    switch (t) {
      case AlertType.zoneExit:
        return (
          Icons.directions_run,
          Colors.orange,
          '$name left a safe zone',
        );
      case AlertType.zoneEnter:
        return (
          Icons.home,
          Colors.green,
          '$name entered a safe zone',
        );
      case AlertType.batteryLow:
        return (
          Icons.battery_1_bar,
          Colors.orange,
          '$name ki battery <20%',
        );
      case AlertType.phoneOffline:
        return (
          Icons.phone_disabled,
          Colors.red,
          '$name ka phone offline hai',
        );
      case AlertType.sos:
        return (Icons.sos, Colors.red, 'SOS from $name');
    }
  }

  static String _fmtAge(DateTime ts) {
    final d = DateTime.now().toUtc().difference(ts);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return DateFormat('MMM d').format(ts.toLocal());
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('Abhi koi alert nahi',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Jab bhi koi family member safe zone cross karega, phone '
              'offline hoga ya battery low ho jaayegi — yahaan dikhega.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
