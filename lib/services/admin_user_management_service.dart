import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:nihongo_japanese_app/firebase_options.dart';

class AdminUserManagementService {
  static const String _secondaryAppName = 'super_admin_secondary';

  Future<FirebaseApp> _ensureSecondaryApp() async {
    try {
      final existing = Firebase.apps.where((a) => a.name == _secondaryAppName);
      if (existing.isNotEmpty) return existing.first;
    } catch (_) {}
    final app = await Firebase.initializeApp(
      name: _secondaryAppName,
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return app;
  }

  Future<void> fixSuperAdminProfile() async {
    try {
      debugPrint('Fixing super admin profile...');
      final db = FirebaseDatabase.instance.ref();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // Update the super admin profile with correct role and isAdmin fields
      await db.child('users/${currentUser.uid}').update({
        'role': 'super_admin',
        'isAdmin': true,
        'email': currentUser.email,
        'lastUpdated': ServerValue.timestamp,
      });

      debugPrint('Super admin profile fixed successfully');

      // Verify the fix
      final userProfileSnapshot = await db.child('users/${currentUser.uid}').get();
      if (userProfileSnapshot.exists) {
        final userProfile = userProfileSnapshot.value as Map<dynamic, dynamic>;
        debugPrint('Updated super admin profile: $userProfile');
      }
    } catch (e) {
      debugPrint('Error fixing super admin profile: $e');
      throw Exception('Failed to fix super admin profile: $e');
    }
  }

  Future<void> testSuperAdminPermissions() async {
    try {
      debugPrint('Testing super admin permissions...');

      // First, let's check what's actually in the super admin's user profile
      final db = FirebaseDatabase.instance.ref();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      debugPrint('Checking super admin profile in Firebase...');
      final userProfileSnapshot = await db.child('users/${currentUser.uid}').get();

      if (userProfileSnapshot.exists) {
        final userProfile = userProfileSnapshot.value as Map<dynamic, dynamic>;
        debugPrint('Super admin profile data: $userProfile');
        debugPrint('Super admin role from Firebase: ${userProfile['role']}');
        debugPrint('Super admin isAdmin from Firebase: ${userProfile['isAdmin']}');
      } else {
        debugPrint('ERROR: Super admin profile not found in Firebase!');
        throw Exception('Super admin profile not found in Firebase database');
      }

      // Test write permission to users path directly (what we actually need)
      final testUid = 'test_${DateTime.now().millisecondsSinceEpoch}';
      await db.child('users/$testUid').set({
        'test': 'super_admin_write_test',
        'timestamp': ServerValue.timestamp,
      });
      debugPrint('Super admin write test successful');

      // Clean up test data
      await db.child('users/$testUid').remove();
      debugPrint('Test data cleaned up');
    } catch (e) {
      debugPrint('Super admin permission test failed: $e');
      throw Exception('Super admin does not have write permissions: $e');
    }
  }

  Future<void> createTeacherAccount({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? gender,
  }) async {
    // Fix super admin profile first
    await fixSuperAdminProfile();

    // Test super admin permissions
    await testSuperAdminPermissions();

    final secondary = await _ensureSecondaryApp();
    final auth = FirebaseAuth.instanceFor(app: secondary);
    try {
      debugPrint('Creating teacher account via secondary app for $email');
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        throw Exception('No UID returned for created teacher');
      }
      debugPrint('Teacher Firebase Auth account created with UID: $uid');

      try {
        await cred.user!.updateDisplayName(
          '${(firstName ?? '').trim()} ${(lastName ?? '').trim()}'.trim(),
        );
      } catch (_) {}

      // Save user profile in primary database using primary app (super admin authenticated)
      final db = FirebaseDatabase.instance.ref();
      debugPrint('Attempting to save teacher profile to database...');

      try {
        await db.child('users/$uid').set({
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'gender': gender ?? 'Prefer not to say',
          'profileImageUrl': null,
          'isAdmin': true,
          'role': 'teacher',
          'createdAt': ServerValue.timestamp,
        });
        debugPrint('Teacher account $email created with role=teacher');

        // Verify the teacher profile was saved correctly
        final verifySnapshot = await db.child('users/$uid').get();
        if (verifySnapshot.exists) {
          final verifyData = verifySnapshot.value as Map<dynamic, dynamic>;
          debugPrint('Teacher profile verification: $verifyData');
          debugPrint('Teacher role: ${verifyData['role']}');
          debugPrint('Teacher isAdmin: ${verifyData['isAdmin']}');

          // Ensure the profile has all required fields for authentication
          if (verifyData['role'] != 'teacher' || verifyData['isAdmin'] != true) {
            debugPrint('WARNING: Teacher profile incomplete, attempting to fix...');
            await db.child('users/$uid').update({
              'role': 'teacher',
              'isAdmin': true,
              'lastUpdated': ServerValue.timestamp,
            });
            debugPrint('Teacher profile fixed');
          }
        } else {
          debugPrint('ERROR: Teacher profile not found after creation!');
          throw Exception('Teacher profile not found after creation');
        }
      } catch (dbError) {
        debugPrint('Database error while saving teacher profile: $dbError');
        // Try to delete the Firebase Auth account if database save failed
        try {
          await cred.user!.delete();
          debugPrint('Deleted Firebase Auth account due to database error');
        } catch (deleteError) {
          debugPrint('Failed to delete Firebase Auth account: $deleteError');
        }
        throw Exception('Failed to save teacher profile: $dbError');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth error: ${e.code} - ${e.message}');
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'This email is already in use.';
          break;
        case 'invalid-email':
          msg = 'Invalid email address.';
          break;
        case 'weak-password':
          msg = 'Password is too weak.';
          break;
        default:
          msg = 'Failed to create teacher: ${e.message}';
      }
      throw Exception(msg);
    } catch (e) {
      debugPrint('Unexpected error creating teacher: $e');

      // Handle type casting errors during registration - ignore if user was created
      if (e.toString().contains('PigeonUserDetails') ||
          e.toString().contains('type cast') ||
          e.toString().contains('List<Object?>')) {
        debugPrint('Type casting error during registration, checking if user was created');

        // Check if the Firebase Auth account was actually created
        try {
          final auth = FirebaseAuth.instanceFor(app: secondary);
          final currentUser = auth.currentUser;
          if (currentUser != null) {
            debugPrint('User was created despite type error: ${currentUser.uid}');

            // Try to save user data to database
            try {
              final db = FirebaseDatabase.instance.ref();
              await db.child('users/${currentUser.uid}').set({
                'email': email,
                'firstName': firstName,
                'lastName': lastName,
                'gender': gender ?? 'Prefer not to say',
                'profileImageUrl': null,
                'isAdmin': true,
                'role': 'teacher',
                'createdAt': ServerValue.timestamp,
              });
              debugPrint('Teacher account $email created with role=teacher');

              // Verify the teacher profile was saved correctly
              final verifySnapshot = await db.child('users/${currentUser.uid}').get();
              if (verifySnapshot.exists) {
                final verifyData = verifySnapshot.value as Map<dynamic, dynamic>;
                debugPrint('Teacher profile verification: $verifyData');
                debugPrint('Teacher role: ${verifyData['role']}');
                debugPrint('Teacher isAdmin: ${verifyData['isAdmin']}');

                // Ensure the profile has all required fields for authentication
                if (verifyData['role'] != 'teacher' || verifyData['isAdmin'] != true) {
                  debugPrint('WARNING: Teacher profile incomplete, attempting to fix...');
                  await db.child('users/${currentUser.uid}').update({
                    'role': 'teacher',
                    'isAdmin': true,
                    'lastUpdated': ServerValue.timestamp,
                  });
                  debugPrint('Teacher profile fixed');
                }
              } else {
                debugPrint('ERROR: Teacher profile not found after creation!');
                throw Exception('Teacher profile not found after creation');
              }

              // Sign out the created user
              await auth.signOut();
              return; // Success!
            } catch (dbError) {
              debugPrint('Database error while saving teacher profile: $dbError');
              throw Exception('Failed to save teacher profile: $dbError');
            }
          }
        } catch (checkError) {
          debugPrint('Error checking if user was created: $checkError');
        }
      }

      throw Exception('Failed to create teacher: $e');
    } finally {
      try {
        await auth.signOut();
      } catch (_) {}
    }
  }
}
