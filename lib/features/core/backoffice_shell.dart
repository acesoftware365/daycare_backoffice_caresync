import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/family_records.dart';
import '../../models/tenant_membership.dart';
import '../../services/auth_service.dart';
import '../../services/tenant_repository.dart';
import '../parents/parents_page.dart';
import '../staff/staff_management_page.dart';
import '../tenant/tenant_profile_page.dart';

class BackofficeShell extends StatefulWidget {
  const BackofficeShell({
    super.key,
    required this.uid,
    required this.membership,
  });

  final String uid;
  final TenantMembership membership;

  @override
  State<BackofficeShell> createState() => _BackofficeShellState();
}

class _BackofficeShellState extends State<BackofficeShell> {
  static const progressVersion = '1.0.47+48';
  int _index = 0;
  TenantProfileAction? _requestedProfileAction;
  final _authService = const AuthService();
  final _repo = const TenantRepository();
  StreamSubscription<List<PickupNotificationRecord>>? _pickupAlertsSub;
  Set<String> _knownPickupAlertIds = <String>{};
  bool _didPrimePickupAlerts = false;
  static const _items = [
    _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, index: 0),
    _NavItem(
      label: 'Daycare Profile',
      icon: Icons.apartment_outlined,
      index: 1,
    ),
    _NavItem(label: 'Staff', icon: Icons.group_outlined, index: 2),
    _NavItem(label: 'Parents', icon: Icons.family_restroom_outlined, index: 3),
  ];

  @override
  void initState() {
    super.initState();
    _pickupAlertsSub = _repo
        .watchPendingPickupNotifications(widget.membership.tenantId)
        .listen(_handlePickupAlertsUpdate);
  }

  @override
  void dispose() {
    _pickupAlertsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 640;
    final desktop = width >= 1025;
    final tablet = width >= 601 && width < 1025;
    final body = _bodyForIndex();

    if (desktop || tablet) {
      return Scaffold(
        appBar: _appBar(isMobile: false),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8F1E8), Color(0xFFF0F8F3), Color(0xFFF7F2FB)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                _SideBar(
                  currentIndex: _index,
                  onNavigate: (next) => setState(() => _index = next),
                  items: _items,
                  onAddParent: () =>
                      _openProfileAction(TenantProfileAction.addParent),
                  onAddChild: () =>
                      _openProfileAction(TenantProfileAction.addChild),
                  onAddHouseholdMember: () => _openProfileAction(
                    TenantProfileAction.addHouseholdMember,
                  ),
                  onAddStaff: () => setState(() => _index = 2),
                ),
                const SizedBox(width: 22),
                Expanded(child: _ContentFrame(child: body)),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const _BottomBrandBar(),
      );
    }

    return Scaffold(
      appBar: _appBar(isMobile: isMobile),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F1E8), Color(0xFFF3F7FB)],
          ),
        ),
        child: Column(
          children: [
            _MobileQuickActions(
              showStaff: widget.membership.isAdmin,
              onAddStaff: () => setState(() => _index = 2),
              onAddHouseholdMember: () =>
                  _openProfileAction(TenantProfileAction.addHouseholdMember),
            ),
            Expanded(child: _ContentFrame(child: body)),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.apartment_outlined),
                label: 'Daycare Profile',
              ),
              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                label: 'Staff',
              ),
              NavigationDestination(
                icon: Icon(Icons.family_restroom_outlined),
                label: 'Parents',
              ),
            ],
          ),
          const _BottomBrandBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar({required bool isMobile}) {
    return AppBar(
      title: Text(switch (_index) {
        1 => 'Daycare Profile',
        2 => 'Staff',
        3 => 'Parents',
        _ => 'Dashboard',
      }),
      actions: [
        _NotificationsButton(
          membership: widget.membership,
          repo: _repo,
          isMobile: isMobile,
        ),
        const SizedBox(width: 8),
        if (!isMobile) ...[
          _UserBadge(membership: widget.membership),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: _authService.signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Salir'),
          ),
        ] else ...[
          IconButton(
            tooltip: 'Perfil',
            icon: const Icon(
              Icons.account_circle_outlined,
              color: Color(0xFF374151),
            ),
            onPressed: () => _showProfileSheet(context),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
            onSelected: (value) {
              if (value == 'about') _showAboutDialogBox(context);
              if (value == 'settings') _openSettings(context);
              if (value == 'logout') _authService.signOut();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'about', child: Text('About')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'logout', child: Text('Salir')),
            ],
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.membership.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                widget.membership.email,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(widget.membership.role.toUpperCase()),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialogBox(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Daycare Backoffice',
      applicationVersion: progressVersion,
    );
  }

  void _openSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const Text('Settings module coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _bodyForIndex() {
    if (_index == 0) {
      return _DashboardOverview(membership: widget.membership);
    }

    if (_index == 1) {
      return TenantProfilePage(
        uid: widget.uid,
        membership: widget.membership,
        requestedAction: _requestedProfileAction,
        onActionHandled: () {
          if (!mounted) return;
          setState(() => _requestedProfileAction = null);
        },
      );
    }

    if (_index == 2 && !widget.membership.isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Staff management is available for daycare admins only.'),
        ),
      );
    }

    if (_index == 2) {
      return StaffManagementPage(
        uid: widget.uid,
        membership: widget.membership,
      );
    }

    return ParentsPage(uid: widget.uid, membership: widget.membership);
  }

  void _openProfileAction(TenantProfileAction action) {
    setState(() {
      _index = 1;
      _requestedProfileAction = action;
    });
  }

  void _handlePickupAlertsUpdate(List<PickupNotificationRecord> alerts) {
    final ids = alerts.map((alert) => alert.id).toSet();
    if (_didPrimePickupAlerts &&
        ids.difference(_knownPickupAlertIds).isNotEmpty) {
      SystemSound.play(SystemSoundType.alert);
    }
    _knownPickupAlertIds = ids;
    _didPrimePickupAlerts = true;
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({required this.membership});

  final TenantMembership membership;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final twoUp = width >= 900;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD8EBFF), Color(0xFFD8F4E3), Color(0xFFF8DDE5)],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DAYCARE BACKOFFICE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Color(0xFF67758A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome, ${membership.displayName}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Manage families, child requests, and pickup alerts from one bright shared workspace.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              if (twoUp)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroLabel(
                        label: 'Tenant ID',
                        value: membership.tenantId,
                      ),
                      const SizedBox(height: 8),
                      _HeroLabel(label: 'Role', value: membership.role),
                      const SizedBox(height: 8),
                      _HeroLabel(label: 'Status', value: membership.status),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: const [
            _DashboardStatCard(
              title: 'Families',
              value: 'Parents + Children',
              accent: Color(0xFFE7F4EE),
              icon: Icons.family_restroom_outlined,
            ),
            _DashboardStatCard(
              title: 'Requests',
              value: 'Pending approvals',
              accent: Color(0xFFFDF0D6),
              icon: Icons.mark_email_unread_outlined,
            ),
            _DashboardStatCard(
              title: 'Pickup Alerts',
              value: 'Always visible',
              accent: Color(0xFFF9E2E7),
              icon: Icons.notifications_active_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _DailyUpdatesComposer(membership: membership),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workspace Overview',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                SizedBox(height: 10),
                Text('1. Login with Firebase Auth'),
                Text('2. Membership resolver (tenant_memberships/{uid})'),
                Text('3. Role gate (admin/staff)'),
                Text('4. Daycare profile read/write (tenants/{tenantId})'),
                Text('5. Protected business fields shown as read-only'),
                Text('6. Responsive shell for mobile, tablet, and desktop'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({
    required this.membership,
    required this.repo,
    required this.isMobile,
  });

  final TenantMembership membership;
  final TenantRepository repo;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PickupNotificationRecord>>(
      stream: repo.watchPendingPickupNotifications(membership.tenantId),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? const <PickupNotificationRecord>[];
        final hasPending = alerts.isNotEmpty;
        final foreground = hasPending ? Colors.white : const Color(0xFF374151);
        final background = hasPending
            ? const Color(0xFFC62828)
            : const Color(0xFFF3F4F6);

        final button = FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => _showNotificationsDialog(context),
          icon: Badge.count(
            isLabelVisible: hasPending,
            count: alerts.length,
            backgroundColor: Colors.white,
            textColor: const Color(0xFFC62828),
            child: Icon(
              hasPending
                  ? Icons.notifications_active
                  : Icons.notifications_none,
            ),
          ),
          label: Text(isMobile ? 'Alerts' : 'Notifications'),
        );

        return Padding(
          padding: EdgeInsets.only(right: isMobile ? 0 : 4),
          child: button,
        );
      },
    );
  }

  Future<void> _showNotificationsDialog(BuildContext context) async {
    final timeFormat = DateFormat('h:mm a');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StreamBuilder<List<ParentAccount>>(
                stream: repo.watchParents(membership.tenantId),
                builder: (context, parentSnapshot) {
                  final parents =
                      parentSnapshot.data ?? const <ParentAccount>[];
                  final parentById = {
                    for (final parent in parents) parent.id: parent,
                  };
                  return StreamBuilder<List<ChildRecord>>(
                    stream: repo.watchChildren(membership.tenantId),
                    builder: (context, childSnapshot) {
                      final children =
                          childSnapshot.data ?? const <ChildRecord>[];
                      return StreamBuilder<List<PickupNotificationRecord>>(
                        stream: repo.watchPendingPickupNotifications(
                          membership.tenantId,
                        ),
                        builder: (context, snapshot) {
                          final alerts =
                              snapshot.data ??
                              const <PickupNotificationRecord>[];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Pickup Notifications',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (alerts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'No active notifications right now.',
                                  ),
                                )
                              else
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: alerts.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final alert = alerts[index];
                                      final sentAt = alert.createdAt?.toLocal();
                                      final arrivalAt = sentAt?.add(
                                        Duration(minutes: alert.etaMinutes),
                                      );
                                      final childNames = _childNamesForParent(
                                        children,
                                        alert,
                                      );
                                      final parentName = _parentNameForAlert(
                                        parentById,
                                        alert,
                                      );
                                      return Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9FAFB),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .directions_car_filled_outlined,
                                                  color: Color(0xFFC62828),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        childNames,
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFFE8F0FE,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          'Parent: $parentName',
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFF38598B,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                FilledButton.tonal(
                                                  onPressed: () async {
                                                    await repo
                                                        .acknowledgePickupNotification(
                                                          tenantId: membership
                                                              .tenantId,
                                                          notificationId:
                                                              alert.id,
                                                          uid: membership.uid,
                                                        );
                                                  },
                                                  child: const Text('Received'),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              _pickupMessageForAlert(
                                                alert,
                                                parentName,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                _NotificationMetaChip(
                                                  label: 'Sent',
                                                  value: sentAt == null
                                                      ? '-'
                                                      : timeFormat.format(
                                                          sentAt,
                                                        ),
                                                ),
                                                _NotificationMetaChip(
                                                  label: 'ETA',
                                                  value:
                                                      '${alert.etaMinutes} min',
                                                ),
                                                _NotificationMetaChip(
                                                  label: 'Arrives',
                                                  value: arrivalAt == null
                                                      ? '-'
                                                      : timeFormat.format(
                                                          arrivalAt,
                                                        ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _childNamesForParent(
    List<ChildRecord> children,
    PickupNotificationRecord alert,
  ) {
    final matches = children
        .where((child) => child.parentId == alert.parentId)
        .map((child) => child.fullName)
        .where((name) => name.trim().isNotEmpty)
        .toList();
    if (matches.isNotEmpty) {
      return matches.join(', ');
    }
    if (alert.childName.trim().isNotEmpty) {
      return alert.childName.trim();
    }
    return 'Child pickup alert';
  }

  String _pickupMessageForAlert(
    PickupNotificationRecord alert,
    String parentName,
  ) {
    if (alert.message.trim().isEmpty) {
      return '$parentName is on the way for pickup.';
    }
    if (alert.message.contains(alert.childName) &&
        alert.childName.trim().isNotEmpty) {
      return '$parentName is on the way for pickup in about ${alert.etaMinutes} minutes.';
    }
    return alert.message;
  }

  String _parentNameForAlert(
    Map<String, ParentAccount> parentById,
    PickupNotificationRecord alert,
  ) {
    final parent = parentById[alert.parentId];
    if (parent != null && parent.fullName.trim().isNotEmpty) {
      return parent.fullName.trim();
    }
    if (alert.parentName.trim().isNotEmpty) {
      return alert.parentName.trim();
    }
    return 'Parent';
  }
}

class _NotificationMetaChip extends StatelessWidget {
  const _NotificationMetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF4B5563),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DailyUpdatesComposer extends StatefulWidget {
  const _DailyUpdatesComposer({required this.membership});

  final TenantMembership membership;

  @override
  State<_DailyUpdatesComposer> createState() => _DailyUpdatesComposerState();
}

class _DailyUpdatesComposerState extends State<_DailyUpdatesComposer> {
  static const _summaryOptions = <String>[
    'Breakfast',
    'Nap Time',
    'Outdoor Play',
    'Diaper Change',
    'Lunch',
    'Snack',
  ];

  final _repo = const TenantRepository();
  final _noteController = TextEditingController();
  String? _selectedChildId;
  Uint8List? _photoBytes;
  String? _photoName;
  String? _photoType;
  String? _existingPhotoName;
  String? _loadedSummaryChildId;
  String? _loadedLatestChildId;
  final Set<String> _selectedSummaryTags = <String>{};
  bool _savingLatest = false;
  bool _savingSummary = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChildRecord>>(
      stream: _repo.watchChildren(widget.membership.tenantId),
      builder: (context, snapshot) {
        final children = snapshot.data ?? const <ChildRecord>[];
        if (children.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Add children first before publishing updates.'),
            ),
          );
        }

        final selectedChild = _resolveSelectedChild(children);
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _repo.watchTodaySummary(
            widget.membership.tenantId,
            selectedChild.id,
          ),
          builder: (context, summarySnapshot) {
            final summaryData =
                summarySnapshot.data?.data() ?? const <String, dynamic>{};
            _syncSummaryState(selectedChild.id, summaryData);
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _repo.watchLatestUpdate(
                widget.membership.tenantId,
                selectedChild.id,
              ),
              builder: (context, latestSnapshot) {
                final latestData =
                    latestSnapshot.data?.data() ?? const <String, dynamic>{};
                _syncLatestState(selectedChild.id, latestData);
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
                                    'Parent Updates',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Publish the latest photo update and mark the child summary that parents see today.',
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: selectedChild.photoPermissionSigned
                                    ? const Color(0xFFE7F6ED)
                                    : const Color(0xFFF7E6EA),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                selectedChild.photoPermissionSigned
                                    ? 'Photo Permission Signed'
                                    : 'Photo Permission Missing',
                                style: TextStyle(
                                  color: selectedChild.photoPermissionSigned
                                      ? const Color(0xFF2F7D64)
                                      : const Color(0xFFB42318),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedChild.id,
                          decoration: const InputDecoration(labelText: 'Child'),
                          items: children
                              .map(
                                (child) => DropdownMenuItem(
                                  value: child.id,
                                  child: Text(
                                    child.fullName.isEmpty
                                        ? 'Child'
                                        : child.fullName,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedChildId = value;
                              _photoBytes = null;
                              _photoName = null;
                              _photoType = null;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Parents only see updates for the selected child: ${selectedChild.fullName.isEmpty ? 'Child' : selectedChild.fullName}.',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _summaryOptions.map((tag) {
                            final selected = _selectedSummaryTags.contains(tag);
                            return FilterChip(
                              label: Text(tag),
                              selected: selected,
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _selectedSummaryTags.add(tag);
                                  } else {
                                    _selectedSummaryTags.remove(tag);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: _savingSummary
                                    ? null
                                    : () => _saveTodaySummary(selectedChild),
                                icon: const Icon(Icons.checklist_rtl_outlined),
                                label: Text(
                                  'Save Today Summary for ${selectedChild.fullName.isEmpty ? 'Child' : selectedChild.fullName}',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FBFF),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE6DDD2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Latest Update',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _noteController,
                                minLines: 3,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Teacher note',
                                  hintText:
                                      'Share what the child did, learned, or enjoyed today.',
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _savingLatest
                                        ? null
                                        : _pickPhoto,
                                    icon: const Icon(
                                      Icons.upload_file_outlined,
                                    ),
                                    label: const Text('Upload Photo'),
                                  ),
                                  if (_photoName != null)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.image_outlined,
                                        size: 18,
                                      ),
                                      label: Text(_photoName!),
                                    )
                                  else if (_existingPhotoName != null)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.photo_library_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        'Current: $_existingPhotoName',
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _savingLatest
                                      ? null
                                      : () =>
                                            _publishLatestUpdate(selectedChild),
                                  icon: const Icon(Icons.send_outlined),
                                  label: Text(
                                    selectedChild.photoPermissionSigned
                                        ? 'Publish Latest Update for ${selectedChild.fullName.isEmpty ? 'Child' : selectedChild.fullName}'
                                        : 'Permission Required for Photos',
                                  ),
                                ),
                              ),
                            ],
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
      },
    );
  }

  ChildRecord _resolveSelectedChild(List<ChildRecord> children) {
    for (final child in children) {
      if (child.id == _selectedChildId) return child;
    }
    final fallback = children.first;
    _selectedChildId = fallback.id;
    return fallback;
  }

  void _syncSummaryState(String childId, Map<String, dynamic> summaryData) {
    if (_loadedSummaryChildId == childId) return;
    _loadedSummaryChildId = childId;
    final tags = (summaryData['tags'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedSummaryTags
          ..clear()
          ..addAll(tags);
      });
    });
  }

  void _syncLatestState(String childId, Map<String, dynamic> latestData) {
    if (_loadedLatestChildId == childId) return;
    _loadedLatestChildId = childId;
    final note = (latestData['note'] ?? '').toString();
    final photoName = (latestData['photoName'] ?? '').toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _noteController.text = note;
        _existingPhotoName = photoName.trim().isEmpty ? null : photoName;
      });
    });
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null || file.bytes == null) return;
    setState(() {
      _photoBytes = file.bytes;
      _photoName = file.name;
      _photoType = file.extension == 'png' ? 'image/png' : 'image/jpeg';
      _existingPhotoName = null;
    });
  }

  Future<void> _saveTodaySummary(ChildRecord child) async {
    setState(() => _savingSummary = true);
    try {
      await _repo.saveTodaySummary(
        tenantId: widget.membership.tenantId,
        uid: widget.membership.uid,
        childId: child.id,
        tags: _selectedSummaryTags.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Today summary saved for ${child.fullName.isEmpty ? 'child' : child.fullName}.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingSummary = false);
    }
  }

  Future<void> _publishLatestUpdate(ChildRecord child) async {
    if (!child.photoPermissionSigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This child does not have a signed photo permission yet.',
          ),
        ),
      );
      return;
    }
    if (_photoBytes == null || _photoName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a photo before publishing the update.'),
        ),
      );
      return;
    }

    setState(() => _savingLatest = true);
    try {
      final upload = await _repo.uploadChildUpdatePhoto(
        tenantId: widget.membership.tenantId,
        childId: child.id,
        fileName: _photoName!,
        bytes: _photoBytes!,
        contentType: _photoType,
      );
      await _repo.publishLatestUpdate(
        tenantId: widget.membership.tenantId,
        uid: widget.membership.uid,
        childId: child.id,
        childName: child.fullName,
        note: _noteController.text,
        photoUrl: upload.url,
        photoPath: upload.path,
        photoName: upload.fileName,
      );
      if (!mounted) return;
      setState(() {
        _photoBytes = null;
        _photoName = null;
        _photoType = null;
        _existingPhotoName = upload.fileName;
        _noteController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Latest update published for ${child.fullName.isEmpty ? 'child' : child.fullName}.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingLatest = false);
    }
  }
}

