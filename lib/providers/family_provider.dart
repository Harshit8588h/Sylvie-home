import 'dart:async';

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

/// The group the user is currently viewing. Prefers the validated groups
/// list (so an admin-removed stale id in the raw membership array never
/// surfaces as the active group) and falls back to the raw list during
/// the brief first-load window where validation hasn't completed yet.
final activeGroupIdProvider = Provider<String?>((ref) {
  final persisted = ref.watch(activeGroupPrefProvider);
  final validated =
      ref.watch(userGroupsListProvider).valueOrNull ?? const <Family>[];
  if (validated.isNotEmpty) {
    final ids = validated.map((f) => f.id).toList();
    if (persisted != null && ids.contains(persisted)) return persisted;
    return ids.first;
  }
  // First-load fallback: raw memberships haven't been validated yet.
  final raw = ref.watch(userGroupIdsProvider).valueOrNull ?? const <String>[];
  if (raw.isEmpty) return null;
  if (persisted != null && raw.contains(persisted)) return persisted;
  return raw.first;
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

/// Validated list of groups the signed-in user actually still has a
/// member doc in. If an admin elsewhere removed them, their raw
/// user_memberships array still lists that group id — this provider
/// filters it out and asynchronously prunes the stale id from their
/// own membership doc so future reads stay consistent.
final userGroupsListProvider = FutureProvider<List<Family>>((ref) async {
  final ids = ref.watch(userGroupIdsProvider).valueOrNull ?? const <String>[];
  if (ids.isEmpty) return const <Family>[];
  final db = ref.watch(firestoreProvider);
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const <Family>[];

  final results = await Future.wait(ids.map((id) async {
    try {
      final familyDoc = await db.collection('families').doc(id).get();
      if (!familyDoc.exists) return (id, null);
      final memberDoc = await db
          .collection('families')
          .doc(id)
          .collection('members')
          .doc(uid)
          .get();
      if (!memberDoc.exists) return (id, null); // we got kicked
      return (
        id,
        Family.fromJson({...familyDoc.data()!, 'id': familyDoc.id}),
      );
    } catch (_) {
      // Permission denied or network blip — treat as stale rather than
      // crashing the whole list.
      return (id, null);
    }
  }));

  final live = <Family>[];
  final stale = <String>[];
  for (final (id, fam) in results) {
    if (fam != null) {
      live.add(fam);
    } else {
      stale.add(id);
    }
  }

  // Fire-and-forget self-prune of stale ids so we don't ask Firestore
  // for them again on the next poll.
  if (stale.isNotEmpty) {
    unawaited(
      ref
          .read(familyRepositoryProvider)
          .pruneMembershipGroups(uid: uid, staleGroupIds: stale),
    );
  }

  return live;
});
