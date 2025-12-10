import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:nihongo_japanese_app/services/system_config_service.dart';

class ClassInfo {
  final String classId;
  final String nameSection;
  final String yearRange;
  final String classCode;
  final String adminId;
  final DateTime createdAt;

  ClassInfo({
    required this.classId,
    required this.nameSection,
    required this.yearRange,
    required this.classCode,
    required this.adminId,
    required this.createdAt,
  });

  factory ClassInfo.fromMap(String id, Map<dynamic, dynamic> data) {
    return ClassInfo(
      classId: id,
      nameSection: data['nameSection'] ?? '',
      yearRange: data['yearRange'] ?? '',
      classCode: data['classCode'] ?? '',
      adminId: data['adminId'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

class StudentProgressSummary {
  final String userId;
  final String displayName;
  final String email;
  final Map<String, dynamic> userStatistics;

  StudentProgressSummary({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.userStatistics,
  });
}

class ClassManagementService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final SystemConfigService _systemConfig = SystemConfigService();

  // Get all classes for the current teacher
  Stream<List<ClassInfo>> watchTeacherClasses() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db.ref('classes').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return <ClassInfo>[];

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final classes = <ClassInfo>[];

      for (final entry in data.entries) {
        final classData = Map<String, dynamic>.from(entry.value as Map);
        if (classData['adminId'] == user.uid) {
          classes.add(ClassInfo.fromMap(entry.key as String, classData));
        }
      }

      // Sort by creation date (newest first)
      classes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return classes;
    });
  }