class _RailFooter {
  const _RailFooter();

  void openSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const Text('Settings module coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.currentIndex,
    required this.items,
    required this.onNavigate,
    required this.onAddParent,
    required this.onAddChild,
    required this.onAddHouseholdMember,
    required this.onAddStaff,
  });

  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onNavigate;
  final VoidCallback onAddParent;
  final VoidCallback onAddChild;
  final VoidCallback onAddHouseholdMember;
  final VoidCallback onAddStaff;

  @override
  Widget build(BuildContext context) {
    final railFooter = const _RailFooter();
    return Container(
      width: 272,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE6DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD8EBFF), Color(0xFFDFF5E6)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    child: Center(
                      child: Icon(Icons.apartment_rounded, size: 22),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liisgo Daycare',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Backoffice',
                        style: TextStyle(color: Color(0xFF637285)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...items.map((it) {
            final selected = it.index == currentIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.icon(
                onPressed: () => onNavigate(it.index),
                icon: Icon(it.icon),
                label: Text(it.label),
                style: FilledButton.styleFrom(
                  backgroundColor: selected
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFF8F7F4),
                  foregroundColor: selected
                      ? Colors.white
                      : const Color(0xFF334155),
                  elevation: 0,
                  alignment: Alignment.centerLeft,
                ),
              ),
            );
          }),
          const Divider(height: 20),
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: onAddStaff, child: const Text('Add Staff')),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onAddHouseholdMember,
            child: const Text('Household Member'),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: onAddParent, child: const Text('Add Parent')),
          const SizedBox(height: 8),
          FilledButton(onPressed: onAddChild, child: const Text('Add Child')),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: () => railFooter.openSettings(context),
            icon: const Icon(Icons.settings),
            label: const Text('Settings'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Minimal • Fast • SaaS-ready',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Version: ${_BackofficeShellState.progressVersion}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.index,
  });

  final String label;
  final IconData icon;
  final int index;
}

