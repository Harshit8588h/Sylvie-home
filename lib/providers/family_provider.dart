// riverpod exports a type named `Family` (used internally for provider
// families). Hide it so our own `Family` model wins unambiguously here.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../data/family_repository.dart';
import '../models/family.dart';
import '../models/family_member.dart';
import 'auth_provider.dart';
import 'firestore_provider.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository(ref.watch(firestoreProvider));
});

/// The signed-in user's family id, from /user_memberships/{uid}.
/// null = user has not created or joined a family yet.
final currentFamilyIdProvider = StreamProvider<String?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(familyRepositoryProvider).watchMembershipFamilyId(uid);
});

final currentFamilyProvider = StreamProvider<Family?>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (familyId == null) return Stream.value(null);
  return ref.watch(familyRepositoryProvider).watchFamily(familyId);
});

final familyMembersProvider = StreamProvider<List<FamilyMember>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (familyId == null) return Stream.value(const []);
  return ref.watch(familyRepositoryProvider).watchMembers(familyId);
});

final familyInviteCodesProvider = StreamProvider<List<String>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (familyId == null) return Stream.value(const []);
  return ref.watch(familyRepositoryProvider).watchInviteCodes(familyId);
});
