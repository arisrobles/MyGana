import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/screens/auth_screen.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';

class SuperAdminRouteGuard extends StatelessWidget {
  final Widget child;

  const SuperAdminRouteGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const AuthScreen();
        }

        return FutureBuilder<bool>(
          future: AuthService().isSuperAdmin(),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final isSuperAdmin = roleSnap.data ?? false;
            if (!isSuperAdmin) {
              return const Scaffold(
                body: Center(
                  child: Text('Access Denied: Super Admin required'),
                ),
              );
            }

            return child;
          },
        );
      },
    );
  }
}


