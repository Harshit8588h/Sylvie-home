import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/zone_repository.dart';
import '../models/safe_zone.dart';
import 'family_provider.dart';
import 'firestore_provider.dart';

final zoneRepositoryProvider = Provider<ZoneRepository>((ref) {
  return ZoneRepository(ref.watch(firestoreProvider));
});

/// Live list of safe zones for the current family.
final zonesProvider = StreamProvider<List<SafeZone>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (familyId == null) return Stream.value(const []);
  return ref.watch(zoneRepositoryProvider).watchZones(familyId);
});
