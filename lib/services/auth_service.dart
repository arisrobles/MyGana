import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:nihongo_japanese_app/services/challenge_progress_service.dart';
import 'package:nihongo_japanese_app/services/coin_service.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:nihongo_japanese_app/services/profile_image_service.dart';
import 'package:nihongo_japanese_app/services/progress_service.dart';
import 'package:nihongo_japanese_app/services/teacher_activity_service.dart';
import 'package:nihongo_japanese_app/services/user_activity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseUserSyncService _firebaseSync = FirebaseUserSyncService();
  final UserActivityService _userActivityService = UserActivityService();
  final TeacherActivityService _teacherActivityService = TeacherActivityService();
  static const String _superAdminEmail = 'superadmin01@gmail.com';

  User? get currentUser => _auth.currentUser;

  Stream<User?> getAuthStateChanges() => authStateChanges;

  // Check if user is authenticated
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sync user progress when app starts (if user is authenticated)
  Future<void> syncUserProgressOnAppStart() async {
    try {
      if (currentUser != null) {
        debugPrint('Syncing user progress on app start for user: ${currentUser!.uid}');
        await _firebaseSync.syncUserProgressToFirebase();
        debugPrint('User progress synced on app start');
      } else {
        debugPrint('No authenticated user found for progress sync');
      }
    } catch (e) {
      debugPrint('Error syncing user progress on app start: $e');
      // Don't throw error, app should continue to work
    }
  }

  // Backward-compatible: Check if user has teacher-level access (teacher or super admin or legacy isAdmin)
  Future<bool> isAdmin() async {
    if (currentUser == null) {
      debugPrint('No user signed in for admin check');
      return false;
    }
    try {
      // Prefer role-based check first
      final role = await getUserRole();
      if (role == 'teacher' || role == 'super_admin') {
        return true;
      }

      // Fallback to legacy boolean flag
      final snapshot =
          await FirebaseDatabase.instance.ref().child('users/${currentUser!.uid}/isAdmin').get();
      final legacyIsAdmin = snapshot.exists && snapshot.value == true;
      debugPrint('Legacy isAdmin fallback result: $legacyIsAdmin');
      return legacyIsAdmin;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  // Role helpers
  Future<String?> getUserRole() async {
    try {
      if (currentUser == null) return null;

      debugPrint('Getting role for user: ${currentUser!.uid}');

      // Try to get role from database with retry mechanism
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final ref = FirebaseDatabase.instance.ref().child('users/${currentUser!.uid}/role');
          final snapshot = await ref.get();

          if (snapshot.exists) {
            final role = snapshot.value?.toString();
            debugPrint('Role found in database (attempt $attempt): $role');
            return role;
          }

          debugPrint('Role not found in database (attempt $attempt)');
          if (attempt < 3) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          debugPrint('Error getting role from database (attempt $attempt): $e');
          if (attempt < 3) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }

      // Infer from legacy fields or email
      debugPrint('Falling back to legacy isAdmin check');
      final legacyAdminSnap =
          await FirebaseDatabase.instance.ref().child('users/${currentUser!.uid}/isAdmin').get();
      final isLegacyAdmin = legacyAdminSnap.exists && legacyAdminSnap.value == true;
      if (isLegacyAdmin) {
        debugPrint('Legacy admin detected, returning teacher');
        return 'teacher';
      }

      final userEmail = (currentUser!.email ?? '').toLowerCase();
      debugPrint('Checking email against super admin email: $userEmail vs $_superAdminEmail');
      if (userEmail == _superAdminEmail) {
        debugPrint('Super admin email detected');
        return 'super_admin';
      }

      debugPrint('Defaulting to student role');
      return 'student';
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return null;
    }
  }

  Future<bool> isSuperAdmin() async {
    if (currentUser == null) return false;
    try {
      final role = await getUserRole();
      if (role == 'super_admin') return true;
      // Fallback based on email
      return (currentUser!.email ?? '').toLowerCase() == _superAdminEmail;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isTeacher() async {
    if (currentUser == null) return false;
    try {
      final role = await getUserRole();

      // Special case: if role is super_admin but email doesn't match super admin email, treat as teacher
      if (role == 'super_admin' && (currentUser!.email ?? '').toLowerCase() != _superAdminEmail) {
        debugPrint('Role is super_admin but email doesn\'t match, treating as teacher');
        return true;
      }

      if (role == 'teacher') return true;
      // Accept super admin as having teacher access (only if email matches)
      if (role == 'super_admin' && (currentUser!.email ?? '').toLowerCase() == _superAdminEmail) {
        return true;
      }

      // Fallback to legacy flag with better error handling
      try {
        final snapshot =
            await FirebaseDatabase.instance.ref().child('users/${currentUser!.uid}/isAdmin').get();
        final isAdmin = snapshot.exists && snapshot.value == true;
        debugPrint('Legacy isAdmin check for ${currentUser!.uid}: $isAdmin');
        return isAdmin;
      } catch (e) {
        debugPrint('Error checking legacy isAdmin: $e');
        return false;
      }
    } catch (e) {
      debugPrint('Error in isTeacher(): $e');
      return false;
    }
  }

  Future<void> _ensureRoleConsistencyAfterLogin() async {
    if (currentUser == null) return;
    try {
      final userRef = FirebaseDatabase.instance.ref().child('users/${currentUser!.uid}');
      final userSnap = await userRef.get();
      Map<String, dynamic> existing = {};
      if (userSnap.exists && userSnap.value is Map) {
        existing = Map<String, dynamic>.from(userSnap.value as Map);
      }

      String? role = existing['role']?.toString();
      final email = (currentUser!.email ?? '').toLowerCase();

      // Promote special email to super_admin if missing
      if (email == _superAdminEmail) {
        role = 'super_admin';
        existing['isAdmin'] = true; // keep legacy compatible
      } else if (role == null) {
        // Infer from legacy isAdmin
        final legacyIsAdmin = existing['isAdmin'] == true;
        role = legacyIsAdmin ? 'teacher' : 'student';
      }

      // If email is invited as teacher, ensure teacher role
      try {
        final inviteSnap = await FirebaseDatabase.instance
            .ref()
            .child('teacherInvites/${email.replaceAll('.', ',')}')
            .get();
        if (inviteSnap.exists) {
          if (role != 'super_admin') {
            role = 'teacher';
            existing['isAdmin'] = true;
          }
        }
      } catch (_) {}

      await userRef.update({'role': role, 'lastLoginAt': ServerValue.timestamp});
    } catch (e) {
      debugPrint('Error ensuring role consistency: $e');
    }
  }

  // Enhanced method to ensure user is authenticated for reading
  Future<bool> ensureAuthenticated() async {
    try {
      // Check if already authenticated
      if (currentUser != null) {
        debugPrint('User already authenticated: ${currentUser!.uid}');
        return true;
      }

      // Try anonymous sign in for read access
      debugPrint('No user found, attempting anonymous sign in...');
      final UserCredential userCredential = await _auth.signInAnonymously();

      if (userCredential.user != null) {
        debugPrint('Anonymous sign in successful: ${userCredential.user!.uid}');
        // Wait for authentication to be fully processed
        await Future.delayed(const Duration(milliseconds: 1000));
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error ensuring authentication: $e');
      return false;
    }
  }

  // Sign in anonymously for read access with retry logic
  Future<void> signInAnonymously({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('Attempting anonymous sign in (attempt $attempt/$maxRetries)...');

        final UserCredential userCredential = await _auth.signInAnonymously();

        if (userCredential.user == null) {
          throw Exception('Anonymous sign in failed: No user returned');
        }

        debugPrint('Anonymous sign in successful for user: ${userCredential.user!.uid}');

        // Wait for authentication to be ready
        await Future.delayed(const Duration(milliseconds: 500));
        return;
      } on FirebaseAuthException catch (e) {
        debugPrint(
            'FirebaseAuthException during anonymous sign in (attempt $attempt): ${e.code} - ${e.message}');

        if (attempt == maxRetries) {
          String errorMessage;
          switch (e.code) {
            case 'operation-not-allowed':
              errorMessage = 'Anonymous authentication is not enabled.';
              break;
            case 'network-request-failed':
              errorMessage = 'Network error. Please check your connection.';
              break;
            default:
              errorMessage = 'Anonymous sign in failed: ${e.message}';
          }
          throw Exception(errorMessage);
        }

        // Wait before retry
        await Future.delayed(Duration(seconds: attempt));
      } catch (e) {
        debugPrint('Unexpected anonymous sign in error (attempt $attempt): $e');

        if (attempt == maxRetries) {
          throw Exception('Unexpected error during anonymous sign in: $e');
        }

        // Wait before retry
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  // Login with improved error handling
  Future<void> login(String email, String password, {int retryCount = 2}) async {
    try {
      debugPrint('Attempting login with email: $email (Retry count: $retryCount)');

      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user == null) {
        debugPrint('Login failed: No user returned from Firebase');
        throw Exception('Login failed: No user found after authentication');
      }

      debugPrint('Login successful for user: ${userCredential.user!.uid}');

      // Wait a moment for the database to be ready
      await Future.delayed(const Duration(milliseconds: 500));

      // Only clear data if user actually changed, not for password reset
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastUserId = prefs.getString('last_user_id');
        final currentUserId = userCredential.user!.uid;

        // Only clear data if user actually changed
        if (lastUserId != null && lastUserId != currentUserId) {
          debugPrint(
              'User changed from $lastUserId to $currentUserId - clearing previous user data');
          await _clearPreviousUserData();
          // Reset ALL services for new user
          ProgressService().reset();
          ChallengeProgressService().reset();
          CoinService().reset();
          ProfileImageService().reset();
          // Clear Firebase listeners and cache for the new user
          _firebaseSync.clearUserData();
        } else {
          debugPrint('Same user logging in (UID: $currentUserId) - preserving user data');
        }

        // Set up fresh listeners for the current user
        _firebaseSync.initialize();
        await _firebaseSync.restoreUserDataFromFirebase();

        // Ensure last_user_id is set for future logins
        await prefs.setString('last_user_id', currentUserId);
        debugPrint('User data restored from Firebase after login');
      } catch (e) {
        debugPrint('Error restoring user data after login: $e');
        // Don't throw error, login was successful
      }

      // Sync user progress to Firebase after successful login
      try {
        await _firebaseSync.syncUserProgressToFirebase();
        debugPrint('User progress synced to Firebase after login');
      } catch (e) {
        debugPrint('Error syncing user progress after login: $e');
        // Don't throw error, login was successful
      }
      // Ensure role field is present/consistent
      try {
        await _ensureRoleConsistencyAfterLogin();
      } catch (_) {}

      // Set user as online in leaderboard
      try {
        await _setUserOnline();
        debugPrint('User set as online in leaderboard');
      } catch (e) {
        debugPrint('Error setting user online: $e');
        // Don't throw error, login was successful
      }

      // Log login activity
      try {
        // Wait a bit more to ensure role is properly set
        await Future.delayed(const Duration(milliseconds: 200));
        final userRole = await getUserRole();
        debugPrint('Attempting to log login activity for role: $userRole');

        if (userRole == 'teacher') {
          await _teacherActivityService.logLogin('email');
          debugPrint('Teacher login activity logged successfully');
        } else if (userRole == 'super_admin') {
          // Super admins are also teachers, so log as teacher activity
          await _teacherActivityService.logLogin('email');
          debugPrint('Super admin login activity logged as teacher');
        } else {
          await _userActivityService.logLogin('email');
          debugPrint('Student login activity logged successfully');
        }
      } catch (e) {
        debugPrint('Error logging login activity: $e');
        // Don't throw error, login was successful
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during login: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid email or password. Please try again.';
          break;
        default:
          if (e.message?.contains('reCAPTCHA') ?? false) {
            errorMessage = 'reCAPTCHA verification failed. Please try again.';
          } else {
            errorMessage = 'Login failed: ${e.message}';
          }
      }
      throw Exception(errorMessage);
    } catch (e, stackTrace) {
      debugPrint('Unexpected login error: $e\nStack trace: $stackTrace');

      // Handle specific type casting errors - ignore them if user is authenticated
      if (e.toString().contains('PigeonUserInfo') ||
          e.toString().contains('type cast') ||
          e.toString().contains('List<Object?>')) {
        debugPrint('Type casting error detected, checking if user is actually authenticated');

        // Wait a bit and check if user is actually authenticated
        await Future.delayed(const Duration(milliseconds: 1000));

        if (currentUser != null) {
          debugPrint('User is authenticated despite type error: ${currentUser!.uid}');
          return; // Login was actually successful, ignore the type error
        }
      }

      // Retry for network errors
      if (e.toString().contains('Connection reset by peer') && retryCount > 0) {
        debugPrint('Retrying login due to network error...');
        await Future.delayed(const Duration(seconds: 2));
        return login(email, password, retryCount: retryCount - 1);
      }

      throw Exception('Unexpected error during login: $e');
    }
  }

  // Register with improved error handling
  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String gender,
    String? profileImagePath,
    bool isAdmin = false,
  }) async {
    try {
      debugPrint('Registering user with email: $email');

      // Create user with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      User? user = userCredential.user;

      if (user == null) {
        debugPrint('Registration failed: No user returned');
        throw Exception('Registration failed: No user created');
      }

      debugPrint('User created: ${user.uid}');

      // Update user profile with retry mechanism
      try {
        await user.updateDisplayName('$firstName $lastName');
        await user.reload();
        debugPrint('User profile updated with name: $firstName $lastName');
      } catch (e) {
        debugPrint('Error updating display name: $e');
        // Continue with registration even if display name update fails
      }

      // Store user data in Realtime Database with explicit admin flag and role
      final userData = {
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'profileImageUrl': profileImagePath,
        'isAdmin': isAdmin,
        'role': isAdmin
            ? 'teacher'
            : ((email.toLowerCase() == _superAdminEmail) ? 'super_admin' : 'student'),
        'createdAt': ServerValue.timestamp,
      };

      await FirebaseDatabase.instance.ref().child('users/${user.uid}').set(userData);

      // Set user as online in leaderboard
      await _setUserOnline();

      debugPrint('User data saved to Realtime Database with admin status: $isAdmin');

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('first_name', firstName);
      await prefs.setString('last_name', lastName);
      await prefs.setString('gender', gender);
      await prefs.setBool('has_completed_profile', true);
      debugPrint('User data saved to SharedPreferences');

      // Sync user progress to Firebase after successful registration
      try {
        await _firebaseSync.syncUserProgressToFirebase();
        debugPrint('User progress synced to Firebase after registration');
      } catch (e) {
        debugPrint('Error syncing user progress after registration: $e');
        // Don't throw error, registration was successful
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during registration: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already in use.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        default:
          errorMessage = 'Registration failed: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e, stackTrace) {
      debugPrint('Unexpected registration error: $e\nStack trace: $stackTrace');

      // Handle type casting errors during registration - ignore if user was created
      if (e.toString().contains('PigeonUserInfo') ||
          e.toString().contains('type cast') ||
          e.toString().contains('List<Object?>')) {
        debugPrint('Type casting error during registration, checking if user was created');

        await Future.delayed(const Duration(milliseconds: 1000));

        if (currentUser != null) {
          debugPrint('User was created despite type error: ${currentUser!.uid}');

          // Try to save user data to database
          try {
            final userData = {
              'email': email,
              'firstName': firstName,
              'lastName': lastName,
              'gender': gender,
              'profileImageUrl': profileImagePath,
              'isAdmin': isAdmin,
              'role': isAdmin
                  ? 'teacher'
                  : ((email.toLowerCase() == _superAdminEmail) ? 'super_admin' : 'student'),
              'createdAt': ServerValue.timestamp,
            };

            await FirebaseDatabase.instance.ref().child('users/${currentUser!.uid}').set(userData);

            // Save to SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('first_name', firstName);
            await prefs.setString('last_name', lastName);
            await prefs.setString('gender', gender);
            await prefs.setBool('has_completed_profile', true);

            debugPrint('User data saved successfully after type error recovery');

            // Sync user progress to Firebase after successful registration
            try {
              await _firebaseSync.syncUserProgressToFirebase();
              debugPrint('User progress synced to Firebase after registration (error recovery)');
            } catch (e) {
              debugPrint('Error syncing user progress after registration (error recovery): $e');
              // Don't throw error, registration was successful
            }

            return; // Registration was successful, ignore the type error
          } catch (dbError) {
            debugPrint('Error saving user data after type error: $dbError');
            throw Exception('Registration completed but failed to save user data: $dbError');
          }
        }
      }

      throw Exception('Unexpected error during registration: $e');
    }
  }

  // Method to manually set admin status (for testing purposes)
  Future<void> setAdminStatus(bool isAdmin) async {
    if (currentUser == null) {
      throw Exception('No user signed in');
    }
    try {
      await FirebaseDatabase.instance.ref().child('users/${currentUser!.uid}/isAdmin').set(isAdmin);
      debugPrint('Admin status set to: $isAdmin for user: ${currentUser!.uid}');
    } catch (e) {
      debugPrint('Error setting admin status: $e');
      throw Exception('Failed to set admin status: $e');
    }
  }

  // Sign out with improved error handling
  Future<void> signOut() async {
    try {
      debugPrint('Signing out user: ${currentUser?.uid}');

      // Log logout activity before signing out
      try {
        final userRole = await getUserRole();
        debugPrint('Attempting to log logout activity for role: $userRole');

        if (userRole == 'teacher') {
          await _teacherActivityService.logLogout();
          debugPrint('Teacher logout activity logged successfully');
        } else if (userRole == 'super_admin') {
          // Super admins are also teachers, so log as teacher activity
          await _teacherActivityService.logLogout();
          debugPrint('Super admin logout activity logged as teacher');
        } else {
          await _userActivityService.logLogout();
          debugPrint('Student logout activity logged successfully');
        }
      } catch (e) {
        debugPrint('Error logging logout activity: $e');
        // Don't throw error, continue with sign out
      }

      // Set user as offline in Firebase before signing out
      try {
        await _firebaseSync.setUserOffline();
        debugPrint('User set as offline in Firebase');
      } catch (e) {
        debugPrint('Error setting user offline: $e');
        // Don't throw error, continue with sign out
      }

      // Clear Firebase listeners and cache before signing out
      _firebaseSync.clearUserData();
      debugPrint('Firebase listeners and cache cleared');

      // Reset ALL services to clear in-memory data
      ProgressService().reset();
      ChallengeProgressService().reset();
      CoinService().reset();
      ProfileImageService().reset();
      debugPrint('All services reset');

      // Clear ALL SharedPreferences data to prevent cross-account leakage
      await _clearAllUserData();
      debugPrint('All user data cleared from SharedPreferences');

      await _auth.signOut();
      debugPrint('Sign out successful - user completely logged out');
    } catch (e) {
      debugPrint('Sign out error: $e');
      throw Exception('Sign out failed: $e');
    }
  }

  /// Send password reset email to the specified email address
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('Sending password reset email to: $email');

      // Validate email format
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim())) {
        throw Exception('Please enter a valid email address.');
      }

      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('Password reset email sent successfully');
    } catch (e) {
      debugPrint('Error sending password reset email: $e');

      // Handle specific Firebase Auth errors
      String errorMessage;
      switch (e.toString()) {
        case 'user-not-found':
          errorMessage = 'No account found with this email address.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection and try again.';
          break;
        default:
          if (e.toString().contains('user-not-found')) {
            errorMessage = 'No account found with this email address.';
          } else if (e.toString().contains('invalid-email')) {
            errorMessage = 'Please enter a valid email address.';
          } else if (e.toString().contains('too-many-requests')) {
            errorMessage = 'Too many requests. Please try again later.';
          } else if (e.toString().contains('network')) {
            errorMessage = 'Network error. Please check your connection and try again.';
          } else {
            errorMessage = 'Failed to send password reset email. Please try again.';
          }
      }

      throw Exception(errorMessage);
    }
  }

  // Set user as online in leaderboard
  Future<void> _setUserOnline() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get user data from Firebase to include in leaderboard
      final userSnapshot = await FirebaseDatabase.instance.ref().child('users/${user.uid}').get();
      Map<String, dynamic> userData = {};

      if (userSnapshot.exists) {
        userData = Map<String, dynamic>.from(userSnapshot.value as Map);
      }

      // Update online status and last active time
      userData['isOnline'] = true;
      userData['lastActive'] = ServerValue.timestamp;

      // Ensure required fields for leaderboard
      userData['userId'] = user.uid;
      userData['displayName'] = userData['displayName'] ?? user.displayName ?? 'User';
      userData['totalXp'] = userData['totalXp'] ?? 0;
      userData['level'] = userData['level'] ?? 1;
      userData['rank'] = userData['rank'] ?? 'Rookie';
      userData['rankBadge'] = userData['rankBadge'] ?? '🌱';
      userData['currentStreak'] = userData['currentStreak'] ?? 0;

      // Update both users and leaderboard paths
      await FirebaseDatabase.instance.ref().child('users/${user.uid}').update({
        'isOnline': true,
        'lastActive': ServerValue.timestamp,
      });

      await FirebaseDatabase.instance.ref().child('leaderboard/${user.uid}').set(userData);

      debugPrint('User set as online: ${user.uid}');
    } catch (e) {
      debugPrint('Error setting user online: $e');
    }
  }

  // Clear ALL user data from SharedPreferences (used during logout)
  Future<void> _clearAllUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      debugPrint('Clearing all user data from SharedPreferences (${allKeys.length} keys)');

      for (final key in allKeys) {
        // Keep only system settings, clear ALL user progress data including last_user_id
        if (!key.startsWith('setting_') &&
            !key.startsWith('app_') &&
            !key.startsWith('theme_') &&
            !key.startsWith('language_') &&
            !key.startsWith('notification_')) {
          await prefs.remove(key);
          debugPrint('Removed key: $key');
        }
      }

      debugPrint('All user data cleared from SharedPreferences');
    } catch (e) {
      debugPrint('Error clearing all user data: $e');
      // Don't throw error, continue with logout
    }
  }

  // Clear previous user's data when switching users
  Future<void> _clearPreviousUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Store current user ID to check if it changed
      final currentUserId = currentUser?.uid;
      final lastUserId = prefs.getString('last_user_id');

      // If user ID changed, clear all user-specific data
      if (lastUserId != null && lastUserId != currentUserId) {
        debugPrint('User changed from $lastUserId to $currentUserId - clearing previous user data');

        // Clear all user-specific data
        final allKeys = prefs.getKeys();
        for (final key in allKeys) {
          // Keep only system settings, clear user progress data
          if (!key.startsWith('setting_') &&
              !key.startsWith('last_user_id') &&
              !key.startsWith('app_') &&
              !key.startsWith('theme_') &&
              !key.startsWith('language_') &&
              !key.startsWith('notification_')) {
            await prefs.remove(key);
          }
        }

        debugPrint('Previous user data cleared');
      }

      // Always update last user ID to current user
      if (currentUserId != null) {
        await prefs.setString('last_user_id', currentUserId);
        debugPrint('Updated last_user_id to: $currentUserId');
      }
    } catch (e) {
      debugPrint('Error clearing previous user data: $e');
      // Don't throw error, continue with login
    }
  }

  // Update profile image with improved error handling
  Future<void> updateProfileImage(String imagePath) async {
    try {
      if (currentUser == null) {
        debugPrint('No user signed in for profile image update');
        throw Exception('No user signed in');
      }

      debugPrint('Uploading profile image for user: ${currentUser!.uid}');

      final storageRef = FirebaseStorage.instance.ref().child('profile_images/${currentUser!.uid}');

      await storageRef.putFile(File(imagePath));
      final profileImageUrl = await storageRef.getDownloadURL();

      await FirebaseDatabase.instance
          .ref()
          .child('users/${currentUser!.uid}/profileImageUrl')
          .set(profileImageUrl);

      debugPrint('Profile image updated: $profileImageUrl');
    } catch (e) {
      debugPrint('Profile image update error: $e');
      throw Exception('Failed to update profile image: $e');
    }
  }

  // Get user data from Firebase
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      if (currentUser == null) {
        debugPrint('No user signed in for getUserData');
        return null;
      }

      final snapshot =
          await FirebaseDatabase.instance.ref().child('users/${currentUser!.uid}').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return Map<String, dynamic>.from(data);
      }

      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  // Update user data in Firebase
  Future<void> updateUserData(Map<String, dynamic> userData) async {
    try {
      if (currentUser == null) {
        throw Exception('No user signed in');
      }

      userData['updatedAt'] = ServerValue.timestamp;

      await FirebaseDatabase.instance.ref().child('users/${currentUser!.uid}').update(userData);

      debugPrint('User data updated successfully');
    } catch (e) {
      debugPrint('Error updating user data: $e');
      throw Exception('Failed to update user data: $e');
    }
  }
}