  // Create a new class
  Future<String> createClass({
    required String nameSection,
    required String yearRange,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final classId = _generateClassId();
    final classCode = _generateClassCode();

    final classData = {
      'classId': classId,
      'nameSection': nameSection,
      'yearRange': yearRange,
      'classCode': classCode,
      'adminId': user.uid,
      'createdAt': ServerValue.timestamp,
    };

    await _db.ref('classes').child(classId).set(classData);
    await _db.ref('classCodes').child(classCode).set({'classId': classId});

    return classId;
  }

  // Generate unique class ID
  String _generateClassId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1000);
    return 'class_${timestamp}_$random';
  }

  // Generate unique class code
  String _generateClassCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Watch class members with their statistics
  Stream<List<StudentProgressSummary>> watchClassMembersWithStats(String classId) {
    return _db.ref('classMembers').child(classId).onValue.asyncMap((event) async {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <StudentProgressSummary>[];
      }
      final dynamic rawMembers = event.snapshot.value;
      final Map<dynamic, dynamic> members =
          rawMembers is Map ? Map<dynamic, dynamic>.from(rawMembers) : <dynamic, dynamic>{};

      final List<StudentProgressSummary> students = [];
      for (final entry in members.entries) {
        final userId = entry.key.toString();
        try {
          // First try to get user data from /users path
          final userSnap = await _db.ref('users').child(userId).get();
          Map<String, dynamic> userData;

          if (userSnap.exists) {
            final dynamic raw = userSnap.value;
            userData = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          } else {
            // Fallback to classMembers data
            final dynamic raw = entry.value;
            userData = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          }

          final displayName = _buildDisplayName(userData);
          final email = userData['email']?.toString() ?? '';

          final Map<String, dynamic> userStatistics = () {
            final dynamic stats = userData['userStatistics'];
            if (stats is Map) {
              try {
                return Map<String, dynamic>.from(stats);
              } catch (_) {
                final Map<String, dynamic> safe = {};
                stats.forEach((k, v) => safe[k.toString()] = v);
                return safe;
              }
            }
            return <String, dynamic>{};
          }();

          students.add(StudentProgressSummary(
            userId: userId,
            displayName: displayName,
            email: email,
            userStatistics: userStatistics,
          ));
        } catch (e) {
          // Error loading member, skip
        }
      }
      return students;
    });
  }

  Stream<ClassInfo?> watchClass(String classId) {
    return _db.ref('classes').child(classId).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return ClassInfo.fromMap(classId, data);
    });
  }

  String _buildDisplayName(Map<dynamic, dynamic> userData) {
    final firstName = userData['firstName']?.toString() ?? '';
    final lastName = userData['lastName']?.toString() ?? '';
    final displayName = userData['displayName']?.toString() ?? '';

    // Try different combinations
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    }
    if (displayName.isNotEmpty) {
      return displayName;
    }
    if (firstName.isNotEmpty) {
      return firstName;
    }
    if (lastName.isNotEmpty) {
      return lastName;
    }

    return 'Student';
  }

  // Delete student account and remove from class
  Future<void> deleteStudentAccount(String classId, String studentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Verify admin permissions
    final classSnap = await _db.ref('classes').child(classId).get();
    if (!classSnap.exists) throw Exception('Class not found');

    final classData = Map<String, dynamic>.from(classSnap.value as Map);
    if (classData['adminId'] != user.uid) {
      throw Exception('Not authorized to remove students from this class');
    }

    // Remove from class
    await _db.ref('classMembers').child(classId).child(studentId).remove();
    await _db.ref('userClasses').child(studentId).child(classId).remove();

    // Delete user account
    await _db.ref('users').child(studentId).remove();
  }

  // Get top student in a class
  Future<StudentProgressSummary?> getTopStudent(String classId) async {
    final students = await watchClassMembersWithStats(classId).first;
    if (students.isEmpty) return null;

    // Sort by total points (descending)
    students.sort((a, b) {
      final aPoints = (a.userStatistics['totalPoints'] as num?)?.toInt() ?? 0;
      final bPoints = (b.userStatistics['totalPoints'] as num?)?.toInt() ?? 0;
      return bPoints.compareTo(aPoints);
    });

    // Return top 10 (or all if less than 10)
    return students.take(10).toList().isNotEmpty ? students.first : null;
  }

  // Alias for watchTeacherClasses (for backward compatibility)
  Stream<List<ClassInfo>> watchAdminClasses() {
    return watchTeacherClasses();
  }

  // Enroll current user in a class using class code
  Future<void> enrollCurrentUserWithCode(String classCode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Find class by code
    final classCodeSnap = await _db.ref('classCodes').child(classCode).get();
    if (!classCodeSnap.exists) {
      throw Exception('Invalid class code');
    }

    final classId = classCodeSnap.value as String;

    // Check if class exists
    final classSnap = await _db.ref('classes').child(classId).get();
    if (!classSnap.exists) {
      throw Exception('Class not found');
    }

    // Check if user is already enrolled
    final memberSnap = await _db.ref('classMembers').child(classId).child(user.uid).get();
    if (memberSnap.exists) {
      throw Exception('Already enrolled in this class');
    }

    // Check max users per class limit
    final maxUsersPerClass = await _systemConfig.getMaxUsersPerClass();
    final currentMembersSnap = await _db.ref('classMembers').child(classId).get();
    final currentMemberCount = currentMembersSnap.exists ? currentMembersSnap.children.length : 0;

    if (currentMemberCount >= maxUsersPerClass) {
      throw Exception('Class is full. Maximum $maxUsersPerClass students allowed.');
    }

    // Enroll user in class
    final updates = <String, dynamic>{};
    updates['classMembers/$classId/${user.uid}'] = {
      'joinedAt': ServerValue.timestamp,
      'enrolledBy': user.uid,
    };
    updates['userClasses/${user.uid}/$classId'] = {
      'joinedAt': ServerValue.timestamp,
      'enrolledBy': user.uid,
    };
    updates['users/${user.uid}/classId'] = classId;

    await _db.ref().update(updates);
  }

  // Get class capacity information
  Future<Map<String, dynamic>> getClassCapacityInfo(String classId) async {
    final maxUsersPerClass = await _systemConfig.getMaxUsersPerClass();
    final currentMembersSnap = await _db.ref('classMembers').child(classId).get();
    final currentMemberCount = currentMembersSnap.exists ? currentMembersSnap.children.length : 0;

    return {
      'currentCount': currentMemberCount,
      'maxCount': maxUsersPerClass,
      'isFull': currentMemberCount >= maxUsersPerClass,
      'remainingSlots': maxUsersPerClass - currentMemberCount,
      'capacityPercentage': (currentMemberCount / maxUsersPerClass * 100).round(),
    };
  }

  // Check if class has available slots
  Future<bool> hasAvailableSlots(String classId) async {
    final capacityInfo = await getClassCapacityInfo(classId);
    return !capacityInfo['isFull'];
  }
}