class _UserBadge extends StatelessWidget {
  const _UserBadge({required this.membership});

  final TenantMembership membership;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFE8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Usuario', style: Theme.of(context).textTheme.labelLarge),
              Text(
                membership.email,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(width: 10),
          Chip(
            label: Text(membership.role.toUpperCase()),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _MobileQuickActions extends StatelessWidget {
  const _MobileQuickActions({
    required this.showStaff,
    required this.onAddStaff,
    required this.onAddHouseholdMember,
  });

  final bool showStaff;
  final VoidCallback onAddStaff;
  final VoidCallback onAddHouseholdMember;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              if (showStaff)
                _MobileQuickActionChip(
                  icon: Icons.badge_outlined,
                  label: 'Add Staff',
                  onPressed: onAddStaff,
                ),
              _MobileQuickActionChip(
                icon: Icons.home_work_outlined,
                label: 'Household',
                onPressed: onAddHouseholdMember,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileQuickActionChip extends StatelessWidget {
  const _MobileQuickActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        alignment: Alignment.centerLeft,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BottomBrandBar extends StatelessWidget {
  const _BottomBrandBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: const BoxDecoration(color: Color(0xFFF1E7DC)),
      child: const Text(
        'Daycare Backoffice Version: v${_BackofficeShellState.progressVersion}',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ContentFrame extends StatelessWidget {
  const _ContentFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFE6DDD2)),
      ),
      child: child,
    );
  }
}

class _HeroLabel extends StatelessWidget {
  const _HeroLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF455569),
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF334155)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Color(0xFF5E6D79))),
          ],
        ),
      ),
    );
  }
}
