import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyContactRecord {
  const FamilyContactRecord({
    required this.name,
    required this.phone,
    required this.relation,
  });

  final String name;
  final String phone;
  final String relation;

  factory FamilyContactRecord.fromMap(Map<String, dynamic>? data) {
    final raw = data ?? const <String, dynamic>{};
    return FamilyContactRecord(
      name: (raw['name'] ?? '').toString(),
      phone: (raw['phone'] ?? '').toString(),
      relation: (raw['relation'] ?? '').toString(),
    );
  }
}

class ParentAccount {
  const ParentAccount({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.authUid,
    required this.phone,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.zip,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.emergencyContacts,
    required this.authorizedPickupContacts,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String authUid;
  final String phone;
  final String addressLine1;
  final String city;
  final String state;
  final String zip;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final List<FamilyContactRecord> emergencyContacts;
  final List<FamilyContactRecord> authorizedPickupContacts;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  factory ParentAccount.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ParentAccount(
      id: doc.id,
      email: (data['email'] ?? '').toString(),
      firstName: (data['firstName'] ?? '').toString(),
      lastName: (data['lastName'] ?? '').toString(),
      authUid: (data['authUid'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      addressLine1: (data['addressLine1'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
      state: (data['state'] ?? '').toString(),
      zip: (data['zip'] ?? '').toString(),
      emergencyContactName: (data['emergencyContactName'] ?? '').toString(),
      emergencyContactPhone: (data['emergencyContactPhone'] ?? '').toString(),
      emergencyContacts:
          ((data['emergencyContacts'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(FamilyContactRecord.fromMap)
              .toList(),
      authorizedPickupContacts:
          ((data['authorizedPickupContacts'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(FamilyContactRecord.fromMap)
              .toList(),
    );
  }
}

class ChildRecord {
  const ChildRecord({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.parentId,
    required this.ageYears,
    required this.dateOfBirth,
    required this.photoPermissionSigned,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String parentId;
  final int? ageYears;
  final DateTime? dateOfBirth;
  final bool photoPermissionSigned;

  String get fullName => '$firstName $lastName'.trim();

  factory ChildRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChildRecord(
      id: doc.id,
      firstName: (data['firstName'] ?? '').toString(),
      lastName: (data['lastName'] ?? '').toString(),
      parentId: (data['parentId'] ?? '').toString(),
      ageYears: (data['ageYears'] as num?)?.toInt(),
      dateOfBirth: HouseholdMemberRecord._asDateTime(data['dateOfBirth']),
      photoPermissionSigned: data['photoPermissionSigned'] == true,
    );
  }
}

class HouseholdMemberRecord {
  const HouseholdMemberRecord({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.childId,
    required this.physicalExamIssuedAt,
    required this.physicalExamExpiresAt,
    required this.fingerprintIssuedAt,
    required this.fingerprintExpiresAt,
    required this.physicalExamPhotoUrl,
    required this.fingerprintPhotoUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String childId;
  final DateTime? physicalExamIssuedAt;
  final DateTime? physicalExamExpiresAt;
  final DateTime? fingerprintIssuedAt;
  final DateTime? fingerprintExpiresAt;
  final String physicalExamPhotoUrl;
  final String fingerprintPhotoUrl;

  factory HouseholdMemberRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return HouseholdMemberRecord(
      id: doc.id,
      firstName: (data['firstName'] ?? '').toString(),
      lastName: (data['lastName'] ?? '').toString(),
      childId: (data['childId'] ?? '').toString(),
      physicalExamIssuedAt: _asDateTime(data['physicalExamIssuedAt']),
      physicalExamExpiresAt: _asDateTime(data['physicalExamExpiresAt']),
      fingerprintIssuedAt: _asDateTime(data['fingerprintIssuedAt']),
      fingerprintExpiresAt: _asDateTime(data['fingerprintExpiresAt']),
      physicalExamPhotoUrl: (data['physicalExamPhotoUrl'] ?? '').toString(),
      fingerprintPhotoUrl: (data['fingerprintPhotoUrl'] ?? '').toString(),
    );
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class ChildRequestRecord {
  const ChildRequestRecord({
    required this.id,
    required this.parentId,
    required this.firstName,
    required this.lastName,
    required this.notes,
    required this.status,
  });

  final String id;
  final String parentId;
  final String firstName;
  final String lastName;
  final String notes;
  final String status;

  String get fullName => '$firstName $lastName'.trim();

  factory ChildRequestRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChildRequestRecord(
      id: doc.id,
      parentId: (data['parentId'] ?? '').toString(),
      firstName: (data['firstName'] ?? '').toString(),
      lastName: (data['lastName'] ?? '').toString(),
      notes: (data['notes'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
    );
  }
}

class PickupNotificationRecord {
  const PickupNotificationRecord({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.parentName,
    required this.childName,
    required this.message,
    required this.status,
    required this.etaMinutes,
    required this.createdAt,
  });

  final String id;
  final String parentId;
  final String childId;
  final String parentName;
  final String childName;
  final String message;
  final String status;
  final int etaMinutes;
  final DateTime? createdAt;

  factory PickupNotificationRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return PickupNotificationRecord(
      id: doc.id,
      parentId: (data['parentId'] ?? '').toString(),
      childId: (data['childId'] ?? '').toString(),
      parentName: (data['parentName'] ?? '').toString(),
      childName: (data['childName'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      etaMinutes: (data['etaMinutes'] as num?)?.toInt() ?? 0,
      createdAt: HouseholdMemberRecord._asDateTime(data['createdAt']),
    );
  }
}

class StaffDocumentRecord {
  const StaffDocumentRecord({
    required this.submittedAt,
    required this.expiresAt,
    required this.photoUrl,
    required this.photoPath,
    required this.photoName,
  });

  final DateTime? submittedAt;
  final DateTime? expiresAt;
  final String photoUrl;
  final String photoPath;
  final String photoName;

  bool get hasPhoto => photoUrl.trim().isNotEmpty;

  factory StaffDocumentRecord.fromMap(Map<String, dynamic>? data) {
    final raw = data ?? const <String, dynamic>{};
    return StaffDocumentRecord(
      submittedAt: HouseholdMemberRecord._asDateTime(raw['submittedAt']),
      expiresAt: HouseholdMemberRecord._asDateTime(raw['expiresAt']),
      photoUrl: (raw['photoUrl'] ?? '').toString(),
      photoPath: (raw['photoPath'] ?? '').toString(),
      photoName: (raw['photoName'] ?? '').toString(),
    );
  }
}

class StaffMemberRecord {
  const StaffMemberRecord({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.daycareLicenseRole,
    required this.roleNotes,
    required this.backgroundCheck,
    required this.physical,
    required this.drugAdministrationLicense,
    required this.cpr,
    required this.createdAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String daycareLicenseRole;
  final String roleNotes;
  final StaffDocumentRecord backgroundCheck;
  final StaffDocumentRecord physical;
  final StaffDocumentRecord drugAdministrationLicense;
  final StaffDocumentRecord cpr;
  final DateTime? createdAt;

  String get fullName => '$firstName $lastName'.trim();

  factory StaffMemberRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StaffMemberRecord(
      id: doc.id,
      firstName: (data['firstName'] ?? '').toString(),
      lastName: (data['lastName'] ?? '').toString(),
      dateOfBirth: HouseholdMemberRecord._asDateTime(data['dateOfBirth']),
      daycareLicenseRole: (data['daycareLicenseRole'] ?? '').toString(),
      roleNotes: (data['roleNotes'] ?? '').toString(),
      backgroundCheck: StaffDocumentRecord.fromMap(
        data['backgroundCheck'] as Map<String, dynamic>?,
      ),
      physical: StaffDocumentRecord.fromMap(
        data['physical'] as Map<String, dynamic>?,
      ),
      drugAdministrationLicense: StaffDocumentRecord.fromMap(
        data['drugAdministrationLicense'] as Map<String, dynamic>?,
      ),
      cpr: StaffDocumentRecord.fromMap(data['cpr'] as Map<String, dynamic>?),
      createdAt: HouseholdMemberRecord._asDateTime(data['createdAt']),
    );
  }
}
