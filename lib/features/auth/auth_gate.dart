import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/tenant_membership.dart';
import '../../services/auth_service.dart';
import '../../services/tenant_repository.dart';
import '../core/backoffice_shell.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    const authService = AuthService();
    const tenantRepository = TenantRepository();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) return const LoginPage();

        return StreamBuilder<TenantMembership?>(
          stream: tenantRepository.watchMembership(user.uid),
          builder: (context, membershipSnapshot) {
            if (membershipSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (membershipSnapshot.hasError) {
              return LoginPage(
                initialError:
                    'Membership read failed (Firestore rules). ${membershipSnapshot.error}',
              );
            }

            final membership = membershipSnapshot.data;
            if (membership == null) {
              return const LoginPage(
                initialError:
                    'No membership found for this account. Contact support.',
              );
            }

            if (!membership.isActive) {
              return const LoginPage(
                initialError:
                    'This account is inactive. Contact your administrator.',
              );
            }

            return BackofficeShell(uid: user.uid, membership: membership);
          },
        );
      },
    );
  }
}
