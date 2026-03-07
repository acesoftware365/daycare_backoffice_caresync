class TenantMembership {
  const TenantMembership({
    required this.uid,
    required this.tenantId,
    required this.role,
    required this.status,
    required this.displayName,
    required this.email,
  });

  final String uid;
  final String tenantId;
  final String role;
  final String status;
  final String displayName;
  final String email;

  bool get isActive => status == 'active';
  bool get isAdmin => role == 'admin';

  factory TenantMembership.fromMap(Map<String, dynamic> data) {
    return TenantMembership(
      uid: (data['uid'] ?? '').toString(),
      tenantId: (data['tenantId'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      displayName: (data['displayName'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
    );
  }
}
