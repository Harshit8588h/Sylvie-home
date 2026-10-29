import 'package:flutter/material.dart';

import '../../models/family_member.dart';

/// Shared "your name + relation" sub-form reused by Create and Join screens.
class ProfileFields extends StatelessWidget {
  final TextEditingController nameController;
  final Relation? selectedRelation;
  final ValueChanged<Relation?> onRelationChanged;

  const ProfileFields({
    super.key,
    required this.nameController,
    required this.selectedRelation,
    required this.onRelationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Tera naam',
            hintText: 'Jaise: Harshit',
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Naam daal' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<Relation>(
          value: selectedRelation,
          decoration: const InputDecoration(
            labelText: 'Family mein tera relation',
            border: OutlineInputBorder(),
          ),
          items: Relation.values
              .map((r) => DropdownMenuItem(value: r, child: Text(_label(r))))
              .toList(),
          onChanged: onRelationChanged,
          validator: (v) => v == null ? 'Relation chun' : null,
        ),
      ],
    );
  }

  static String _label(Relation r) {
    switch (r) {
      case Relation.self:
        return 'Self (me)';
      case Relation.mother:
        return 'Mummy';
      case Relation.father:
        return 'Papa';
      case Relation.sister:
        return 'Behen / Didi';
      case Relation.brother:
        return 'Bhai';
      case Relation.grandmother:
        return 'Dadi / Nani';
      case Relation.grandfather:
        return 'Dada / Nana';
      case Relation.other:
        return 'Other';
    }
  }
}
