import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/screens/auth_screen.dart';
import 'package:nihongo_japanese_app/screens/main_screen.dart'; // Import MainScreen
import 'package:nihongo_japanese_app/screens/maintenance_screen.dart';
import 'package:nihongo_japanese_app/screens/user_onboarding_screen.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:nihongo_japanese_app/services/system_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeIn,
      ),
    );

    _fadeAnimationController.forward();

    Timer(const Duration(milliseconds: 1500), () {
      _checkAuthStatus();
    });
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    if (!mounted) {
      debugPrint('SplashScreen not mounted, aborting auth check');
      return;
    }

    try {
      debugPrint('Checking Firebase initialization status');
      // Ensure Firebase is initialized
      if (Firebase.apps.isEmpty) {
        debugPrint('Firebase not initialized, navigating to AuthScreen');
        _navigateTo(const AuthScreen());
        return;
      }

      // Check for maintenance mode first (but allow super admin to bypass)
      debugPrint('Checking maintenance mode...');
      final systemConfig = SystemConfigService();
      final isMaintenanceMode = await systemConfig.isMaintenanceMode();

      if (isMaintenanceMode) {
        // Check if current user is super admin
        final user = _authService.currentUser;
        if (user != null) {
          final role = await _authService.getUserRole();
          final isSuperAdmin =
              role == 'super_admin' && user.email?.toLowerCase() == 'superadmin01@gmail.com';

          if (isSuperAdmin) {
            debugPrint('Super admin bypassing maintenance mode');
            // Continue with normal flow for super admin
          } else {
            debugPrint('Maintenance mode is active, showing maintenance screen');
            _showMaintenanceScreen();
            return;
          }
        } else {
          debugPrint('Maintenance mode is active, showing maintenance screen');
          _showMaintenanceScreen();
          return;
        }
      }

      debugPrint('Checking current user');
      final user = _authService.currentUser;
      if (user == null) {
        debugPrint('No user authenticated, navigating to AuthScreen');
        _navigateTo(const AuthScreen());
        return;
      }

      debugPrint('User found: ${user.uid}, resolving role');
      final role = await _authService.getUserRole();
      debugPrint('Resolved role: $role');
      if (mounted) {
        // Check for super admin first - but only if email matches super admin email
        if (role == 'super_admin' && user.email?.toLowerCase() == 'superadmin01@gmail.com') {
          debugPrint('Navigating to super admin');
          Navigator.of(context).pushReplacementNamed('/super_admin');
          return;
        }

        // If role is super_admin but email doesn't match, treat as teacher
        if (role == 'super_admin' && user.email?.toLowerCase() != 'superadmin01@gmail.com') {
          debugPrint('WARNING: Role is super_admin but email doesn\'t match, treating as teacher');
          // Continue to teacher check below
        }

        // Check for teacher access with retry mechanism
        debugPrint('Checking teacher access...');
        bool isTeacher = false;
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            isTeacher = await _authService.isTeacher();
            debugPrint('Teacher check attempt $attempt: $isTeacher');
            if (isTeacher) break;
            if (attempt < 3) {
              debugPrint('Waiting 1 second before retry...');
              await Future.delayed(const Duration(seconds: 1));
            }
          } catch (e) {
            debugPrint('Error checking teacher access on attempt $attempt: $e');
            if (attempt < 3) {
              await Future.delayed(const Duration(seconds: 1));
            }
          }
        }

        if (isTeacher) {
          debugPrint('Navigating to admin');
          Navigator.of(context).pushReplacementNamed('/admin');
          return;
        }
      }

      debugPrint('Checking profile completion status');
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedProfile = prefs.getBool('has_completed_profile') ?? false;
      debugPrint('hasCompletedProfile: $hasCompletedProfile');

      debugPrint('Navigating to ${hasCompletedProfile ? 'MainScreen' : 'UserOnboardingScreen'}');
      _navigateTo(
        hasCompletedProfile ? const MainScreen() : const UserOnboardingScreen(),
      );
    } catch (e, stackTrace) {
      debugPrint('Error checking auth status: $e\nStack trace: $stackTrace');
      if (mounted) {
        _navigateTo(const AuthScreen());
      }
    }
  }

  void _navigateTo(Widget destination) {
    if (!mounted) {
      debugPrint('SplashScreen not mounted, aborting navigation');
      return;
    }
    debugPrint('Navigating to ${destination.runtimeType}');
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _showMaintenanceScreen() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MaintenanceScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'MyGana',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'TheLastShuriken',
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 8.0,
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Japanese Learning App',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
