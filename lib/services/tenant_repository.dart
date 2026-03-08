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

  CollectionReference<Map<String, dynamic>> _childRequestsRef(String tenantId) {
    return FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('child_requests');
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

  Stream<List<ChildRequestRecord>> watchPendingChildRequests(String tenantId) {
    return _childRequestsRef(tenantId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(ChildRequestRecord.fromDoc).toList(),
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

    if (authUid.trim().isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('parent_memberships')
          .doc(authUid)
          .set({
            'tenantId': tenantId,
            'parentId': doc.id,
            'email': email.trim().toLowerCase(),
            'status': 'active',
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': uid,
            'sourceApp': 'daycare_backoffice',
          }, SetOptions(merge: true));
    }
  }

  Future<void> createChild({
    required String tenantId,
    required String uid,
    required String firstName,
    required String lastName,
    required String parentId,
  }) async {
    final normalizedFirst = firstName.trim().toLowerCase();
    final normalizedLast = lastName.trim().toLowerCase();
    final existing = await _childrenRef(
      tenantId,
    ).where('parentId', isEqualTo: parentId).get();
    final duplicate = existing.docs.any((doc) {
      final data = doc.data();
      final f = (data['firstName'] ?? '').toString().trim().toLowerCase();
      final l = (data['lastName'] ?? '').toString().trim().toLowerCase();
      return f == normalizedFirst && l == normalizedLast;
    });
    if (duplicate) {
      throw StateError('Child already exists for this parent.');
    }

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

  Future<void> approveChildRequest({
    required String tenantId,
    required String uid,
    required ChildRequestRecord request,
  }) async {
    await createChild(
      tenantId: tenantId,
      uid: uid,
      firstName: request.firstName,
      lastName: request.lastName,
      parentId: request.parentId,
    );

    await _childRequestsRef(tenantId).doc(request.id).set({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedByUid': uid,
      'sourceApp': 'daycare_backoffice',
    }, SetOptions(merge: true));
  }

  Future<void> rejectChildRequest({
    required String tenantId,
    required String uid,
    required String requestId,
  }) async {
    await _childRequestsRef(tenantId).doc(requestId).set({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedByUid': uid,
      'sourceApp': 'daycare_backoffice',
    }, SetOptions(merge: true));
  }

  Timestamp? _asTimestamp(DateTime? value) {
    if (value == null) return null;
    return Timestamp.fromDate(value);
  }
}
