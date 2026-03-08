import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  static const _allParentsFilter = '__all__';
  final _repo = const TenantRepository();
  final _authService = const AuthService();
  String _selectedParentId = _allParentsFilter;

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

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileCard(context, profile),
            const SizedBox(height: 16),
            _ParentSection(tenantId: widget.membership.tenantId, repo: _repo),
            const SizedBox(height: 16),
            _buildChildrenSection(),
            const SizedBox(height: 16),
            _buildHouseholdMembersSection(),
          ],
        );
      },
    );
  }

  Widget _buildProfileCard(BuildContext context, TenantProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
          final children = await _repo.getChildren(widget.membership.tenantId);
          if (!mounted) return;
          await _showAddHouseholdMemberDialog(children);
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
        final selectedExists =
            _selectedParentId == _allParentsFilter ||
            parents.any((parent) => parent.id == _selectedParentId);
        if (!selectedExists && _selectedParentId != _allParentsFilter) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _selectedParentId = _allParentsFilter);
            }
          });
        }

        return StreamBuilder<List<ChildRecord>>(
          stream: _repo.watchChildren(widget.membership.tenantId),
          builder: (context, childSnapshot) {
            final children = childSnapshot.data ?? const <ChildRecord>[];
            final filtered = _selectedParentId == _allParentsFilter
                ? children
                : children
                      .where((child) => child.parentId == _selectedParentId)
                      .toList();
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
                    DropdownButtonFormField<String>(
                      initialValue: _selectedParentId,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Parent',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: _allParentsFilter,
                          child: Text('All Parents'),
                        ),
                        ...parents.map(
                          (parent) => DropdownMenuItem(
                            value: parent.id,
                            child: Text(parent.fullName),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedParentId = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    if (filtered.isEmpty)
                      const Text('No children found for this filter.')
                    else
                      ...filtered.map(
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

  Widget _buildHouseholdMembersSection() {
    return StreamBuilder<List<ChildRecord>>(
      stream: _repo.watchChildren(widget.membership.tenantId),
      builder: (context, childSnapshot) {
        final children = childSnapshot.data ?? const <ChildRecord>[];
        final childById = {for (final child in children) child.id: child};

        return StreamBuilder<List<HouseholdMemberRecord>>(
          stream: _repo.watchHouseholdMembers(widget.membership.tenantId),
          builder: (context, householdSnapshot) {
            final members =
                householdSnapshot.data ?? const <HouseholdMemberRecord>[];

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Household Members',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    if (members.isEmpty)
                      const Text('No household members added yet.')
                    else
                      ...members.map(
                        (member) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.assignment_ind_outlined),
                          title: Text(
                            '${member.firstName} ${member.lastName}'.trim(),
                          ),
                          subtitle: Text(
                            'Child: ${childById[member.childId]?.fullName ?? 'Unassigned'}\n'
                            'Physical Exam: ${_dateRange(member.physicalExamIssuedAt, member.physicalExamExpiresAt)}\n'
                            'Fingerprint: ${_dateRange(member.fingerprintIssuedAt, member.fingerprintExpiresAt)}',
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

  Future<void> _showAddHouseholdMemberDialog(List<ChildRecord> children) async {
    if (children.isEmpty) {
      _showMessage('Add at least one child before adding household members.');
      return;
    }

    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedChildId = children.first.id;
    DateTime? physicalIssued;
    DateTime? physicalExpires;
    DateTime? fingerprintIssued;
    DateTime? fingerprintExpires;
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

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Household Member'),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedChildId,
                          decoration: const InputDecoration(labelText: 'Child'),
                          items: children
                              .map(
                                (child) => DropdownMenuItem(
                                  value: child.id,
                                  child: Text(child.fullName),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedChildId = value);
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
                        const SizedBox(height: 12),
                        _DatePickerRow(
                          label: 'Physical Exam Issued',
                          value: physicalIssued,
                          onPick: () => pickDate(
                            (picked) =>
                                setDialogState(() => physicalIssued = picked),
                            physicalIssued,
                          ),
                        ),
                        _DatePickerRow(
                          label: 'Physical Exam Expires',
                          value: physicalExpires,
                          onPick: () => pickDate(
                            (picked) =>
                                setDialogState(() => physicalExpires = picked),
                            physicalExpires,
                          ),
                        ),
                        _DatePickerRow(
                          label: 'Fingerprint Issued',
                          value: fingerprintIssued,
                          onPick: () => pickDate(
                            (picked) => setDialogState(
                              () => fingerprintIssued = picked,
                            ),
                            fingerprintIssued,
                          ),
                        ),
                        _DatePickerRow(
                          label: 'Fingerprint Expires',
                          value: fingerprintExpires,
                          onPick: () => pickDate(
                            (picked) => setDialogState(
                              () => fingerprintExpires = picked,
                            ),
                            fingerprintExpires,
                          ),
                        ),
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
                            await _repo.createHouseholdMember(
                              tenantId: widget.membership.tenantId,
                              uid: widget.uid,
                              firstName: firstNameController.text,
                              lastName: lastNameController.text,
                              childId: selectedChildId,
                              physicalExamIssuedAt: physicalIssued,
                              physicalExamExpiresAt: physicalExpires,
                              fingerprintIssuedAt: fingerprintIssued,
                              fingerprintExpiresAt: fingerprintExpires,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          } catch (_) {
                            if (!context.mounted) return;
                            setDialogState(() => saving = false);
                            _showMessage('Could not add household member.');
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Member'),
                ),
              ],
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

  String _dateRange(DateTime? start, DateTime? end) {
    final f = DateFormat('yyyy-MM-dd');
    final startText = start == null ? '-' : f.format(start);
    final endText = end == null ? '-' : f.format(end);
    return '$startText -> $endText';
  }
}

class _ParentSection extends StatelessWidget {
  const _ParentSection({required this.tenantId, required this.repo});

  final String tenantId;
  final TenantRepository repo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ParentAccount>>(
      stream: repo.watchParents(tenantId),
      builder: (context, snapshot) {
        final parents = snapshot.data ?? const <ParentAccount>[];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Parents', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (parents.isEmpty)
                  const Text('No parents added yet.')
                else
                  ...parents.map(
                    (parent) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(parent.fullName),
                      subtitle: Text(parent.email),
                      trailing: parent.authUid.trim().isEmpty
                          ? const Text('No Auth UID')
                          : const Icon(Icons.verified_user_outlined),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Select date'
        : DateFormat('yyyy-MM-dd').format(value!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          OutlinedButton(onPressed: onPick, child: Text(text)),
        ],
      ),
    );
  }
}
