import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/family_records.dart';
import '../../models/tenant_membership.dart';
import '../../services/tenant_repository.dart';

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({
    super.key,
    required this.uid,
    required this.membership,
  });

  final String uid;
  final TenantMembership membership;

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  final _repo = const TenantRepository();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildHero(),
            const SizedBox(height: 16),
            _buildIntroCard(),
            const SizedBox(height: 16),
            StreamBuilder<List<StaffMemberRecord>>(
              stream: _repo.watchStaffMembers(widget.membership.tenantId),
              builder: (context, snapshot) {
                final staff = snapshot.data ?? const <StaffMemberRecord>[];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Staff Records',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _openAddStaffDialog,
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Add Staff'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (staff.isEmpty)
                          const Text('No staff records added yet.')
                        else
                          ...staff.map(
                            (member) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _StaffCard(member: member),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8DDE5), Color(0xFFD8EBFF), Color(0xFFF8F1C9)],
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
              child: Center(child: Icon(Icons.badge_outlined, size: 30)),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STAFF MANAGEMENT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Color(0xFF667085),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Licenses, compliance, and document tracking',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Role Rules',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 10),
            Text(
              'Substitute: Cannot be by herself with children. Either Provider (daycare owner) or Assistant has to be with her.',
            ),
            SizedBox(height: 6),
            Text('Provider: Can be alone with children.'),
            SizedBox(height: 6),
            Text('Assistant: Can be alone with children.'),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddStaffDialog() async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final docs = {
      'backgroundCheck': _EditableStaffDocument(label: 'Background Check'),
      'physical': _EditableStaffDocument(label: 'Physical'),
      'drugAdministrationLicense': _EditableStaffDocument(
        label: 'Drug Administration License',
      ),
      'cpr': _EditableStaffDocument(label: 'CPR'),
    };
    var selectedRole = 'Provider';
    DateTime? dateOfBirth;
    var saving = false;
    String? error;

    Future<void> pickDate(
      DateTime? current,
      void Function(DateTime?) onSelected,
    ) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: current ?? now,
        firstDate: DateTime(now.year - 80),
        lastDate: DateTime(now.year + 20),
      );
      if (picked != null) {
        onSelected(picked);
      }
    }

    Future<void> pickUpload(_EditableStaffDocument doc) async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = result?.files.singleOrNull;
      if (file == null || file.bytes == null) return;
      doc.fileBytes = file.bytes;
      doc.fileName = file.name;
      doc.contentType = file.extension == 'png' ? 'image/png' : 'image/jpeg';
    }

    Future<void> takePhoto(_EditableStaffDocument doc) async {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo == null) return;
      doc.fileBytes = await photo.readAsBytes();
      doc.fileName = photo.name;
      doc.contentType = photo.mimeType ?? 'image/jpeg';
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
                  maxHeight: 760,
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
                            'Add Staff Member',
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedRole,
                                  decoration: const InputDecoration(
                                    labelText: 'Daycare License Role',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Substitute',
                                      child: Text('Substitute'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Provider',
                                      child: Text('Provider'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Assistant',
                                      child: Text('Assistant'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setDialogState(() => selectedRole = value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _DateButtonField(
                                  label: 'DOB',
                                  value: dateOfBirth,
                                  onTap: () => pickDate(
                                    dateOfBirth,
                                    (picked) => setDialogState(
                                      () => dateOfBirth = picked,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ...docs.values.map(
                            (doc) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _StaffDocumentEditor(
                                document: doc,
                                onSubmittedTap: () => pickDate(
                                  doc.submittedAt,
                                  (picked) => setDialogState(
                                    () => doc.submittedAt = picked,
                                  ),
                                ),
                                onExpiresTap: () => pickDate(
                                  doc.expiresAt,
                                  (picked) => setDialogState(
                                    () => doc.expiresAt = picked,
                                  ),
                                ),
                                onUploadTap: () async {
                                  await pickUpload(doc);
                                  if (!context.mounted) return;
                                  setDialogState(() {});
                                },
                                onCameraTap: () async {
                                  await takePhoto(doc);
                                  if (!context.mounted) return;
                                  setDialogState(() {});
                                },
                              ),
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
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
                                        setDialogState(() {
                                          saving = true;
                                          error = null;
                                        });
                                        try {
                                          final staffId = _repo.newStaffId(
                                            widget.membership.tenantId,
                                          );
                                          final backgroundCheck =
                                              await _uploadDocIfNeeded(
                                                staffId,
                                                'background_check',
                                                docs['backgroundCheck']!,
                                              );
                                          final physical =
                                              await _uploadDocIfNeeded(
                                                staffId,
                                                'physical',
                                                docs['physical']!,
                                              );
                                          final drugAdmin =
                                              await _uploadDocIfNeeded(
                                                staffId,
                                                'drug_administration_license',
                                                docs['drugAdministrationLicense']!,
                                              );
                                          final cpr = await _uploadDocIfNeeded(
                                            staffId,
                                            'cpr',
                                            docs['cpr']!,
                                          );

                                          await _repo.createStaffMember(
                                            tenantId:
                                                widget.membership.tenantId,
                                            uid: widget.uid,
                                            staffId: staffId,
                                            firstName: firstNameController.text,
                                            lastName: lastNameController.text,
                                            dateOfBirth: dateOfBirth,
                                            daycareLicenseRole: selectedRole,
                                            roleNotes: _roleNotesFor(
                                              selectedRole,
                                            ),
                                            backgroundCheck: _docPayload(
                                              docs['backgroundCheck']!,
                                              backgroundCheck,
                                            ),
                                            physical: _docPayload(
                                              docs['physical']!,
                                              physical,
                                            ),
                                            drugAdministrationLicense: _docPayload(
                                              docs['drugAdministrationLicense']!,
                                              drugAdmin,
                                            ),
                                            cpr: _docPayload(docs['cpr']!, cpr),
                                          );
                                          if (!context.mounted) return;
                                          Navigator.of(context).pop();
                                        } catch (_) {
                                          setDialogState(() {
                                            saving = false;
                                            error =
                                                'Could not save staff member. Check file upload and try again.';
                                          });
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
                                    : const Text('Save Staff'),
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

  Future<UploadedStaffPhoto?> _uploadDocIfNeeded(
    String staffId,
    String documentKey,
    _EditableStaffDocument doc,
  ) async {
    if (doc.fileBytes == null || doc.fileName == null) return null;
    return _repo.uploadStaffDocumentPhoto(
      tenantId: widget.membership.tenantId,
      staffId: staffId,
      documentKey: documentKey,
      fileName: doc.fileName!,
      bytes: doc.fileBytes!,
      contentType: doc.contentType,
    );
  }

  Map<String, dynamic> _docPayload(
    _EditableStaffDocument doc,
    UploadedStaffPhoto? upload,
  ) {
    return {
      'submittedAt': doc.submittedAt,
      'expiresAt': doc.expiresAt,
      'photoUrl': upload?.url ?? '',
      'photoPath': upload?.path ?? '',
      'photoName': upload?.fileName ?? '',
    };
  }

  String _roleNotesFor(String role) {
    switch (role) {
      case 'Substitute':
        return 'Cannot be by herself with children. Either Provider (daycare owner) or Assistant has to be with her.';
      case 'Assistant':
        return 'Can be alone with children.';
      case 'Provider':
      default:
        return 'Can be alone with children.';
    }
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member});

  final StaffMemberRecord member;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName.isEmpty ? '-' : member.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.daycareLicenseRole,
                      style: const TextStyle(
                        color: Color(0xFF2B6E6A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(
                  'DOB: ${member.dateOfBirth == null ? '-' : dateFormat.format(member.dateOfBirth!)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(member.roleNotes),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StaffDocChip(label: 'Background', doc: member.backgroundCheck),
              _StaffDocChip(label: 'Physical', doc: member.physical),
              _StaffDocChip(
                label: 'Drug Admin',
                doc: member.drugAdministrationLicense,
              ),
              _StaffDocChip(label: 'CPR', doc: member.cpr),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffDocChip extends StatelessWidget {
  const _StaffDocChip({required this.label, required this.doc});

  final String label;
  final StaffDocumentRecord doc;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MM/dd/yyyy');
    return Container(
      width: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Submitted: ${doc.submittedAt == null ? '-' : dateFormat.format(doc.submittedAt!)}',
          ),
          Text(
            'Expires: ${doc.expiresAt == null ? '-' : dateFormat.format(doc.expiresAt!)}',
          ),
          const SizedBox(height: 6),
          Text(
            doc.hasPhoto ? 'Photo attached' : 'No photo',
            style: TextStyle(
              color: doc.hasPhoto
                  ? const Color(0xFF2F9965)
                  : const Color(0xFF8A5B00),
              fontWeight: FontWeight.w700,
            ),
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

class _StaffDocumentEditor extends StatelessWidget {
  const _StaffDocumentEditor({
    required this.document,
    required this.onSubmittedTap,
    required this.onExpiresTap,
    required this.onUploadTap,
    required this.onCameraTap,
  });

  final _EditableStaffDocument document;
  final VoidCallback onSubmittedTap;
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
            document.label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateButtonField(
                  label: 'Submitted',
                  value: document.submittedAt,
                  onTap: onSubmittedTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateButtonField(
                  label: 'Expires',
                  value: document.expiresAt,
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
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Photo'),
              ),
              OutlinedButton.icon(
                onPressed: onCameraTap,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take Photo'),
              ),
              if (document.fileName != null)
                Chip(label: Text(document.fileName!)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableStaffDocument {
  _EditableStaffDocument({required this.label});

  final String label;
  DateTime? submittedAt;
  DateTime? expiresAt;
  Uint8List? fileBytes;
  String? fileName;
  String? contentType;
}
