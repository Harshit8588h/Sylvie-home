import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/alert_repository.dart';
import '../models/alert.dart';
import 'family_provider.dart';
import 'firestore_provider.dart';

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepository(ref.watch(firestoreProvider));
});

final alertsProvider = StreamProvider<List<FamilyAlert>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (familyId == null) return Stream.value(const []);
  return ref.watch(alertRepositoryProvider).watchAlerts(familyId);
});

/// Just the unresolved alerts, used by the Alerts tab badge.
final unresolvedAlertsProvider = Provider<List<FamilyAlert>>((ref) {
  final all = ref.watch(alertsProvider).valueOrNull ?? const [];
  return all.where((a) => !a.resolved).toList();
});
