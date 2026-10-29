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

  // --- membership index: tells each user which family they belong to ---

  Stream<String?> watchMembershipFamilyId(String uid) {
    return _db.collection('user_memberships').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return snap.data()?['family_id'] as String?;
    });
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
    batch.set(
      _db.collection('user_memberships').doc(adminMember.id),
      {'family_id': familyRef.id},
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
      {'family_id': familyId},
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
