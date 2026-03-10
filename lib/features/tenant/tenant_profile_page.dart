import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../form_document_pdf.dart';
import '../../models/family_records.dart';
import '../../models/tenant_membership.dart';
import '../../models/tenant_profile.dart';
import '../../services/auth_service.dart';
import '../../services/tenant_repository.dart';

enum TenantProfileAction { addParent, addChild, addHouseholdMember }

class TenantProfilePage extends StatefulWidget {
  const TenantProfilePage({
    super.key,
    required this.uid,
    required this.membership,
    this.requestedAction,
    this.onActionHandled,
  });

  final String uid;
  final TenantMembership membership;
  final TenantProfileAction? requestedAction;
  final VoidCallback? onActionHandled;

  @override
  State<TenantProfilePage> createState() => _TenantProfilePageState();
}

class _TenantProfilePageState extends State<TenantProfilePage> {
  final _repo = const TenantRepository();
  final _authService = const AuthService();

  @override
  void initState() {
    super.initState();
    _consumeRequestedAction();
  }

  @override
  void didUpdateWidget(covariant TenantProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestedAction != widget.requestedAction) {
      _consumeRequestedAction();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TenantProfile?>(
      stream: _repo.watchTenant(widget.membership.tenantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data;
        if (profile == null) {
          return const Center(child: Text('Daycare document not found.'));
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildHeroHeader(),
                const SizedBox(height: 16),
                _buildProfileCard(context, profile),
                const SizedBox(height: 16),
                _buildChildrenSection(),
                const SizedBox(height: 16),
                _buildParentFormsSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8DDE5), Color(0xFFD8EBFF), Color(0xFFDFF5E6)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              child: Center(child: Icon(Icons.apartment_rounded, size: 30)),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAYCARE PROFILE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Color(0xFF667085),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Families, enrollment, and records',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Organized sections for parents, children, requests, and household members.',
                  style: TextStyle(color: Color(0xFF5E6D79)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, TenantProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daycare Profile',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Protected fields are read-only in backoffice.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Plan Status', _capitalize(profile.planStatus)),
                _chip('Feature Plan', _capitalize(profile.featurePlan)),
                _chip(
                  'Feature Daycare',
                  profile.featureDaycare ? 'True' : 'False',
                ),
                _chip(
                  'Verification Status',
                  _capitalize(profile.verificationStatus),
                ),
                _chip('Dealer Code', profile.dealerCode),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _consumeRequestedAction() {
    final action = widget.requestedAction;
    if (action == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      switch (action) {
        case TenantProfileAction.addParent:
          await _showAddParentDialog();
          break;
        case TenantProfileAction.addChild:
          final parents = await _repo.getParents(widget.membership.tenantId);
          if (!mounted) return;
          await _showAddChildDialog(parents);
          break;
        case TenantProfileAction.addHouseholdMember:
          await _showAddHouseholdMemberDialog();
          break;
      }
      if (!mounted) return;
      widget.onActionHandled?.call();
    });
  }

  Widget _buildChildrenSection() {
    return StreamBuilder<List<ParentAccount>>(
      stream: _repo.watchParents(widget.membership.tenantId),
      builder: (context, parentSnapshot) {
        final parents = parentSnapshot.data ?? const <ParentAccount>[];
        return StreamBuilder<List<ChildRecord>>(
          stream: _repo.watchChildren(widget.membership.tenantId),
          builder: (context, childSnapshot) {
            final children = childSnapshot.data ?? const <ChildRecord>[];
            final parentById = {
              for (final parent in parents) parent.id: parent,
            };

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Children',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (children.isEmpty)
                      const Text('No children added yet.')
                    else
                      ...children.map(
                        (child) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.child_friendly_outlined),
                          title: Text(
                            child.fullName.isEmpty ? '-' : child.fullName,
                          ),
                          subtitle: Text(
                            'Parent: ${parentById[child.parentId]?.fullName ?? 'Unassigned'}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildParentFormsSection() {
    return StreamBuilder<List<ParentAccount>>(
      stream: _repo.watchParents(widget.membership.tenantId),
      builder: (context, parentSnapshot) {
        final parents = parentSnapshot.data ?? const <ParentAccount>[];
        return StreamBuilder<List<ChildRecord>>(
          stream: _repo.watchChildren(widget.membership.tenantId),
          builder: (context, childSnapshot) {
            final children = childSnapshot.data ?? const <ChildRecord>[];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signed Parent Documents',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'View and print the daycare contract and each child photo permission signed by the parent.',
                    ),
                    const SizedBox(height: 12),
                    if (parents.isEmpty)
                      const Text('No parent records found yet.')
                    else
                      ...parents.map((parent) {
                        final linkedChildren = children
                            .where((child) => child.parentId == parent.id)
                            .toList();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FBFF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFD8E2EC)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parent.fullName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (parent.email.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  parent.email,
                                  style: const TextStyle(
                                    color: Color(0xFF63748A),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              _DocumentActionRow(
                                title: 'Daycare Contract',
                                subtitle:
                                    'Parent agreement and saved signature',
                                onView: () =>
                                    _openContractPdfPreview(parent: parent),
                              ),
                              if (linkedChildren.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                ...linkedChildren.map(
                                  (child) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _DocumentActionRow(
                                      title:
                                          '${child.fullName.isEmpty ? 'Child' : child.fullName} Photo Permission',
                                      subtitle:
                                          'Signed photo sharing form for this child',
                                      onView: () =>
                                          _openPhotoPermissionPdfPreview(
                                            parent: parent,
                                            child: child,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openContractPdfPreview({required ParentAccount parent}) async {
    final payload = await _repo.loadParentContractDocument(
      tenantId: widget.membership.tenantId,
      parentId: parent.id,
    );
    final contract =
        (payload['parentContract'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final signaturePoints =
        (contract['signaturePoints'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    await _showPdfPreview(
      title: '${parent.fullName} Daycare Contract',
      build: () => FormPdfBuilder.buildContractPdf(
        parentName: parent.fullName,
        parentEmail: parent.email,
        parentPhone: parent.phone,
        parentAddress: [
          parent.addressLine1,
          parent.city,
          parent.state,
          parent.zip,
        ].where((part) => part.trim().isNotEmpty).join(', '),
        signedName: (contract['signedName'] ?? '').toString(),
        signed: contract['accepted'] == true,
        signedAt: _asDateTime(contract['signedAt']),
        signaturePoints: signaturePoints,
      ),
    );
  }

  Future<void> _openPhotoPermissionPdfPreview({
    required ParentAccount parent,
    required ChildRecord child,
  }) async {
    final payload = await _repo.loadPhotoPermissionDocument(
      tenantId: widget.membership.tenantId,
      childId: child.id,
      parentId: parent.id,
    );
    final signaturePoints =
        (payload['signaturePoints'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    await _showPdfPreview(
      title: '${child.fullName} Photo Permission',
      build: () => FormPdfBuilder.buildPhotoPermissionPdf(
        parentName: parent.fullName,
        parentEmail: parent.email,
        parentPhone: parent.phone,
        parentAddress: [
          parent.addressLine1,
          parent.city,
          parent.state,
          parent.zip,
        ].where((part) => part.trim().isNotEmpty).join(', '),
        childName: child.fullName.isEmpty ? 'Child' : child.fullName,
        signedName: (payload['signedName'] ?? '').toString(),
        signed: payload['consentGranted'] == true,
        signedAt: _asDateTime(payload['signedAt']),
        signaturePoints: signaturePoints,
      ),
    );
  }

  Future<void> _showPdfPreview({
    required String title,
    required Future<List<int>> Function() build,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: SizedBox(
            width: 920,
            height: 760,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: PdfPreview(
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    allowPrinting: true,
                    allowSharing: true,
                    build: (format) async => Uint8List.fromList(await build()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  Future<void> _showAddParentDialog() async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Parent'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Login Email',
                        ),
                        validator: (value) =>
                            (value == null || !value.contains('@'))
                            ? 'Valid email required'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Login Password',
                        ),
                        validator: (value) =>
                            (value == null || value.length < 6)
                            ? 'Minimum 6 characters'
                            : null,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });

                          try {
                            final authUid = await _authService
                                .createParentAuthUser(
                                  email: emailController.text,
                                  password: passwordController.text,
                                );

                            await _repo.createParent(
                              tenantId: widget.membership.tenantId,
                              uid: widget.uid,
                              firstName: firstNameController.text,
                              lastName: lastNameController.text,
                              email: emailController.text,
                              authUid: authUid,
                            );

                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          } on FirebaseAuthException catch (e) {
                            setDialogState(() {
                              error = 'Auth error: ${e.code}';
                              saving = false;
                            });
                          } catch (_) {
                            setDialogState(() {
                              error = 'Could not add parent. Please try again.';
                              saving = false;
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Parent'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddChildDialog(List<ParentAccount> parents) async {
    if (parents.isEmpty) {
      _showMessage('Add a parent first before creating a child.');
      return;
    }

    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedParentId = parents.first.id;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Child'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedParentId,
                        decoration: const InputDecoration(labelText: 'Parent'),
                        items: parents
                            .map(
                              (parent) => DropdownMenuItem(
                                value: parent.id,
                                child: Text(parent.fullName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedParentId = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => saving = true);
                          try {
                            await _repo.createChild(
                              tenantId: widget.membership.tenantId,
                              uid: widget.uid,
                              firstName: firstNameController.text,
                              lastName: lastNameController.text,
                              parentId: selectedParentId,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          } on StateError catch (e) {
                            if (!context.mounted) return;
                            setDialogState(() => saving = false);
                            _showMessage(e.message);
                          } catch (_) {
                            if (!context.mounted) return;
                            setDialogState(() => saving = false);
                            _showMessage('Could not add child.');
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Child'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddHouseholdMemberDialog() async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime? physicalIssued;
    DateTime? physicalExpires;
    DateTime? fingerprintIssued;
    DateTime? fingerprintExpires;
    Uint8List? physicalPhotoBytes;
    String? physicalPhotoName;
    String? physicalPhotoType;
    Uint8List? fingerprintPhotoBytes;
    String? fingerprintPhotoName;
    String? fingerprintPhotoType;
    var saving = false;

    Future<void> pickDate(
      void Function(DateTime?) setValue,
      DateTime? current,
    ) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: current ?? now,
        firstDate: DateTime(now.year - 10),
        lastDate: DateTime(now.year + 20),
      );
      if (picked != null) {
        setValue(picked);
      }
    }

    Future<void> pickUpload(
      void Function(Uint8List, String, String) onReady,
    ) async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = result?.files.singleOrNull;
      if (file == null || file.bytes == null) return;
      onReady(
        file.bytes!,
        file.name,
        file.extension == 'png' ? 'image/png' : 'image/jpeg',
      );
    }

    Future<void> takePhoto(
      void Function(Uint8List, String, String) onReady,
    ) async {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo == null) return;
      onReady(
        await photo.readAsBytes(),
        photo.name,
        photo.mimeType ?? 'image/jpeg',
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 860,
                  maxHeight: 720,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Household Member',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: firstNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'First Name',
                                  ),
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: lastNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Last Name',
                                  ),
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _HouseholdDocumentEditor(
                            title: 'Physical Exam',
                            issuedAt: physicalIssued,
                            expiresAt: physicalExpires,
                            fileName: physicalPhotoName,
                            onIssuedTap: () => pickDate(
                              (picked) =>
                                  setDialogState(() => physicalIssued = picked),
                              physicalIssued,
                            ),
                            onExpiresTap: () => pickDate(
                              (picked) => setDialogState(
                                () => physicalExpires = picked,
                              ),
                              physicalExpires,
                            ),
                            onUploadTap: () async {
                              await pickUpload((bytes, name, type) {
                                setDialogState(() {
                                  physicalPhotoBytes = bytes;
                                  physicalPhotoName = name;
                                  physicalPhotoType = type;
                                });
                              });
                            },
                            onCameraTap: () async {
                              await takePhoto((bytes, name, type) {
                                setDialogState(() {
                                  physicalPhotoBytes = bytes;
                                  physicalPhotoName = name;
                                  physicalPhotoType = type;
                                });
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _HouseholdDocumentEditor(
                            title: 'Fingerprint',
                            issuedAt: fingerprintIssued,
                            expiresAt: fingerprintExpires,
                            fileName: fingerprintPhotoName,
                            onIssuedTap: () => pickDate(
                              (picked) => setDialogState(
                                () => fingerprintIssued = picked,
                              ),
                              fingerprintIssued,
                            ),
                            onExpiresTap: () => pickDate(
                              (picked) => setDialogState(
                                () => fingerprintExpires = picked,
                              ),
                              fingerprintExpires,
                            ),
                            onUploadTap: () async {
                              await pickUpload((bytes, name, type) {
                                setDialogState(() {
                                  fingerprintPhotoBytes = bytes;
                                  fingerprintPhotoName = name;
                                  fingerprintPhotoType = type;
                                });
                              });
                            },
                            onCameraTap: () async {
                              await takePhoto((bytes, name, type) {
                                setDialogState(() {
                                  fingerprintPhotoBytes = bytes;
                                  fingerprintPhotoName = name;
                                  fingerprintPhotoType = type;
                                });
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) {
                                          return;
                                        }
                                        setDialogState(() => saving = true);
                                        try {
                                          final householdMemberId = _repo
                                              .newHouseholdMemberId(
                                                widget.membership.tenantId,
                                              );
                                          String physicalExamPhotoUrl = '';
                                          if (physicalPhotoBytes != null &&
                                              physicalPhotoName != null) {
                                            final upload = await _repo
                                                .uploadHouseholdDocumentPhoto(
                                                  tenantId: widget
                                                      .membership
                                                      .tenantId,
                                                  householdMemberId:
                                                      householdMemberId,
                                                  documentKey: 'physical_exam',
                                                  fileName: physicalPhotoName!,
                                                  bytes: physicalPhotoBytes!,
                                                  contentType:
                                                      physicalPhotoType,
                                                );
                                            physicalExamPhotoUrl = upload.url;
                                          }
                                          String fingerprintPhotoUrl = '';
                                          if (fingerprintPhotoBytes != null &&
                                              fingerprintPhotoName != null) {
                                            final upload = await _repo
                                                .uploadHouseholdDocumentPhoto(
                                                  tenantId: widget
                                                      .membership
                                                      .tenantId,
                                                  householdMemberId:
                                                      householdMemberId,
                                                  documentKey: 'fingerprint',
                                                  fileName:
                                                      fingerprintPhotoName!,
                                                  bytes: fingerprintPhotoBytes!,
                                                  contentType:
                                                      fingerprintPhotoType,
                                                );
                                            fingerprintPhotoUrl = upload.url;
                                          }
                                          await _repo.createHouseholdMember(
                                            tenantId:
                                                widget.membership.tenantId,
                                            uid: widget.uid,
                                            householdMemberId:
                                                householdMemberId,
                                            firstName: firstNameController.text,
                                            lastName: lastNameController.text,
                                            physicalExamIssuedAt:
                                                physicalIssued,
                                            physicalExamExpiresAt:
                                                physicalExpires,
                                            fingerprintIssuedAt:
                                                fingerprintIssued,
                                            fingerprintExpiresAt:
                                                fingerprintExpires,
                                            physicalExamPhotoUrl:
                                                physicalExamPhotoUrl,
                                            fingerprintPhotoUrl:
                                                fingerprintPhotoUrl,
                                          );
                                          if (!context.mounted) return;
                                          Navigator.of(context).pop();
                                        } catch (_) {
                                          if (!context.mounted) return;
                                          setDialogState(() => saving = false);
                                          _showMessage(
                                            'Could not add household member.',
                                          );
                                        }
                                      },
                                child: saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save Member'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _chip(String label, String value) {
    final safe = value.trim().isEmpty ? '-' : value.trim();
    return Chip(label: Text('$label: $safe'));
  }

  String _capitalize(String value) {
    final cleaned = value.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return '-';
    return cleaned
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}

class _DocumentActionRow extends StatelessWidget {
  const _DocumentActionRow({
    required this.title,
    required this.subtitle,
    required this.onView,
  });

  final String title;
  final String subtitle;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3D4A59),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF63748A)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonalIcon(
            onPressed: onView,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('View / Print'),
          ),
        ],
      ),
    );
  }
}

class _DateButtonField extends StatelessWidget {
  const _DateButtonField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MM/dd/yyyy');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value == null ? 'Select date' : dateFormat.format(value!)),
      ),
    );
  }
}

class _HouseholdDocumentEditor extends StatelessWidget {
  const _HouseholdDocumentEditor({
    required this.title,
    required this.issuedAt,
    required this.expiresAt,
    required this.fileName,
    required this.onIssuedTap,
    required this.onExpiresTap,
    required this.onUploadTap,
    required this.onCameraTap,
  });

  final String title;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String? fileName;
  final VoidCallback onIssuedTap;
  final VoidCallback onExpiresTap;
  final VoidCallback onUploadTap;
  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateButtonField(
                  label: 'Submitted',
                  value: issuedAt,
                  onTap: onIssuedTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateButtonField(
                  label: 'Expires',
                  value: expiresAt,
                  onTap: onExpiresTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onUploadTap,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload Photo'),
              ),
              OutlinedButton.icon(
                onPressed: onCameraTap,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take Photo'),
              ),
              if (fileName != null && fileName!.trim().isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.image_outlined, size: 18),
                  label: Text(fileName!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
