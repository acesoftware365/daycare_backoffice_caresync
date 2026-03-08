import 'package:cloud_firestore/cloud_firestore.dart';

class ParentAccount {
  const ParentAccount({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.authUid,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String authUid;

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
    );
  }
}

class ChildRecord {
  const ChildRecord({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.parentId,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String parentId;

  String get fullName => '$firstName $lastName'.trim();

  factory ChildRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChildRecord(
      id: doc.id,
      firstName: (data['firstName'] ?? '').toString(),
      lastName: (data['lastName'] ?? '').toString(),
      parentId: (data['parentId'] ?? '').toString(),
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
  });

  final String id;
  final String firstName;
  final String lastName;
  final String childId;
  final DateTime? physicalExamIssuedAt;
  final DateTime? physicalExamExpiresAt;
  final DateTime? fingerprintIssuedAt;
  final DateTime? fingerprintExpiresAt;

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
    );
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
