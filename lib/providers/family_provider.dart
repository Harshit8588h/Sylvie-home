// riverpod exports a type named `Family` (used internally for provider
// families). Hide it so our own `Family` model wins unambiguously here.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../data/family_repository.dart';
import '../models/family.dart';
import '../models/family_member.dart';
import 'auth_provider.dart';
import 'firestore_provider.dart';
import 'preferences_provider.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository(ref.watch(firestoreProvider));
});

/// Every group the signed-in user is a member of.
final userGroupIdsProvider = StreamProvider<List<String>>((ref) async* {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    yield const <String>[];
    return;
  }
  final repo = ref.watch(familyRepositoryProvider);
  // One-shot migration so legacy {family_id: x} docs become
  // {group_ids: [x]} and the rest of the app only has to read the array.
  await repo.migrateMembershipIfNeeded(uid);
  yield* repo.watchMembershipGroupIds(uid);
});

/// The group the user is currently viewing. Falls back to the first
/// known membership if the persisted choice is stale or missing.
final activeGroupIdProvider = Provider<String?>((ref) {
  final persisted = ref.watch(activeGroupPrefProvider);
  final memberships =
      ref.watch(userGroupIdsProvider).valueOrNull ?? const <String>[];
  if (memberships.isEmpty) return null;
  if (persisted != null && memberships.contains(persisted)) return persisted;
  return memberships.first;
});

/// Legacy alias — kept so screens that reasoned about a single family id
/// keep compiling. New code should prefer activeGroupIdProvider directly.
final currentFamilyIdProvider = StreamProvider<String?>((ref) async* {
  yield ref.watch(activeGroupIdProvider);
  // Re-emit whenever the active group changes.
  ref.listen(activeGroupIdProvider, (_, next) {});
});

final currentFamilyProvider = StreamProvider<Family?>((ref) {
  final familyId = ref.watch(activeGroupIdProvider);
  if (familyId == null) return Stream.value(null);
  return ref.watch(familyRepositoryProvider).watchFamily(familyId);
});

final familyMembersProvider = StreamProvider<List<FamilyMember>>((ref) {
  final familyId = ref.watch(activeGroupIdProvider);
  if (familyId == null) return Stream.value(const []);
  return ref.watch(familyRepositoryProvider).watchMembers(familyId);
});

final familyInviteCodesProvider = StreamProvider<List<String>>((ref) {
  final familyId = ref.watch(activeGroupIdProvider);
  if (familyId == null) return Stream.value(const []);
  return ref.watch(familyRepositoryProvider).watchInviteCodes(familyId);
});

/// All groups' Family docs — needed by the group switcher. Fetched as a
/// one-shot per membership change; group names rarely change so a live
/// stream per group isn't worth the complexity here.
final userGroupsListProvider = FutureProvider<List<Family>>((ref) async {
  final ids = ref.watch(userGroupIdsProvider).valueOrNull ?? const <String>[];
  if (ids.isEmpty) return const <Family>[];
  final db = ref.watch(firestoreProvider);
  final docs = await Future.wait(
    ids.map((id) => db.collection('families').doc(id).get()),
  );
  return docs
      .where((d) => d.exists)
      .map((d) => Family.fromJson({...d.data()!, 'id': d.id}))
      .toList();
});
