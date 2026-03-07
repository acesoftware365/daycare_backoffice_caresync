import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tenant_membership.dart';
import '../models/tenant_profile.dart';

class TenantRepository {
  const TenantRepository();

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
}
