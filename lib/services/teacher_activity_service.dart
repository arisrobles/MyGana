import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class TeacherActivityService {
  static final TeacherActivityService _instance = TeacherActivityService._internal();
  factory TeacherActivityService() => _instance;
  TeacherActivityService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Log a teacher activity
  Future<void> logActivity({
    required String activityType,
    required String title,
    required String description,
    String? relatedId,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final activityId = _database.ref('users/${user.uid}/teacherActivities').push().key!;

    final activityData = {
      'activityType': activityType,
      'title': title,
      'description': description,
      'relatedId': relatedId,
      'metadata': metadata ?? {},
      'timestamp': timestamp,
      'createdAt': ServerValue.timestamp,
    };

    await _database.ref('users/${user.uid}/teacherActivities/$activityId').set(activityData);
  }

  // Get recent activities for the current teacher
  Stream<List<TeacherActivity>> watchRecentActivities({int limit = 10}) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _database
        .ref('users/${user.uid}/teacherActivities')
        .orderByChild('timestamp')
        .limitToLast(limit)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <TeacherActivity>[];
      }

      final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(
        event.snapshot.value as Map,
      );

      final activities = <TeacherActivity>[];
      for (final entry in data.entries) {
        try {
          final activityData = Map<String, dynamic>.from(entry.value);
          activities.add(TeacherActivity.fromMap(entry.key, activityData));
        } catch (e) {
          print('Error parsing activity: $e');
        }
      }

      // Sort by timestamp (newest first) since Firebase doesn't support multiple orderBy
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return activities;
    });
  }

  // Helper methods for common activities
  Future<void> logQuizCreated(String quizId, String quizTitle) async {
    await logActivity(
      activityType: 'quiz_created',
      title: 'Quiz Created',
      description: 'Created quiz: $quizTitle',
      relatedId: quizId,
      metadata: {'quizTitle': quizTitle},
    );
  }

  Future<void> logClassCreated(String classId, String className) async {
    await logActivity(
      activityType: 'class_created',
      title: 'Class Created',
      description: 'Created class: $className',
      relatedId: classId,
      metadata: {'className': className},
    );
  }

  Future<void> logLessonCreated(String lessonId, String lessonTitle, String category) async {
    await logActivity(
      activityType: 'lesson_created',
      title: 'Lesson Created',
      description: 'Created lesson: $lessonTitle',
      relatedId: lessonId,
      metadata: {
        'lessonTitle': lessonTitle,
        'category': category,
      },
    );
  }

  Future<void> logStudentEnrolled(String classId, String studentName) async {
    await logActivity(
      activityType: 'student_enrolled',
      title: 'Student Enrolled',
      description: '$studentName joined your class',
      relatedId: classId,
      metadata: {'studentName': studentName},
    );
  }

  Future<void> logLessonDelivered(String lessonId, String lessonTitle, String className) async {
    await logActivity(
      activityType: 'lesson_delivered',
      title: 'Lesson Delivered',
      description: 'Delivered $lessonTitle to $className',
      relatedId: lessonId,
      metadata: {
        'lessonTitle': lessonTitle,
        'className': className,
      },
    );
  }

  Future<void> logQuizCompleted(String quizId, String quizTitle, int studentCount) async {
    await logActivity(
      activityType: 'quiz_completed',
      title: 'Quiz Completed',
      description: '$studentCount students completed $quizTitle',
      relatedId: quizId,
      metadata: {
        'quizTitle': quizTitle,
        'studentCount': studentCount,
      },
    );
  }

  // Authentication activities
  Future<void> logLogin(String loginMethod) async {
    await logActivity(
      activityType: 'teacher_login',
      title: 'Teacher Login',
      description: 'Teacher logged in successfully',
      metadata: {
        'loginMethod': loginMethod, // 'email', 'google', etc.
        'loginTime': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logLogout() async {
    await logActivity(
      activityType: 'teacher_logout',
      title: 'Teacher Logout',
      description: 'Teacher logged out successfully',
      metadata: {
        'logoutTime': DateTime.now().toIso8601String(),
      },
    );
  }

  // Clear all teacher activities (useful for removing mock data)
  Future<void> clearAllActivities() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _database.ref('users/${user.uid}/teacherActivities').remove();
      print('All teacher activities cleared successfully');
    } catch (e) {
      print('Error clearing teacher activities: $e');
    }
  }
}

class TeacherActivity {
  final String id;
  final String teacherId;
  final String activityType;
  final String title;
  final String description;
  final String? relatedId;
  final Map<String, dynamic> metadata;
  final int timestamp;
  final DateTime createdAt;

  TeacherActivity({
    required this.id,
    required this.teacherId,
    required this.activityType,
    required this.title,
    required this.description,
    this.relatedId,
    required this.metadata,
    required this.timestamp,
    required this.createdAt,
  });

  factory TeacherActivity.fromMap(String id, Map<String, dynamic> map) {
    return TeacherActivity(
      id: id,
      teacherId: '', // teacherId is implicit from the path, not stored in data
      activityType: map['activityType'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      relatedId: map['relatedId'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      timestamp: map['timestamp'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  IconData get icon {
    switch (activityType) {
      case 'quiz_created':
        return Icons.quiz_rounded;
      case 'class_created':
        return Icons.group_rounded;
      case 'lesson_created':
        return Icons.book_rounded;
      case 'category_created':
        return Icons.category_rounded;
      case 'student_enrolled':
        return Icons.person_add_rounded;
      case 'lesson_delivered':
        return Icons.school_rounded;
      case 'quiz_completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.timeline_rounded;
    }
  }

  Color get color {
    switch (activityType) {
      case 'quiz_created':
        return const Color(0xFF8E54E9);
      case 'class_created':
        return const Color(0xFF4776E6);
      case 'lesson_created':
        return const Color(0xFFFF9800);
      case 'category_created':
        return const Color(0xFF9C27B0);
      case 'student_enrolled':
        return const Color(0xFF26A69A);
      case 'lesson_delivered':
        return const Color(0xFF2196F3);
      case 'quiz_completed':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  double get progress {
    switch (activityType) {
      case 'quiz_completed':
        final studentCount = metadata['studentCount'] as int? ?? 0;
        final totalStudents = metadata['totalStudents'] as int? ?? studentCount;
        return totalStudents > 0 ? studentCount / totalStudents : 1.0;
      default:
        return 1.0;
    }
  }

  String get progressText {
    switch (activityType) {
      case 'quiz_completed':
        final studentCount = metadata['studentCount'] as int? ?? 0;
        final totalStudents = metadata['totalStudents'] as int? ?? studentCount;
        return totalStudents > 0 ? '$studentCount/$totalStudents completed' : 'Completed';
      default:
        return 'Completed';
    }
  }
}
