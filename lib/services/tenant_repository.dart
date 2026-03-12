import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  CollectionReference<Map<String, dynamic>> _pickupNotificationsRef(
    String tenantId,
  ) {
    return FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('pickup_notifications');
  }

  CollectionReference<Map<String, dynamic>> _staffRef(String tenantId) {
    return FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('staff');
  }

  DocumentReference<Map<String, dynamic>> _latestUpdateRef(
    String tenantId,
    String childId,
  ) {
    return _childrenRef(
      tenantId,
    ).doc(childId).collection('latest_updates').doc('current');
  }

  DocumentReference<Map<String, dynamic>> _todaySummaryRef(
    String tenantId,
    String childId,
  ) {
    return _childrenRef(
      tenantId,
    ).doc(childId).collection('today_summary').doc('current');
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

  Stream<ParentAccount?> watchParent(String tenantId, String parentId) {
    return _parentsRef(tenantId).doc(parentId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return ParentAccount.fromDoc(doc);
    });
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

  Future<Map<String, dynamic>> loadParentContractDocument({
    required String tenantId,
    required String parentId,
  }) async {
    final doc = await _parentsRef(tenantId).doc(parentId).get();
    return doc.data() ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> loadPhotoPermissionDocument({
    required String tenantId,
    required String childId,
    required String parentId,
  }) async {
    final doc = await _childrenRef(
      tenantId,
    ).doc(childId).collection('photo_permissions').doc(parentId).get();
    return doc.data() ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> loadChildEnrollmentDocument({
    required String tenantId,
    required String childId,
    required String parentId,
  }) async {
    final doc = await _childrenRef(
      tenantId,
    ).doc(childId).collection('enrollment_forms').doc(parentId).get();
    return doc.data() ?? const <String, dynamic>{};
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

  Stream<List<PickupNotificationRecord>> watchPendingPickupNotifications(
    String tenantId,
  ) {
    return _pickupNotificationsRef(tenantId).snapshots().map((snapshot) {
      final items =
          snapshot.docs
              .map(PickupNotificationRecord.fromDoc)
              .where((item) => item.status == 'pending')
              .toList()
            ..sort((a, b) {
              final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
              final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
              return bTime.compareTo(aTime);
            });
      return items;
    });
  }

  Future<void> acknowledgePickupNotification({
    required String tenantId,
    required String notificationId,
    required String uid,
  }) async {
    await _pickupNotificationsRef(tenantId).doc(notificationId).set({
      'status': 'received',
      'receivedAt': FieldValue.serverTimestamp(),
      'receivedByUid': uid,
      'sourceApp': 'daycare_backoffice',
    }, SetOptions(merge: true));
  }

  Stream<List<StaffMemberRecord>> watchStaffMembers(String tenantId) {
    return _staffRef(tenantId).snapshots().map((snapshot) {
      final items = snapshot.docs.map(StaffMemberRecord.fromDoc).toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      return items;
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchLatestUpdate(
    String tenantId,
    String childId,
  ) {
    return _latestUpdateRef(tenantId, childId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTodaySummary(
    String tenantId,
    String childId,
  ) {
    return _todaySummaryRef(tenantId, childId).snapshots();
  }

  String newStaffId(String tenantId) => _staffRef(tenantId).doc().id;

  String newHouseholdMemberId(String tenantId) =>
      _householdRef(tenantId).doc().id;

  Future<UploadedStaffPhoto> uploadStaffDocumentPhoto({
    required String tenantId,
    required String staffId,
    required String documentKey,
    required String fileName,
    required List<int> bytes,
    String? contentType,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        'tenants/$tenantId/staff_documents/$staffId/$documentKey/$safeName';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: contentType ?? 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();
    return UploadedStaffPhoto(url: url, path: path, fileName: safeName);
  }

  Future<UploadedStaffPhoto> uploadHouseholdDocumentPhoto({
    required String tenantId,
    required String householdMemberId,
    required String documentKey,
    required String fileName,
    required List<int> bytes,
    String? contentType,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        'tenants/$tenantId/household_documents/$householdMemberId/$documentKey/$safeName';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: contentType ?? 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();
    return UploadedStaffPhoto(url: url, path: path, fileName: safeName);
  }

  Future<UploadedStaffPhoto> uploadChildUpdatePhoto({
    required String tenantId,
    required String childId,
    required String fileName,
    required List<int> bytes,
    String? contentType,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'tenants/$tenantId/child_updates/$childId/$safeName';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: contentType ?? 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();
    return UploadedStaffPhoto(url: url, path: path, fileName: safeName);
  }

  Future<void> createStaffMember({
    required String tenantId,
    required String uid,
    required String staffId,
    required String firstName,
    required String lastName,
    required DateTime? dateOfBirth,
    required String daycareLicenseRole,
    required String roleNotes,
    required Map<String, dynamic> backgroundCheck,
    required Map<String, dynamic> physical,
    required Map<String, dynamic> drugAdministrationLicense,
    required Map<String, dynamic> cpr,
  }) async {
    await _staffRef(tenantId).doc(staffId).set({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'dateOfBirth': _asTimestamp(dateOfBirth),
      'daycareLicenseRole': daycareLicenseRole,
      'roleNotes': roleNotes,
      'backgroundCheck': backgroundCheck,
      'physical': physical,
      'drugAdministrationLicense': drugAdministrationLicense,
      'cpr': cpr,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': uid,
      'sourceApp': 'daycare_backoffice',
    });
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
      'emergencyContacts': const [],
      'authorizedPickupContacts': const [],
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

  Future<void> updateParent({
    required String tenantId,
    required String parentId,
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    String phone = '',
    String addressLine1 = '',
    String city = '',
    String state = '',
    String zip = '',
    String emergencyContactName = '',
    String emergencyContactPhone = '',
    List<Map<String, String>> emergencyContacts = const [],
    List<Map<String, String>> authorizedPickupContacts = const [],
  }) async {
    await _parentsRef(tenantId).doc(parentId).set({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'addressLine1': addressLine1.trim(),
      'city': city.trim(),
      'state': state.trim(),
      'zip': zip.trim(),
      'emergencyContactName': emergencyContactName.trim(),
      'emergencyContactPhone': emergencyContactPhone.trim(),
      'emergencyContacts': emergencyContacts,
      'authorizedPickupContacts': authorizedPickupContacts,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': uid,
      'sourceApp': 'daycare_backoffice',
    }, SetOptions(merge: true));
  }

  Future<void> addAuthorizedPickupContact({
    required String tenantId,
    required String parentId,
    required String uid,
    required List<Map<String, String>> authorizedPickupContacts,
  }) async {
    await _parentsRef(tenantId).doc(parentId).set({
      'authorizedPickupContacts': authorizedPickupContacts,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': uid,
      'sourceApp': 'daycare_backoffice',
    }, SetOptions(merge: true));
  }

  Future<void> saveEmergencyContacts({
    required String tenantId,
    required String parentId,
    required String uid,
    required List<Map<String, String>> emergencyContacts,
  }) async {
    await _parentsRef(tenantId).doc(parentId).set({
      'emergencyContacts': emergencyContacts,
      'emergencyContactName': emergencyContacts.isEmpty
          ? ''
          : emergencyContacts.first['name'] ?? '',
      'emergencyContactPhone': emergencyContacts.isEmpty
          ? ''
          : emergencyContacts.first['phone'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': uid,
      'sourceApp': 'daycare_backoffice',
    }, SetOptions(merge: true));
  }

  Future<void> deleteParent({
    required String tenantId,
    required String parentId,
  }) async {
    final linkedChildren = await _childrenRef(
      tenantId,
    ).where('parentId', isEqualTo: parentId).limit(1).get();
    if (linkedChildren.docs.isNotEmpty) {
      throw StateError('Delete the linked children first.');
    }

    final parentDoc = await _parentsRef(tenantId).doc(parentId).get();
    final authUid = (parentDoc.data()?['authUid'] ?? '').toString().trim();

    await _parentsRef(tenantId).doc(parentId).delete();

    if (authUid.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('parent_memberships')
          .doc(authUid)
          .delete();
    }
  }

  Future<void> createChild({
    required String tenantId,
    required String uid,
    required String firstName,
    required String lastName,
    required String parentId,
    DateTime? dateOfBirth,
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
    final normalizedDob = _normalizeDate(dateOfBirth);
    await doc.set({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'parentId': parentId,
      'ageYears': _ageFromDateOfBirth(normalizedDob),
      'dateOfBirth': _asTimestamp(normalizedDob),
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': uid,
      'sourceApp': 'daycare_backoffice',
    });
  }

  Future<void> updateChild({
    required String tenantId,
    required String childId,
    required String uid,
    required String firstName,
    required String lastName,
    required DateTime? dateOfBirth,
  }) async {
    final normalizedDob = _normalizeDate(dateOfBirth);
    await _childrenRef(tenantId).doc(childId).set({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'ageYears': _ageFromDateOfBirth(normalizedDob),
      'dateOfBirth': _asTimestamp(normalizedDob),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': uid,
      'sourceApp': 'daycare_backoffice',
    }, SetOptions(merge: true));
  }

  Future<void> deleteChild({
    required String tenantId,
    required String childId,
  }) async {
    await _childrenRef(tenantId).doc(childId).delete();
  }

  Future<void> createHouseholdMember({
    required String tenantId,
    required String uid,
    required String householdMemberId,
    required String firstName,
    required String lastName,
    String childId = '',
    DateTime? physicalExamIssuedAt,
    DateTime? physicalExamExpiresAt,
    DateTime? fingerprintIssuedAt,
    DateTime? fingerprintExpiresAt,
    String physicalExamPhotoUrl = '',
    String fingerprintPhotoUrl = '',
  }) async {
    await _householdRef(tenantId).doc(householdMemberId).set({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'childId': childId,
      'physicalExamIssuedAt': _asTimestamp(physicalExamIssuedAt),
      'physicalExamExpiresAt': _asTimestamp(physicalExamExpiresAt),
      'fingerprintIssuedAt': _asTimestamp(fingerprintIssuedAt),
      'fingerprintExpiresAt': _asTimestamp(fingerprintExpiresAt),
      'physicalExamPhotoUrl': physicalExamPhotoUrl,
      'fingerprintPhotoUrl': fingerprintPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': uid,
      'sourceApp': 'daycare_backoffice',
    });
  }

  Future<void> publishLatestUpdate({
    required String tenantId,
    required String uid,
    required String childId,
    required String childName,
    required String note,
    required String photoUrl,
    required String photoPath,
    required String photoName,
  }) async {
    final payload = {
      'childId': childId,
      'childName': childName,
      'note': note.trim(),
      'photoUrl': photoUrl,
      'photoPath': photoPath,
      'photoName': photoName,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': uid,
      'sourceApp': 'daycare_backoffice',
    };
    await _latestUpdateRef(
      tenantId,
      childId,
    ).set(payload, SetOptions(merge: true));
    await _childrenRef(tenantId).doc(childId).set({
      'latestUpdateNote': note.trim(),
      'latestUpdatePhotoUrl': photoUrl,
      'latestUpdatePhotoPath': photoPath,
      'latestUpdatePhotoName': photoName,
      'latestUpdateCreatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': uid,
      'sourceApp': 'daycare_backoffice',
    }, SetOptions(merge: true));
  }

  Future<void> saveTodaySummary({
    required String tenantId,
    required String uid,
    required String childId,
    required List<String> tags,
  }) async {
    final now = DateTime.now();
    final dateKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await _todaySummaryRef(tenantId, childId).set({
      'childId': childId,
      'tags': tags,
      'dateKey': dateKey,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': uid,
      'sourceApp': 'daycare_backoffice',
    }, SetOptions(merge: true));
    await _childrenRef(tenantId).doc(childId).set({
      'todaySummaryTags': tags,
      'todaySummaryDateKey': dateKey,
      'todaySummaryUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': uid,
      'sourceApp': 'daycare_backoffice',
    }, SetOptions(merge: true));
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

  DateTime? _normalizeDate(DateTime? value) {
    if (value == null) return null;
    return DateTime(value.year, value.month, value.day);
  }

  int? _ageFromDateOfBirth(DateTime? dateOfBirth) {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    var age = now.year - dateOfBirth.year;
    final birthdayPassed =
        now.month > dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);
    if (!birthdayPassed) age -= 1;
    return age < 0 ? 0 : age;
  }
}

class UploadedStaffPhoto {
  const UploadedStaffPhoto({
    required this.url,
    required this.path,
    required this.fileName,
  });

  final String url;
  final String path;
  final String fileName;
}
