import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/family.dart';
import '../models/family_member.dart';

class CreateFamilyResult {
  final String familyId;
  final String inviteCode;
  const CreateFamilyResult({required this.familyId, required this.inviteCode});
}

class FamilyRepository {
  final FirebaseFirestore _db;
  FamilyRepository(this._db);

  // --- membership index: tells each user which groups they belong to ---

  /// Legacy single-group accessor kept for backwards compatibility.
  Stream<String?> watchMembershipFamilyId(String uid) {
    return watchMembershipGroupIds(uid).map((ids) => ids.isEmpty ? null : ids.first);
  }

  /// All groups the user belongs to. Prefers the new `group_ids` array but
  /// transparently falls back to the legacy single `family_id` field so
  /// existing deployments keep working across the migration.
  Stream<List<String>> watchMembershipGroupIds(String uid) {
    return _db.collection('user_memberships').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return const <String>[];
      final data = snap.data();
      if (data == null) return const <String>[];
      final arr = (data['group_ids'] as List?)?.cast<String>();
      if (arr != null && arr.isNotEmpty) return arr;
      final legacy = data['family_id'] as String?;
      if (legacy != null) return [legacy];
      return const <String>[];
    });
  }

  /// One-shot migration — if the user's membership doc still has the old
  /// `family_id` scalar and no `group_ids` array, write the array in place.
  /// Safe to call on every app start.
  Future<void> migrateMembershipIfNeeded(String uid) async {
    final ref = _db.collection('user_memberships').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null) return;
    final hasArr = data['group_ids'] is List;
    final legacy = data['family_id'] as String?;
    if (!hasArr && legacy != null) {
      await ref.set(
        {'group_ids': [legacy]},
        SetOptions(merge: true),
      );
    }
  }

  // --- family ---

  Stream<Family?> watchFamily(String familyId) {
    return _db.collection('families').doc(familyId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Family.fromJson({...snap.data()!, 'id': snap.id});
    });
  }

  /// Admin creates the family. Done in two writes because invite creation
  /// requires the creator to already be a member of the target family, and
  /// Firestore rules evaluate each write against committed state.
  Future<CreateFamilyResult> createFamily({
    required String name,
    required FamilyMember adminMember,
  }) async {
    final familyRef = _db.collection('families').doc();
    final family = Family(
      id: familyRef.id,
      name: name,
      adminId: adminMember.id,
      createdAt: DateTime.now().toUtc(),
    );

    final batch = _db.batch();
    batch.set(familyRef, family.toJson());
    batch.set(
      familyRef.collection('members').doc(adminMember.id),
      adminMember.toJson(),
    );
    // Append this group to the user's membership array (array union handles
    // both "first group ever" and "nth group" cases).
    batch.set(
      _db.collection('user_memberships').doc(adminMember.id),
      {
        'group_ids': FieldValue.arrayUnion([familyRef.id]),
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    // Second write: now the admin is a member, so the invite rule passes.
    final inviteCode = _generateInviteCode();
    await _db.collection('invites').doc(inviteCode).set({
      'family_id': familyRef.id,
      'created_by': adminMember.id,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    return CreateFamilyResult(familyId: familyRef.id, inviteCode: inviteCode);
  }

  /// Look up an invite code and return the matching family id, or null.
  Future<String?> familyIdForInviteCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final snap = await _db.collection('invites').doc(normalized).get();
    if (!snap.exists) return null;
    return snap.data()?['family_id'] as String?;
  }

  /// Join an existing family as [member]. Also writes the membership index.
  Future<void> joinFamily({
    required String familyId,
    required FamilyMember member,
  }) async {
    final batch = _db.batch();
    batch.set(
      _db
          .collection('families')
          .doc(familyId)
          .collection('members')
          .doc(member.id),
      member.toJson(),
    );
    batch.set(
      _db.collection('user_memberships').doc(member.id),
      {
        'group_ids': FieldValue.arrayUnion([familyId]),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Leave a group: deletes the user's member and presence docs, removes
  /// the group id from their membership array. Keeps the group itself —
  /// only admin can delete the group entirely.
  Future<void> leaveGroup({
    required String familyId,
    required String uid,
  }) async {
    final batch = _db.batch();
    batch.delete(
      _db
          .collection('families')
          .doc(familyId)
          .collection('members')
          .doc(uid),
    );
    batch.delete(
      _db
          .collection('families')
          .doc(familyId)
          .collection('presence')
          .doc(uid),
    );
    batch.update(
      _db.collection('user_memberships').doc(uid),
      {
        'group_ids': FieldValue.arrayRemove([familyId]),
      },
    );
    await batch.commit();
  }

  /// Admin promotes/demotes a member by changing their role field.
  Future<void> setMemberRole({
    required String familyId,
    required String memberId,
    required bool asAdmin,
  }) async {
    await _db
        .collection('families')
        .doc(familyId)
        .collection('members')
        .doc(memberId)
        .update({'role': asAdmin ? 'admin' : 'member'});
  }

  /// Admin removes a member from the group entirely (used when kicking a
  /// friend out of the family group, etc.).
  Future<void> removeMember({
    required String familyId,
    required String memberId,
  }) async {
    final batch = _db.batch();
    batch.delete(
      _db
          .collection('families')
          .doc(familyId)
          .collection('members')
          .doc(memberId),
    );
    batch.delete(
      _db
          .collection('families')
          .doc(familyId)
          .collection('presence')
          .doc(memberId),
    );
    batch.update(
      _db.collection('user_memberships').doc(memberId),
      {
        'group_ids': FieldValue.arrayRemove([familyId]),
      },
    );
    await batch.commit();
  }

  // --- members ---

  Stream<List<FamilyMember>> watchMembers(String familyId) {
    return _db
        .collection('families')
        .doc(familyId)
        .collection('members')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FamilyMember.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  // --- invite codes ---

  /// All active invite codes for a family (admin may want to share one).
  Stream<List<String>> watchInviteCodes(String familyId) {
    return _db
        .collection('invites')
        .where('family_id', isEqualTo: familyId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  /// Alphabet excludes 0/O/1/I/L to avoid read-aloud confusion.
  static const _codeAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static final _rng = Random.secure();

  static String _generateInviteCode([int length = 6]) {
    return List.generate(
      length,
      (_) => _codeAlphabet[_rng.nextInt(_codeAlphabet.length)],
    ).join();
  }
}
