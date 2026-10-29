import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import 'create_family_screen.dart';
import 'join_family_screen.dart';

/// Shown right after a user signs in but hasn't picked a family yet.
/// Admin → "Create family". Everyone else → "Join family" with the invite
/// code the admin shares.
class CreateOrJoinScreen extends ConsumerWidget {
  const CreateOrJoinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Family setup',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Pehla member family banata hai aur ek invite code generate hota hai. '
              'Baaki log us code se join karte hain.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            _BigChoiceCard(
              icon: Icons.home_outlined,
              title: 'Create family',
              subtitle: 'Admin ban aur apni family set up kar',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateFamilyScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _BigChoiceCard(
              icon: Icons.group_add_outlined,
              title: 'Join family',
              subtitle: 'Admin ne jo code bheja hai use daalo',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JoinFamilyScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _BigChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
