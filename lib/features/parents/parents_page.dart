import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../form_document_pdf.dart';
import '../../models/family_records.dart';
import '../../models/tenant_membership.dart';
import '../../services/auth_service.dart';
import '../../services/tenant_repository.dart';

class ParentsPage extends StatefulWidget {
  const ParentsPage({super.key, required this.uid, required this.membership});

  final String uid;
  final TenantMembership membership;

  @override
  State<ParentsPage> createState() => _ParentsPageState();
}

class _ParentsPageState extends State<ParentsPage> {
  final _repo = const TenantRepository();
  final _authService = const AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ParentAccount>>(
      stream: _repo.watchParents(widget.membership.tenantId),
      builder: (context, parentSnapshot) {
        final parents = parentSnapshot.data ?? const <ParentAccount>[];
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildHero(),
                const SizedBox(height: 16),
                _buildParentListCard(parents: parents),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD8EBFF), Color(0xFFF8DDE5), Color(0xFFDFF5E6)],
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
              child: Center(child: Icon(Icons.family_restroom, size: 30)),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PARENTS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Color(0xFF667085),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Manage parents and their children',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Select a parent to view linked children and add a new child record.',
                  style: TextStyle(color: Color(0xFF5E6D79)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentListCard({required List<ParentAccount> parents}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        'Parents',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Click a parent name to open the family record.',
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _showAddParentDialog,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add Parent'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (parents.isEmpty)
              const Text('No parent records found yet.')
            else
              ...parents.map(
                (parent) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ParentListTile(
                    parent: parent,
                    onTap: () => _openParentDetail(parent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openParentDetail(ParentAccount parent) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _ParentDetailPage(
          tenantId: widget.membership.tenantId,
          parent: parent,
          onAddChild: () => _showAddChildDialog(parent: parent),
          onOpenParentForms: () => _openParentForms(parent),
          onAddAuthorizedPickup: () => _showAddAuthorizedPickupDialog(parent),
          onAddEmergencyContact: () => _showAddEmergencyContactDialog(parent),
          onEditParent: () => _requestParentPasswordGate(
            title: 'Edit Parent',
            message:
                'Do you want to edit this parent? Enter your login password to continue.',
            onApproved: () => _showEditParentDialog(parent),
          ),
          onDeleteParent: () => _requestParentPasswordGate(
            title: 'Delete Parent',
            message:
                'Do you want to delete this parent? Enter your login password to continue.',
            onApproved: () => _confirmDeleteParent(parent),
          ),
          onEditAuthorizedPickup: (index, contact) =>
              _showEditAuthorizedPickupDialog(parent, index, contact),
          onDeleteAuthorizedPickup: (index) =>
              _deleteAuthorizedPickup(parent, index),
          onEditEmergencyContact: (index, contact) =>
              _showEditEmergencyContactDialog(parent, index, contact),
          onDeleteEmergencyContact: (index) =>
              _deleteEmergencyContact(parent, index),
          onEditChild: (child) => _showEditChildDialog(child),
          onDeleteChild: (child) => _confirmDeleteChild(child),
        ),
      ),
    );
  }

  Future<void> _openParentForms(ParentAccount parent) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _ParentFormsPage(
          tenantId: widget.membership.tenantId,
          parent: parent,
        ),
      ),
    );
  }

  Future<void> _requestParentPasswordGate({
    required String title,
    required String message,
    required Future<void> Function() onApproved,
  }) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var checking = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Your Login Password',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
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
                  onPressed: checking
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: checking
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            checking = true;
                            error = null;
                          });
                          try {
                            await _authService.confirmCurrentUserPassword(
                              password: passwordController.text.trim(),
                            );
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await onApproved();
                          } on FirebaseAuthException catch (e) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              checking = false;
                              error =
                                  e.code == 'wrong-password' ||
                                      e.code == 'invalid-credential'
                                  ? 'Incorrect password.'
                                  : 'Could not verify password.';
                            });
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              checking = false;
                              error = 'Could not verify password.';
                            });
                          }
                        },
                  child: checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
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
                        validator: (value) => _required(value),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                        ),
                        validator: (value) => _required(value),
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

  Future<void> _showAddChildDialog({required ParentAccount parent}) async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime? dateOfBirth;
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Parent: ${parent.fullName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                        ),
                        validator: (value) => _required(value),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                        ),
                        validator: (value) => _required(value),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      dateOfBirth ??
                                      DateTime(
                                        now.year - 3,
                                        now.month,
                                        now.day,
                                      ),
                                  firstDate: DateTime(now.year - 18),
                                  lastDate: now,
                                );
                                if (picked != null) {
                                  setDialogState(() => dateOfBirth = picked);
                                }
                              },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          dateOfBirth == null
                              ? 'Select Date of Birth'
                              : _formatDate(dateOfBirth!),
                        ),
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
                          if (dateOfBirth == null) {
                            _showMessage('Select the date of birth.');
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            await _repo.createChild(
                              tenantId: widget.membership.tenantId,
                              uid: widget.uid,
                              firstName: firstNameController.text,
                              lastName: lastNameController.text,
                              parentId: parent.id,
                              dateOfBirth: dateOfBirth,
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

  Future<void> _showEditParentDialog(ParentAccount parent) async {
    final firstNameController = TextEditingController(text: parent.firstName);
    final lastNameController = TextEditingController(text: parent.lastName);
    final emailController = TextEditingController(text: parent.email);
    final phoneController = TextEditingController(text: parent.phone);
    final addressController = TextEditingController(text: parent.addressLine1);
    final cityController = TextEditingController(text: parent.city);
    final stateController = TextEditingController(text: parent.state);
    final zipController = TextEditingController(text: parent.zip);
    final formKey = GlobalKey<FormState>();
    final emergencyContacts = parent.emergencyContacts.isNotEmpty
        ? parent.emergencyContacts
              .map(
                (contact) => _EditableFamilyContact(
                  name: contact.name,
                  phone: contact.phone,
                ),
              )
              .toList()
        : [
            _EditableFamilyContact(
              name: parent.emergencyContactName,
              phone: parent.emergencyContactPhone,
            ),
          ];
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Parent'),
              content: SizedBox(
                width: 460,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                          ),
                          validator: (value) => _required(value),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                          ),
                          validator: (value) => _required(value),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) =>
                              (value == null || !value.contains('@'))
                              ? 'Valid email required'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: cityController,
                          decoration: const InputDecoration(labelText: 'City'),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: stateController,
                          decoration: const InputDecoration(labelText: 'State'),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: zipController,
                          decoration: const InputDecoration(labelText: 'ZIP'),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Emergency Contacts',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => setDialogState(
                                () => emergencyContacts.add(
                                  _EditableFamilyContact(),
                                ),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Contact'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...emergencyContacts.asMap().entries.map((entry) {
                          final index = entry.key;
                          final contact = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _FamilyContactEditor(
                              title: 'Emergency Contact ${index + 1}',
                              contact: contact,
                              showRelation: false,
                              onRemove: emergencyContacts.length <= 1
                                  ? null
                                  : () => setDialogState(
                                      () => emergencyContacts.removeAt(index),
                                    ),
                            ),
                          );
                        }),
                      ],
                    ),
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
                            final cleanedEmergencyContacts = emergencyContacts
                                .map((contact) => contact.toMap())
                                .where(
                                  (contact) =>
                                      (contact['name'] ?? '')
                                          .trim()
                                          .isNotEmpty ||
                                      (contact['phone'] ?? '')
                                          .trim()
                                          .isNotEmpty,
                                )
                                .toList();
                            await _repo.updateParent(
                              tenantId: widget.membership.tenantId,
                              parentId: parent.id,
                              uid: widget.uid,
                              firstName: firstNameController.text,
                              lastName: lastNameController.text,
                              email: emailController.text,
                              phone: phoneController.text,
                              addressLine1: addressController.text,
                              city: cityController.text,
                              state: stateController.text,
                              zip: zipController.text,
                              emergencyContactName:
                                  cleanedEmergencyContacts.isEmpty
                                  ? ''
                                  : (cleanedEmergencyContacts.first['name'] ??
                                        ''),
                              emergencyContactPhone:
                                  cleanedEmergencyContacts.isEmpty
                                  ? ''
                                  : (cleanedEmergencyContacts.first['phone'] ??
                                        ''),
                              emergencyContacts: cleanedEmergencyContacts,
                              authorizedPickupContacts: parent
                                  .authorizedPickupContacts
                                  .map(
                                    (contact) => {
                                      'name': contact.name,
                                      'phone': contact.phone,
                                      'relation': contact.relation,
                                    },
                                  )
                                  .toList(),
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          } catch (_) {
                            if (!context.mounted) return;
                            setDialogState(() => saving = false);
                            _showMessage('Could not update parent.');
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditChildDialog(ChildRecord child) async {
    final firstNameController = TextEditingController(text: child.firstName);
    final lastNameController = TextEditingController(text: child.lastName);
    final formKey = GlobalKey<FormState>();
    DateTime? dateOfBirth = child.dateOfBirth;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Child'),
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
                        validator: (value) => _required(value),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                        ),
                        validator: (value) => _required(value),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      dateOfBirth ??
                                      DateTime(
                                        now.year - 3,
                                        now.month,
                                        now.day,
                                      ),
                                  firstDate: DateTime(now.year - 18),
                                  lastDate: now,
                                );
                                if (picked != null) {
                                  setDialogState(() => dateOfBirth = picked);
                                }
                              },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          dateOfBirth == null
                              ? 'Select Date of Birth'
                              : _formatDate(dateOfBirth!),
                        ),
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
                          if (dateOfBirth == null) {
                            _showMessage('Select the date of birth.');
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            await _repo.updateChild(
                              tenantId: widget.membership.tenantId,
                              childId: child.id,
                              uid: widget.uid,
                              firstName: firstNameController.text,
                              lastName: lastNameController.text,
                              dateOfBirth: dateOfBirth,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          } catch (_) {
                            if (!context.mounted) return;
                            setDialogState(() => saving = false);
                            _showMessage('Could not update child.');
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteParent(ParentAccount parent) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Parent'),
        content: Text('Delete ${parent.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _repo.deleteParent(
        tenantId: widget.membership.tenantId,
        parentId: parent.id,
      );
      if (!mounted) return;
      Navigator.of(context).maybePop();
      _showMessage('Parent deleted.');
    } on StateError catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not delete parent.');
    }
  }

  Future<void> _confirmDeleteChild(ChildRecord child) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Child'),
        content: Text('Delete ${child.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _repo.deleteChild(
        tenantId: widget.membership.tenantId,
        childId: child.id,
      );
      _showMessage('Child deleted.');
    } catch (_) {
      _showMessage('Could not delete child.');
    }
  }

  Future<void> _showAddAuthorizedPickupDialog(ParentAccount parent) async {
    final nameController = TextEditingController();
    final relationController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Authorized Pickup'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => _required(value),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: relationController,
                        decoration: const InputDecoration(
                          labelText: 'Relation',
                        ),
                        validator: (value) => _required(value),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
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
                            final updatedContacts = [
                              ...parent.authorizedPickupContacts.map(
                                (contact) => {
                                  'name': contact.name,
                                  'phone': contact.phone,
                                  'relation': contact.relation,
                                },
                              ),
                              {
                                'name': nameController.text.trim(),
                                'phone': phoneController.text.trim(),
                                'relation': relationController.text.trim(),
                              },
                            ];
                            await _repo.addAuthorizedPickupContact(
                              tenantId: widget.membership.tenantId,
                              parentId: parent.id,
                              uid: widget.uid,
                              authorizedPickupContacts: updatedContacts,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          } catch (_) {
                            if (!context.mounted) return;
                            setDialogState(() => saving = false);
                            _showMessage(
                              'Could not add authorized pickup contact.',
                            );
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddEmergencyContactDialog(ParentAccount parent) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Emergency Contact'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => _required(value),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
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
                            final updatedContacts = [
                              ...parent.emergencyContacts.map(
                                (contact) => {
                                  'name': contact.name,
                                  'phone': contact.phone,
                                  'relation': contact.relation,
                                },
                              ),
                              {
                                'name': nameController.text.trim(),
                                'phone': phoneController.text.trim(),
                                'relation': '',
                              },
                            ];
                            await _repo.saveEmergencyContacts(
                              tenantId: widget.membership.tenantId,
                              parentId: parent.id,
                              uid: widget.uid,
                              emergencyContacts: updatedContacts,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          } catch (_) {
                            if (!context.mounted) return;
                            setDialogState(() => saving = false);
                            _showMessage('Could not add emergency contact.');
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditEmergencyContactDialog(
    ParentAccount parent,
    int index,
    FamilyContactRecord contact,
  ) async {
    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phone);
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Emergency Contact'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => _required(value),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
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
                            final updated = parent.emergencyContacts
                                .map(
                                  (item) => {
                                    'name': item.name,
                                    'phone': item.phone,
                                    'relation': item.relation,
                                  },
                                )
                                .toList();
                            updated[index] = {
                              'name': nameController.text.trim(),
                              'phone': phoneController.text.trim(),
                              'relation': '',
                            };
                            await _repo.saveEmergencyContacts(
                              tenantId: widget.membership.tenantId,
                              parentId: parent.id,
                              uid: widget.uid,
                              emergencyContacts: updated,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          } catch (_) {
                            if (!context.mounted) return;
                            setDialogState(() => saving = false);
                            _showMessage('Could not update emergency contact.');
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEmergencyContact(ParentAccount parent, int index) async {
    final updated =
        parent.emergencyContacts
            .map(
              (item) => {
                'name': item.name,
                'phone': item.phone,
                'relation': item.relation,
              },
            )
            .toList()
          ..removeAt(index);
    await _repo.saveEmergencyContacts(
      tenantId: widget.membership.tenantId,
      parentId: parent.id,
      uid: widget.uid,
      emergencyContacts: updated,
    );
  }

  Future<void> _showEditAuthorizedPickupDialog(
    ParentAccount parent,
    int index,
    FamilyContactRecord contact,
  ) async {
    final nameController = TextEditingController(text: contact.name);
    final relationController = TextEditingController(text: contact.relation);
    final phoneController = TextEditingController(text: contact.phone);
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Authorized Pickup'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => _required(value),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: relationController,
                        decoration: const InputDecoration(
                          labelText: 'Relation',
                        ),
                        validator: (value) => _required(value),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
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
                            final updated = parent.authorizedPickupContacts
                                .map(
                                  (item) => {
                                    'name': item.name,
                                    'phone': item.phone,
                                    'relation': item.relation,
                                  },
                                )
                                .toList();
                            updated[index] = {
                              'name': nameController.text.trim(),
                              'phone': phoneController.text.trim(),
                              'relation': relationController.text.trim(),
                            };
                            await _repo.addAuthorizedPickupContact(
                              tenantId: widget.membership.tenantId,
                              parentId: parent.id,
                              uid: widget.uid,
                              authorizedPickupContacts: updated,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          } catch (_) {
                            if (!context.mounted) return;
                            setDialogState(() => saving = false);
                            _showMessage(
                              'Could not update authorized pickup contact.',
                            );
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAuthorizedPickup(ParentAccount parent, int index) async {
    final updated =
        parent.authorizedPickupContacts
            .map(
              (item) => {
                'name': item.name,
                'phone': item.phone,
                'relation': item.relation,
              },
            )
            .toList()
          ..removeAt(index);
    await _repo.addAuthorizedPickupContact(
      tenantId: widget.membership.tenantId,
      parentId: parent.id,
      uid: widget.uid,
      authorizedPickupContacts: updated,
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String _formatDate(DateTime value) {
    return '${value.month}/${value.day}/${value.year}';
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _ParentListTile extends StatelessWidget {
  const _ParentListTile({required this.parent, required this.onTap});

  final ParentAccount parent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFDCEEFF),
              child: Icon(Icons.person_outline, color: Color(0xFF355C7D)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parent.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF263445),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parent.email.trim().isEmpty ? '-' : parent.email,
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _ParentDetailPage extends StatelessWidget {
  const _ParentDetailPage({
    required this.tenantId,
    required this.parent,
    required this.onAddChild,
    required this.onOpenParentForms,
    required this.onAddAuthorizedPickup,
    required this.onAddEmergencyContact,
    required this.onEditParent,
    required this.onDeleteParent,
    required this.onEditAuthorizedPickup,
    required this.onDeleteAuthorizedPickup,
    required this.onEditEmergencyContact,
    required this.onDeleteEmergencyContact,
    required this.onEditChild,
    required this.onDeleteChild,
  });

  final String tenantId;
  final ParentAccount parent;
  final VoidCallback onAddChild;
  final VoidCallback onOpenParentForms;
  final VoidCallback onAddAuthorizedPickup;
  final VoidCallback onAddEmergencyContact;
  final VoidCallback onEditParent;
  final VoidCallback onDeleteParent;
  final Future<void> Function(int index, FamilyContactRecord contact)
  onEditAuthorizedPickup;
  final Future<void> Function(int index) onDeleteAuthorizedPickup;
  final Future<void> Function(int index, FamilyContactRecord contact)
  onEditEmergencyContact;
  final Future<void> Function(int index) onDeleteEmergencyContact;
  final Future<void> Function(ChildRecord child) onEditChild;
  final Future<void> Function(ChildRecord child) onDeleteChild;

  @override
  Widget build(BuildContext context) {
    final repo = const TenantRepository();
    final isNarrow = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      appBar: AppBar(title: Text(parent.fullName)),
      bottomNavigationBar: const _ParentFooterBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: StreamBuilder<ParentAccount?>(
            stream: repo.watchParent(tenantId, parent.id),
            builder: (context, parentSnapshot) {
              final liveParent = parentSnapshot.data ?? parent;
              return StreamBuilder<List<ChildRecord>>(
                stream: repo.watchChildren(tenantId),
                builder: (context, snapshot) {
                  final children = (snapshot.data ?? const <ChildRecord>[])
                      .where((child) => child.parentId == liveParent.id)
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isNarrow) ...[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                liveParent.fullName,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.headlineSmall,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                liveParent.email.trim().isEmpty
                                                    ? '-'
                                                    : liveParent.email,
                                                style: const TextStyle(
                                                  color: Color(0xFF63748A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _CompactActionIcon(
                                              tooltip: 'Edit Parent',
                                              onPressed: onEditParent,
                                              icon: Icons.edit_outlined,
                                            ),
                                            const SizedBox(width: 8),
                                            _CompactActionIcon(
                                              tooltip: 'Delete Parent',
                                              onPressed: onDeleteParent,
                                              icon: Icons.delete_outline,
                                              iconColor: const Color(
                                                0xFFB42318,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _HeaderActionButton(
                                            onPressed: onAddChild,
                                            icon: Icons.child_friendly_outlined,
                                            label: 'Add Child',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _HeaderActionButton(
                                            onPressed: onOpenParentForms,
                                            icon: Icons.description_outlined,
                                            label: 'Parent Forms',
                                            tonal: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _HeaderActionButton(
                                            onPressed: onAddAuthorizedPickup,
                                            icon:
                                                Icons.family_restroom_outlined,
                                            label: 'Add Authorized Pickup',
                                            tonal: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ] else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  liveParent.fullName,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.headlineSmall,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  liveParent.email
                                                          .trim()
                                                          .isEmpty
                                                      ? '-'
                                                      : liveParent.email,
                                                  style: const TextStyle(
                                                    color: Color(0xFF63748A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _CompactActionIcon(
                                                tooltip: 'Edit Parent',
                                                onPressed: onEditParent,
                                                icon: Icons.edit_outlined,
                                              ),
                                              const SizedBox(width: 8),
                                              _CompactActionIcon(
                                                tooltip: 'Delete Parent',
                                                onPressed: onDeleteParent,
                                                icon: Icons.delete_outline,
                                                iconColor: const Color(
                                                  0xFFB42318,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 180,
                                      child: _HeaderActionButton(
                                        onPressed: onAddChild,
                                        icon: Icons.child_friendly_outlined,
                                        label: 'Add Child',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 180,
                                      child: _HeaderActionButton(
                                        onPressed: onOpenParentForms,
                                        icon: Icons.description_outlined,
                                        label: 'Parent Forms',
                                        tonal: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 220,
                                      child: _HeaderActionButton(
                                        onPressed: onAddAuthorizedPickup,
                                        icon: Icons.family_restroom_outlined,
                                        label: 'Add Authorized Pickup',
                                        tonal: true,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _DetailChip(
                                    label: 'Phone',
                                    value: liveParent.phone,
                                  ),
                                  _DetailChip(
                                    label: 'Address',
                                    value: liveParent.addressLine1,
                                  ),
                                  _DetailChip(
                                    label: 'City',
                                    value: liveParent.city,
                                  ),
                                  _DetailChip(
                                    label: 'State',
                                    value: liveParent.state,
                                  ),
                                  _DetailChip(
                                    label: 'ZIP',
                                    value: liveParent.zip,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Children',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 10),
                              if (children.isEmpty)
                                const Text(
                                  'This parent does not have children yet.',
                                )
                              else
                                ...children.map(
                                  (child) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ChildListTile(
                                      child: child,
                                      onEdit: () => onEditChild(child),
                                      onDelete: () => onDeleteChild(child),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              _ContactSection(
                                title: 'Authorized Pickup',
                                addLabel: 'Add',
                                onAdd: onAddAuthorizedPickup,
                                children:
                                    liveParent.authorizedPickupContacts.isEmpty
                                    ? const [
                                        Text(
                                          'No authorized pickup contacts yet.',
                                        ),
                                      ]
                                    : liveParent.authorizedPickupContacts
                                          .asMap()
                                          .entries
                                          .map(
                                            (entry) => _ContactListTile(
                                              title: entry.value.name,
                                              subtitle: _contactSubtitle(
                                                relation: entry.value.relation,
                                                phone: entry.value.phone,
                                              ),
                                              onEdit: () =>
                                                  onEditAuthorizedPickup(
                                                    entry.key,
                                                    entry.value,
                                                  ),
                                              onDelete: () =>
                                                  onDeleteAuthorizedPickup(
                                                    entry.key,
                                                  ),
                                            ),
                                          )
                                          .toList(),
                              ),
                              const SizedBox(height: 16),
                              _ContactSection(
                                title: 'Emergency Contacts',
                                addLabel: 'Add',
                                onAdd: onAddEmergencyContact,
                                children: liveParent.emergencyContacts.isEmpty
                                    ? const [Text('No emergency contacts yet.')]
                                    : liveParent.emergencyContacts
                                          .asMap()
                                          .entries
                                          .map(
                                            (entry) => _ContactListTile(
                                              title: entry.value.name,
                                              subtitle: _formatPhone(
                                                entry.value.phone,
                                              ),
                                              onEdit: () =>
                                                  onEditEmergencyContact(
                                                    entry.key,
                                                    entry.value,
                                                  ),
                                              onDelete: () =>
                                                  onDeleteEmergencyContact(
                                                    entry.key,
                                                  ),
                                            ),
                                          )
                                          .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ParentFormsPage extends StatelessWidget {
  const _ParentFormsPage({required this.tenantId, required this.parent});

  final String tenantId;
  final ParentAccount parent;

  @override
  Widget build(BuildContext context) {
    final repo = const TenantRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Parent Forms')),
      bottomNavigationBar: const _ParentFooterBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: StreamBuilder<ParentAccount?>(
            stream: repo.watchParent(tenantId, parent.id),
            builder: (context, parentSnapshot) {
              final liveParent = parentSnapshot.data ?? parent;
              return StreamBuilder<List<ChildRecord>>(
                stream: repo.watchChildren(tenantId),
                builder: (context, childSnapshot) {
                  final children = (childSnapshot.data ?? const <ChildRecord>[])
                      .where((child) => child.parentId == liveParent.id)
                      .toList();
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Card(
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
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FBFF),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFD8E2EC),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      liveParent.fullName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (liveParent.email.trim().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        liveParent.email,
                                        style: const TextStyle(
                                          color: Color(0xFF63748A),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    _ParentDocumentActionRow(
                                      title: 'Daycare Contract',
                                      subtitle:
                                          'Parent agreement and saved signature',
                                      onView: () => _openContractPdfPreview(
                                        context,
                                        parent: liveParent,
                                      ),
                                    ),
                                    if (children.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      ...children.map(
                                        (child) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Column(
                                            children: [
                                              _ParentDocumentActionRow(
                                                title:
                                                    '${child.fullName.isEmpty ? 'Child' : child.fullName} Photo Permission',
                                                subtitle:
                                                    'Signed photo sharing form for this child',
                                                onView: () =>
                                                    _openPhotoPermissionPdfPreview(
                                                      context,
                                                      parent: liveParent,
                                                      child: child,
                                                    ),
                                              ),
                                              const SizedBox(height: 10),
                                              _ParentDocumentActionRow(
                                                title:
                                                    '${child.fullName.isEmpty ? 'Child' : child.fullName} Enrollment Form',
                                                subtitle:
                                                    'Enrollment and emergency contact form for this child',
                                                onView: () =>
                                                    _openEnrollmentPdfPreview(
                                                      context,
                                                      parent: liveParent,
                                                      child: child,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ] else
                                      const Padding(
                                        padding: EdgeInsets.only(top: 10),
                                        child: Text(
                                          'This parent does not have child forms yet.',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openContractPdfPreview(
    BuildContext context, {
    required ParentAccount parent,
  }) async {
    final repo = const TenantRepository();
    final payload = await repo.loadParentContractDocument(
      tenantId: tenantId,
      parentId: parent.id,
    );
    final contract =
        (payload['parentContract'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final signaturePoints =
        (contract['signaturePoints'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    if (!context.mounted) return;
    await _showPdfPreview(
      context,
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

  Future<void> _openPhotoPermissionPdfPreview(
    BuildContext context, {
    required ParentAccount parent,
    required ChildRecord child,
  }) async {
    final repo = const TenantRepository();
    final payload = await repo.loadPhotoPermissionDocument(
      tenantId: tenantId,
      childId: child.id,
      parentId: parent.id,
    );
    final signaturePoints =
        (payload['signaturePoints'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    if (!context.mounted) return;
    final language = await _promptForDocumentLanguage(
      context,
      initialLanguage: (payload['documentLanguage'] ?? 'en').toString(),
    );
    if (language == null) return;
    if (!context.mounted) return;
    await _showPdfPreview(
      context,
      title: '${child.fullName} Photo Permission',
      build: () => FormPdfBuilder.buildPhotoPermissionPdf(
        languageCode: language,
        daycareName: (payload['daycareName'] ?? '').toString(),
        daycareAddress: (payload['daycareAddress'] ?? '').toString(),
        daycarePhone: (payload['daycarePhone'] ?? '').toString(),
        childName: child.fullName.isEmpty ? 'Child' : child.fullName,
        childDateOfBirthText: (payload['childDateOfBirthText'] ?? '-')
            .toString(),
        parentGuardianName: parent.fullName,
        internalCommunicationApproved:
            payload['internalCommunicationApproved'] == true,
        publicWebsiteApproved: payload['publicWebsiteApproved'] == true,
        signedName: (payload['signedName'] ?? '').toString(),
        signedAt: _asDateTime(payload['signedAt']),
        signaturePoints: signaturePoints,
      ),
    );
  }

  Future<void> _openEnrollmentPdfPreview(
    BuildContext context, {
    required ParentAccount parent,
    required ChildRecord child,
  }) async {
    final repo = const TenantRepository();
    final payload = await repo.loadChildEnrollmentDocument(
      tenantId: tenantId,
      childId: child.id,
      parentId: parent.id,
    );
    if (payload.isEmpty || !context.mounted) return;
    await _showPdfPreview(
      context,
      title: '${child.fullName} Enrollment Form',
      build: () => FormPdfBuilder.buildEnrollmentFormPdf(
        languageCode: 'en',
        daycareName: (payload['daycareName'] ?? '').toString(),
        dateOfApplicationText: (payload['dateOfApplicationText'] ?? '')
            .toString(),
        dateOfEnrollmentText:
            (payload['dateOfEnrollmentText'] ??
                    payload['childStartDateText'] ??
                    '')
                .toString(),
        lastDayOfEnrollmentText: (payload['lastDayOfEnrollmentText'] ?? '')
            .toString(),
        childName: (payload['childName'] ?? child.fullName).toString(),
        childDateOfBirthText: (payload['childDateOfBirthText'] ?? '-')
            .toString(),
        childGender: (payload['childGender'] ?? '').toString(),
        childStreetAddress:
            (payload['childStreetAddress'] ?? payload['childHomeAddress'] ?? '')
                .toString(),
        childCity: (payload['childCity'] ?? '').toString(),
        childState: (payload['childState'] ?? '').toString(),
        childZipCode: (payload['childZipCode'] ?? '').toString(),
        primaryLanguage: (payload['primaryLanguage'] ?? '').toString(),
        parent1Name: (payload['parent1Name'] ?? parent.fullName).toString(),
        parent1Address:
            (payload['parent1Address'] ?? payload['parent1HomeAddress'] ?? '')
                .toString(),
        parent1City: (payload['parent1City'] ?? parent.city).toString(),
        parent1ZipCode: (payload['parent1ZipCode'] ?? parent.zip).toString(),
        parent1HomePhone: _formatDocumentPhone(
          (payload['parent1HomePhone'] ?? '').toString(),
        ),
        parent1CellPhone: _formatDocumentPhone(
          (payload['parent1CellPhone'] ?? parent.phone).toString(),
        ),
        parent1EmergencyPhone: _formatDocumentPhone(
          (payload['parent1EmergencyPhone'] ?? '').toString(),
        ),
        parent1Email: (payload['parent1Email'] ?? parent.email).toString(),
        parent1Employer:
            (payload['parent1Employer'] ?? payload['parent1Employment'] ?? '')
                .toString(),
        parent1EmployerWorkPhone: _formatDocumentPhone(
          (payload['parent1EmployerWorkPhone'] ??
                  payload['parent1WorkPhone'] ??
                  '')
              .toString(),
        ),
        parent1EmployerAddress:
            (payload['parent1EmployerAddress'] ??
                    payload['parent1Address'] ??
                    payload['parent1HomeAddress'] ??
                    '')
                .toString(),
        parent1EmployerCity:
            (payload['parent1EmployerCity'] ?? payload['parent1City'] ?? '')
                .toString(),
        parent1EmployerZipCode:
            (payload['parent1EmployerZipCode'] ??
                    payload['parent1ZipCode'] ??
                    '')
                .toString(),
        parent2Name: (payload['parent2Name'] ?? '').toString(),
        parent2Address:
            (payload['parent2Address'] ?? payload['parent2HomeAddress'] ?? '')
                .toString(),
        parent2City: (payload['parent2City'] ?? '').toString(),
        parent2ZipCode: (payload['parent2ZipCode'] ?? '').toString(),
        parent2HomePhone: _formatDocumentPhone(
          (payload['parent2HomePhone'] ?? '').toString(),
        ),
        parent2CellPhone: _formatDocumentPhone(
          (payload['parent2CellPhone'] ?? '').toString(),
        ),
        parent2EmergencyPhone: _formatDocumentPhone(
          (payload['parent2EmergencyPhone'] ?? '').toString(),
        ),
        parent2Email: (payload['parent2Email'] ?? '').toString(),
        parent2Employer:
            (payload['parent2Employer'] ?? payload['parent2Employment'] ?? '')
                .toString(),
        parent2EmployerWorkPhone: _formatDocumentPhone(
          (payload['parent2EmployerWorkPhone'] ??
                  payload['parent2WorkPhone'] ??
                  '')
              .toString(),
        ),
        parent2EmployerAddress:
            (payload['parent2EmployerAddress'] ??
                    payload['parent2Address'] ??
                    payload['parent2HomeAddress'] ??
                    '')
                .toString(),
        parent2EmployerCity:
            (payload['parent2EmployerCity'] ?? payload['parent2City'] ?? '')
                .toString(),
        parent2EmployerZipCode:
            (payload['parent2EmployerZipCode'] ??
                    payload['parent2ZipCode'] ??
                    '')
                .toString(),
        contact1Name: (payload['contact1Name'] ?? '').toString(),
        contact1Relationship: (payload['contact1Relationship'] ?? '')
            .toString(),
        contact1Phone: _formatDocumentPhone(
          (payload['contact1Phone'] ?? '').toString(),
        ),
        contact2Name: (payload['contact2Name'] ?? '').toString(),
        contact2Relationship: (payload['contact2Relationship'] ?? '')
            .toString(),
        contact2Phone: _formatDocumentPhone(
          (payload['contact2Phone'] ?? '').toString(),
        ),
        restrictedPickupNotes: (payload['restrictedPickupNotes'] ?? '')
            .toString(),
        pediatricianName: (payload['pediatricianName'] ?? '').toString(),
        pediatricianPhone: _formatDocumentPhone(
          (payload['pediatricianPhone'] ?? '').toString(),
        ),
        preferredHospital: (payload['preferredHospital'] ?? '').toString(),
        allergyNotes: (payload['allergyNotes'] ?? '').toString(),
        medicationNotes: (payload['medicationNotes'] ?? '').toString(),
        signedName: (payload['signedName'] ?? '').toString(),
        signedAt: _asDateTime(payload['signedAt']),
        signaturePoints:
            (payload['signaturePoints'] as List<dynamic>? ?? const [])
                .map((item) => item.toString())
                .toList(),
      ),
    );
  }

  Future<String?> _promptForDocumentLanguage(
    BuildContext context, {
    required String initialLanguage,
  }) async {
    var selected = initialLanguage.trim().toLowerCase() == 'es' ? 'es' : 'en';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Document Language'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose the language for this document view.'),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'en',
                        label: Text('English'),
                      ),
                      ButtonSegment<String>(
                        value: 'es',
                        label: Text('Español'),
                      ),
                    ],
                    selected: {selected},
                    onSelectionChanged: (selection) {
                      setDialogState(() => selected = selection.first);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selected),
                  child: const Text('Open Document'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showPdfPreview(
    BuildContext context, {
    required String title,
    required Future<List<int>> Function() build,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 860,
          height: 720,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: PdfPreview(
                  canChangePageFormat: false,
                  canDebug: false,
                  allowSharing: true,
                  allowPrinting: true,
                  build: (format) async => Uint8List.fromList(await build()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

class _ParentDocumentActionRow extends StatelessWidget {
  const _ParentDocumentActionRow({
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

class _ParentFooterBar extends StatelessWidget {
  const _ParentFooterBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE9E2D8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const SafeArea(
        top: false,
        child: Text(
          'Daycare Backoffice Version: v1.0.47+48',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF667085),
          ),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final safe = value.trim().isEmpty ? '-' : _formatPhone(value.trim());
    return Chip(label: Text('$label: $safe'));
  }
}

class _CompactActionIcon extends StatelessWidget {
  const _CompactActionIcon({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.iconColor,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD8E2EC)),
          ),
          child: Icon(icon, color: iconColor ?? const Color(0xFF4B5563)),
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.tonal = false,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (tonal) {
      return FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: child,
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.children,
  });

  final String title;
  final String addLabel;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E2EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.tonal(onPressed: onAdd, child: Text(addLabel)),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ContactListTile extends StatelessWidget {
  const _ContactListTile({
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E2EC)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.trim().isEmpty ? '-' : title.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF263445),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle.trim().isEmpty ? '-' : subtitle.trim(),
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatPhone(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != 10) return value;
  return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
}

String _formatDocumentPhone(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != 10) return value.trim();
  return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
}

String _contactSubtitle({required String relation, required String phone}) {
  final safePhone = _formatPhone(phone.trim());
  final safeRelation = relation.trim();
  if (safeRelation.isEmpty) return safePhone;
  if (safePhone.isEmpty) return safeRelation;
  return '$safeRelation · $safePhone';
}

class _ChildListTile extends StatelessWidget {
  const _ChildListTile({
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  final ChildRecord child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final age = _ageFromDateOfBirth(child.dateOfBirth) ?? child.ageYears;
    final ageLabel = age == null ? '-' : '$age years';
    final dobLabel = child.dateOfBirth == null
        ? '-'
        : '${child.dateOfBirth!.month}/${child.dateOfBirth!.day}/${child.dateOfBirth!.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E2EC)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE6F6EC),
            child: Icon(Icons.child_friendly_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.fullName.isEmpty ? 'Child' : child.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF263445),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Age: $ageLabel  •  DOB: $dobLabel',
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          if (child.photoPermissionSigned)
            const Chip(label: Text('Photo OK'))
          else
            const Chip(label: Text('Photo Pending')),
        ],
      ),
    );
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

class _EditableFamilyContact {
  _EditableFamilyContact({
    String name = '',
    String phone = '',
    String relation = '',
  }) : nameController = TextEditingController(text: name),
       phoneController = TextEditingController(text: phone),
       relationController = TextEditingController(text: relation);

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController relationController;

  Map<String, String> toMap() => {
    'name': nameController.text.trim(),
    'phone': phoneController.text.trim(),
    'relation': relationController.text.trim(),
  };
}

class _FamilyContactEditor extends StatelessWidget {
  const _FamilyContactEditor({
    required this.title,
    required this.contact,
    required this.showRelation,
    this.onRemove,
  });

  final String title;
  final _EditableFamilyContact contact;
  final bool showRelation;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E2EC)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (onRemove != null)
                IconButton(onPressed: onRemove, icon: const Icon(Icons.close)),
            ],
          ),
          TextFormField(
            controller: contact.nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 10),
          if (showRelation) ...[
            TextFormField(
              controller: contact.relationController,
              decoration: const InputDecoration(labelText: 'Relation'),
            ),
            const SizedBox(height: 10),
          ],
          TextFormField(
            controller: contact.phoneController,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
        ],
      ),
    );
  }
}
