import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../services/oem_detector.dart';
import 'profile_fields.dart';

class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _familyNameController = TextEditingController();
  final _nameController = TextEditingController();
  Relation? _relation = Relation.self;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _familyNameController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) throw StateError('Not signed in');

      final oem = await OemDetector().detect();

      final member = FamilyMember(
        id: user.uid,
        name: _nameController.text.trim(),
        role: FamilyRole.admin,
        relation: _relation!,
        phoneNumber: user.phoneNumber ?? '',
        phoneOem: oem.oem,
        createdAt: DateTime.now().toUtc(),
      );

      await ref.read(familyRepositoryProvider).createFamily(
            name: _familyNameController.text.trim(),
            adminMember: member,
          );

      // currentFamilyIdProvider will flip; AuthGate routes us to dashboard.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create family')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _familyNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Family ka naam',
                  hintText: 'Jaise: Sangwan family',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Naam daal' : null,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Tera profile',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ProfileFields(
                nameController: _nameController,
                selectedRelation: _relation,
                onRelationChanged: (v) => setState(() => _relation = v),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _creating ? null : _create,
                child: _creating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create family'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
