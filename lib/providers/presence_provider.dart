import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/family_member.dart';
import 'family_provider.dart';
import 'location_provider.dart';

/// Live map {uid → latest location} for every member of the current family.
final familyPresenceProvider =
    StreamProvider<Map<String, LastLocation>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (familyId == null) return Stream.value(const {});
  return ref.watch(presenceRepositoryProvider).watchAllPresence(familyId);
});
