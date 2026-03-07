import 'package:flutter/material.dart';

import '../../models/tenant_membership.dart';
import '../../services/auth_service.dart';
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
  static const progressVersion = '1.0.8+9';
  int _index = 0;
  final _authService = const AuthService();
  static const _items = [
    _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, index: 0),
    _NavItem(
      label: 'Daycare Profile',
      icon: Icons.apartment_outlined,
      index: 1,
    ),
    _NavItem(label: 'Staff', icon: Icons.group_outlined, index: 2),
  ];

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
        body: Row(
          children: [
            _SideBar(
              currentIndex: _index,
              onNavigate: (next) => setState(() => _index = next),
              items: _items,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _appBar(isMobile: isMobile),
      body: body,
      bottomNavigationBar: NavigationBar(
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
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar({required bool isMobile}) {
    return AppBar(
      title: Text(switch (_index) {
        1 => 'Daycare Profile',
        2 => 'Staff',
        _ => 'Dashboard',
      }),
      actions: [
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
      return TenantProfilePage(uid: widget.uid, membership: widget.membership);
    }

    if (!widget.membership.isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Staff management is available for daycare admins only.'),
        ),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Staff management module placeholder (admin only).'),
      ),
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({required this.membership});

  final TenantMembership membership;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${membership.displayName}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Daycare ID: ${membership.tenantId}'),
                Text('Role: ${membership.role}'),
                Text('Status: ${membership.status}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'First milestone status',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text('1. Login with Firebase Auth'),
                Text('2. Membership resolver (tenant_memberships/{uid})'),
                Text('3. Role gate (admin/staff)'),
                Text('4. Daycare profile read/write (tenants/{tenantId})'),
                Text('5. Protected business fields shown as read-only'),
                Text('6. Responsive shell: mobile/tablet/desktop'),
              ],
            ),
          ),
        ),
      ],
    );
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
  });

  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.14);
    final railFooter = const _RailFooter();
    return Container(
      width: 272,
      padding: const EdgeInsets.all(12),
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          Text(
            'Liisgo Daycare',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...items.map((it) {
            final selected = it.index == currentIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonalIcon(
                onPressed: () => onNavigate(it.index),
                icon: Icon(it.icon),
                label: Text(it.label),
                style:
                    FilledButton.styleFrom(
                      elevation: 2,
                      shadowColor: Colors.black26,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                    ).copyWith(
                      backgroundColor: selected
                          ? WidgetStatePropertyAll(
                              Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.24),
                            )
                          : const WidgetStatePropertyAll(Colors.white),
                    ),
              ),
            );
          }),
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
    return Row(
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
    );
  }
}
