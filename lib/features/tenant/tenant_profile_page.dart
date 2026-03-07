import 'package:flutter/material.dart';

import '../../models/tenant_membership.dart';
import '../../models/tenant_profile.dart';
import '../../services/tenant_repository.dart';

class TenantProfilePage extends StatelessWidget {
  const TenantProfilePage({
    super.key,
    required this.uid,
    required this.membership,
  });

  final String uid;
  final TenantMembership membership;

  @override
  Widget build(BuildContext context) {
    const repo = TenantRepository();

    return StreamBuilder<TenantProfile?>(
      stream: repo.watchTenant(membership.tenantId),
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
            Card(
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
            ),
          ],
        );
      },
    );
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
