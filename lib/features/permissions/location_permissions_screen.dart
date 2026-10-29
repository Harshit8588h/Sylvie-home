import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/location_provider.dart';

/// First-run location permissions. Walks the user through
/// "while in use" → "allow all the time", explaining why Sylvie
/// needs background location (zone exit alerts).
class LocationPermissionsScreen extends ConsumerWidget {
  const LocationPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(locationPermissionProvider);
    final notifier = ref.read(locationPermissionProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Location access')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Icon(
              Icons.location_on_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Sylvie ko location access chahiye',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Family map pe tujhe dikhne ke liye aur ghar ke safe zone se '
              'nikalne pe alert ke liye. Background mein bhi chahiye warna '
              'app band hone pe tracking ruk jaayegi.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _LevelStatus(level: level),
            const Spacer(),
            if (level == LocationPermissionLevel.deniedForever) ...[
              Text(
                'Permission "Don\'t ask again" ho chuka hai. Settings mein ja ke manually enable kar.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => AppSettings.openAppSettings(
                  type: AppSettingsType.location,
                ),
                child: const Text('Open Settings'),
              ),
            ] else ...[
              FilledButton(
                onPressed: notifier.request,
                child: Text(level == LocationPermissionLevel.whileInUse
                    ? '"Allow all the time" bhi grant kar'
                    : 'Grant location access'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: notifier.refresh,
              child: const Text('I already allowed — refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelStatus extends StatelessWidget {
  final LocationPermissionLevel level;
  const _LevelStatus({required this.level});

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (level) {
      LocationPermissionLevel.always =>
        ('Allowed all the time ✓', Colors.green),
      LocationPermissionLevel.whileInUse =>
        ('Only "while using" — background ke liye upgrade kar', Colors.orange),
      LocationPermissionLevel.denied => ('Not granted yet', Colors.grey),
      LocationPermissionLevel.deniedForever =>
        ('Blocked by OS', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }
}
