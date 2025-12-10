import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/screens/auth_screen.dart';

import '../../services/auth_service.dart';

class AdminRouteGuard extends StatelessWidget {
  final Widget child;

  const AdminRouteGuard({
    super.key,
    required this.child,
  });

  Future<bool> _checkTeacherAccessWithRetry() async {
    final authService = AuthService();

    // Try multiple times with delays to handle timing issues
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        debugPrint('Checking teacher access (attempt $attempt/3)');
        final isTeacher = await authService.isTeacher();

        if (isTeacher) {
          debugPrint('Teacher access confirmed on attempt $attempt');
          return true;
        }

        if (attempt < 3) {
          debugPrint('Teacher access denied on attempt $attempt, retrying in 1 second...');
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        debugPrint('Error checking teacher access on attempt $attempt: $e');
        if (attempt < 3) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    debugPrint('Teacher access denied after all attempts');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const AuthScreen();
        }

        return FutureBuilder<bool>(
          future: _checkTeacherAccessWithRetry(),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final hasTeacherAccess = adminSnapshot.data ?? false;
            if (!hasTeacherAccess) {
              return const Scaffold(
                body: Center(
                  child: Text('Access Denied: Teacher access required'),
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
