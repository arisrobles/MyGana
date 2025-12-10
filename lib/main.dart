import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nihongo_japanese_app/screens/splash_screen.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:nihongo_japanese_app/theme/app_theme.dart';
import 'package:nihongo_japanese_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/admin/admin_main_screen.dart';
import 'screens/admin/admin_profile_screen.dart';
import 'screens/admin/admin_route_guard.dart';
import 'screens/auth_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/lessons_screen.dart';
import 'screens/super_admin/super_admin_activity_screen.dart';
import 'screens/super_admin/super_admin_content_details.dart';
import 'screens/super_admin/super_admin_content_lists.dart';
import 'screens/super_admin/super_admin_main_screen.dart';
import 'screens/super_admin/super_admin_route_guard.dart';

// Singleton for Firebase initialization
class FirebaseInitializer {
  static bool _isInitializing = false;
  static bool _initialized = false;
  static FirebaseApp? _app;

  static Future<FirebaseApp> initialize() async {
    if (_initialized && _app != null) {
      debugPrint('Firebase already initialized: ${_app!.name}');
      return _app!;
    }

    if (_isInitializing) {
      debugPrint('Firebase initialization in progress, waiting...');
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _app!;
    }

    // Check for existing apps (possibly initialized by plugins)
    if (Firebase.apps.isNotEmpty) {
      _app = Firebase.apps.first;
      _initialized = true;
      debugPrint('Reusing existing Firebase app: ${_app!.name}');
      return _app!;
    }

    _isInitializing = true;
    debugPrint('Initializing Firebase...');
    try {
      _app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _initialized = true;
      debugPrint('Firebase initialized successfully with app: ${_app!.name}');
      return _app!;
    } catch (e, stackTrace) {
      debugPrint('Firebase initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow; // Propagate error for proper handling
    } finally {
      _isInitializing = false;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and handle errors
  try {
    await FirebaseInitializer.initialize();

    // Initialize Firebase sync service
    final firebaseSync = FirebaseUserSyncService();
    firebaseSync.initialize();

    // Sync user progress if user is authenticated
    final authService = AuthService();
    await authService.syncUserProgressOnAppStart();

    // Restore user data from Firebase if user is authenticated (authoritative source)
    if (authService.currentUser != null) {
      await firebaseSync.restoreUserDataFromFirebase();
      // Force sync current points to ensure they're up to date
      await firebaseSync.forceSyncCurrentPoints();
    }
  } catch (e) {
    print('Proceeding without Firebase due to initialization error: $e');
    // Optionally, you could navigate to an error screen here
  }

  // SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const NihongoApp(),
    ),
  );
}

class NihongoApp extends StatelessWidget {
  const NihongoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    ThemeData activeTheme;
    switch (themeProvider.appThemeMode) {
      case AppThemeMode.blueLight:
        activeTheme = AppTheme.blueLightTheme;
        break;
      case AppThemeMode.sakura:
        activeTheme = AppTheme.sakuraTheme;
        break;
      case AppThemeMode.matcha:
        activeTheme = AppTheme.matchaTheme;
        break;
      case AppThemeMode.sunset:
        activeTheme = AppTheme.sunsetTheme;
        break;
      case AppThemeMode.dark:
        activeTheme = AppTheme.darkTheme;
        break;
      case AppThemeMode.ocean:
        activeTheme = AppTheme.oceanTheme;
        break;
      case AppThemeMode.lavender:
        activeTheme = AppTheme.lavenderTheme;
        break;
      case AppThemeMode.autumn:
        activeTheme = AppTheme.autumnTheme;
        break;
      case AppThemeMode.fuji:
        activeTheme = AppTheme.fujiTheme;
        break;
      case AppThemeMode.light:
        activeTheme = AppTheme.lightTheme;
        break;
      case AppThemeMode.system:
        activeTheme = AppTheme.lightTheme;
        break;
    }

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _getStatusBarIconBrightness(themeProvider.appThemeMode),
        systemNavigationBarColor: _getNavigationBarColor(themeProvider.appThemeMode),
        systemNavigationBarIconBrightness: _getNavBarIconBrightness(themeProvider.appThemeMode),
      ),
    );

    return MaterialApp(
      title: 'Nihongo App',
      theme: activeTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/lessons': (context) => const LessonsScreen(),
        '/auth': (context) => const AuthScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/admin': (context) => const AdminRouteGuard(
              child: AdminMainScreen(),
            ),
        '/admin_profile': (context) => const AdminRouteGuard(
              child: AdminProfileScreen(),
            ),
        '/super_admin': (context) => const SuperAdminRouteGuard(
              child: SuperAdminMainScreen(),
            ),
        '/super_admin/activity': (context) => const SuperAdminRouteGuard(
              child: SuperAdminActivityScreen(),
            ),
        '/super_admin/content/lessons': (context) => const SuperAdminRouteGuard(
              child: SuperAdminLessonsListScreen(),
            ),
        '/super_admin/content/quizzes': (context) => const SuperAdminRouteGuard(
              child: SuperAdminQuizzesListScreen(),
            ),
        '/super_admin/content/classes': (context) => const SuperAdminRouteGuard(
              child: SuperAdminClassesListScreen(),
            ),
        // Full details
        '/super_admin/detail/lesson': (context) => const SuperAdminRouteGuard(
              child: _LessonDetailsRouteAdapter(),
            ),
        '/super_admin/detail/quiz': (context) => const SuperAdminRouteGuard(
              child: _QuizDetailsRouteAdapter(),
            ),
        '/super_admin/detail/class': (context) => const SuperAdminRouteGuard(
              child: _ClassDetailsRouteAdapter(),
            ),
      },
    );
  }

  Brightness _getStatusBarIconBrightness(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return Brightness.light;
      default:
        return Brightness.dark;
    }
  }

  Color _getNavigationBarColor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return AppTheme.backgroundColor;
      case AppThemeMode.dark:
        return AppTheme.darkBackgroundColor;
      case AppThemeMode.blueLight:
        return AppTheme.blueLightTheme.scaffoldBackgroundColor;
      case AppThemeMode.sakura:
        return AppTheme.sakuraTheme.scaffoldBackgroundColor;
      case AppThemeMode.matcha:
        return AppTheme.matchaTheme.scaffoldBackgroundColor;
      case AppThemeMode.sunset:
        return AppTheme.sunsetTheme.scaffoldBackgroundColor;
      case AppThemeMode.ocean:
        return AppTheme.oceanTheme.scaffoldBackgroundColor;
      case AppThemeMode.lavender:
        return AppTheme.lavenderTheme.scaffoldBackgroundColor;
      case AppThemeMode.autumn:
        return AppTheme.autumnTheme.scaffoldBackgroundColor;
      case AppThemeMode.fuji:
        return AppTheme.fujiTheme.scaffoldBackgroundColor;
      case AppThemeMode.system:
        return AppTheme.backgroundColor;
    }
  }

  Brightness _getNavBarIconBrightness(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return Brightness.light;
      default:
        return Brightness.dark;
    }
  }
}

// Route adapters to pass arguments through named routes
class _LessonDetailsRouteAdapter extends StatelessWidget {
  const _LessonDetailsRouteAdapter();
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final lessonId = args?['lessonId']?.toString() ?? '';
    return SuperAdminLessonDetailsScreen(lessonId: lessonId);
  }
}

class _QuizDetailsRouteAdapter extends StatelessWidget {
  const _QuizDetailsRouteAdapter();
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final quizId = args?['quizId']?.toString() ?? '';
    return SuperAdminQuizDetailsScreen(quizId: quizId);
  }
}

class _ClassDetailsRouteAdapter extends StatelessWidget {
  const _ClassDetailsRouteAdapter();
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final classId = args?['classId']?.toString() ?? '';
    return SuperAdminClassDetailsScreen(classId: classId);
  }
}
