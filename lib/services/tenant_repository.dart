import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/family_records.dart';
import '../models/tenant_membership.dart';
import '../models/tenant_profile.dart';

class TenantRepository {
  const TenantRepository();

  CollectionReference<Map<String, dynamic>> _parentsRef(String tenantId) {
    return FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('parents');
  }

  CollectionReference<Map<String, dynamic>> _childrenRef(String tenantId) {
    return FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('children');
  }

  CollectionReference<Map<String, dynamic>> _householdRef(String tenantId) {
    return FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('household_members');
  }

  Stream<TenantMembership?> watchMembership(String uid) {
    return FirebaseFirestore.instance
        .collection('tenant_memberships')
        .doc(uid)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          if (data == null) return null;
          return TenantMembership.fromMap(data);
        });
  }

  Stream<TenantProfile?> watchTenant(String tenantId) {
    return FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          if (data == null) return null;
          return TenantProfile.fromMap(data);
        });
  }

  Future<void> updateTenantProfile({
    required String tenantId,
    required String uid,
    required String role,
    required Map<String, dynamic> changes,
  }) async {
    final payload = <String, dynamic>{
      ...changes,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': uid,
      'updatedByRole': role,
      'sourceApp': 'daycare_backoffice',
    };

    await FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .set(payload, SetOptions(merge: true));
  }

  Stream<List<ParentAccount>> watchParents(String tenantId) {
    return _parentsRef(tenantId)
        .orderBy('email')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ParentAccount.fromDoc).toList());
  }

  Future<List<ParentAccount>> getParents(String tenantId) async {
    final snapshot = await _parentsRef(tenantId).orderBy('email').get();
    return snapshot.docs.map(ParentAccount.fromDoc).toList();
  }

  Stream<List<ChildRecord>> watchChildren(String tenantId) {
    return _childrenRef(tenantId)
        .orderBy('firstName')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChildRecord.fromDoc).toList());
  }

  Future<List<ChildRecord>> getChildren(String tenantId) async {
    final snapshot = await _childrenRef(tenantId).orderBy('firstName').get();
    return snapshot.docs.map(ChildRecord.fromDoc).toList();
  }

  Stream<List<HouseholdMemberRecord>> watchHouseholdMembers(String tenantId) {
    return _householdRef(tenantId)
        .orderBy('firstName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(HouseholdMemberRecord.fromDoc).toList(),
        );
  }

  Future<void> createParent({
    required String tenantId,
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    required String authUid,
  }) async {
    final doc = _parentsRef(tenantId).doc();
    await doc.set({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim().toLowerCase(),
      'authUid': authUid,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': uid,
      'sourceApp': 'daycare_backoffice',
    });
  }

  Future<void> createChild({
    required String tenantId,
    required String uid,
    required String firstName,
    required String lastName,
    required String parentId,
  }) async {
    final doc = _childrenRef(tenantId).doc();
    await doc.set({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'parentId': parentId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': uid,
      'sourceApp': 'daycare_backoffice',
    });
  }

  Future<void> createHouseholdMember({
    required String tenantId,
    required String uid,
    required String firstName,
    required String lastName,
    required String childId,
    DateTime? physicalExamIssuedAt,
    DateTime? physicalExamExpiresAt,
    DateTime? fingerprintIssuedAt,
    DateTime? fingerprintExpiresAt,
  }) async {
    final doc = _householdRef(tenantId).doc();
    await doc.set({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'childId': childId,
      'physicalExamIssuedAt': _asTimestamp(physicalExamIssuedAt),
      'physicalExamExpiresAt': _asTimestamp(physicalExamExpiresAt),
      'fingerprintIssuedAt': _asTimestamp(fingerprintIssuedAt),
      'fingerprintExpiresAt': _asTimestamp(fingerprintExpiresAt),
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': uid,
      'sourceApp': 'daycare_backoffice',
    });
  }

  Timestamp? _asTimestamp(DateTime? value) {
    if (value == null) return null;
    return Timestamp.fromDate(value);
  }
}
