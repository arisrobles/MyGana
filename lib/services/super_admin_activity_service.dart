import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class SuperAdminActivityService {
  static final SuperAdminActivityService _instance = SuperAdminActivityService._internal();
  factory SuperAdminActivityService() => _instance;
  SuperAdminActivityService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Get all activities from both students and teachers
  Stream<List<SuperAdminActivity>> watchAllActivities({int limit = 50}) {
    return Stream.periodic(const Duration(seconds: 3)).asyncMap((_) async {
      try {
        final allActivities = <SuperAdminActivity>[];

        // Get student activities from userActivity/{userId}
        try {
          final userActivitySnapshot = await _database.ref('userActivity').get();
          if (userActivitySnapshot.exists) {
            final userActivities = userActivitySnapshot.value as Map<dynamic, dynamic>?;
            if (userActivities != null) {
              for (final userEntry in userActivities.entries) {
                final userId = userEntry.key.toString();
                final userActivitiesData = userEntry.value as Map<dynamic, dynamic>?;

                if (userActivitiesData != null) {
                  for (final activityEntry in userActivitiesData.entries) {
                    try {
                      final activityData = Map<String, dynamic>.from(activityEntry.value);
                      allActivities.add(SuperAdminActivity.fromStudentActivity(
                        activityEntry.key,
                        userId,
                        activityData,
                      ));
                    } catch (e) {
                      debugPrint('Error parsing student activity: $e');
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error reading student activities: $e');
        }

        // Get teacher activities from users/{teacherId}/teacherActivities
        try {
          final usersSnapshot = await _database.ref('users').get();
          if (usersSnapshot.exists) {
            final users = usersSnapshot.value as Map<dynamic, dynamic>?;
            if (users != null) {
              for (final userEntry in users.entries) {
                final userId = userEntry.key.toString();
                final userData = userEntry.value as Map<dynamic, dynamic>?;

                if (userData != null) {
                  final role = userData['role']?.toString();
                  if (role == 'teacher' || userData['isAdmin'] == true) {
                    final teacherActivities =
                        userData['teacherActivities'] as Map<dynamic, dynamic>?;

                    if (teacherActivities != null) {
                      for (final activityEntry in teacherActivities.entries) {
                        try {
                          final activityData = Map<String, dynamic>.from(activityEntry.value);
                          allActivities.add(SuperAdminActivity.fromTeacherActivity(
                            activityEntry.key,
                            userId,
                            activityData,
                          ));
                        } catch (e) {
                          debugPrint('Error parsing teacher activity: $e');
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error reading teacher activities: $e');
        }

        // If no activities found, return empty list (no sample data)
        if (allActivities.isEmpty) {
          debugPrint('No activities found in database');
          return <SuperAdminActivity>[];
        }

        // Sort by timestamp (newest first) and limit
        allActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return allActivities.take(limit).toList();
      } catch (e) {
        debugPrint('Error loading all activities: $e');
        return <SuperAdminActivity>[];
      }
    });
  }

  // Get activities filtered by user role
  Stream<List<SuperAdminActivity>> watchActivitiesByRole(String role, {int limit = 30}) {
    return watchAllActivities(limit: 100).map((activities) {
      return activities.where((activity) => activity.userRole == role).take(limit).toList();
    });
  }

  // Get activities filtered by activity type
  Stream<List<SuperAdminActivity>> watchActivitiesByType(String activityType, {int limit = 30}) {
    return watchAllActivities(limit: 100).map((activities) {
      return activities
          .where((activity) => activity.activityType == activityType)
          .take(limit)
          .toList();
    });
  }

  // Get recent student activities
  Stream<List<SuperAdminActivity>> watchRecentStudentActivities({int limit = 20}) {
    return watchActivitiesByRole('student', limit: limit);
  }

  // Get recent teacher activities
  Stream<List<SuperAdminActivity>> watchRecentTeacherActivities({int limit = 20}) {
    return watchActivitiesByRole('teacher', limit: limit);
  }

  // Get activity statistics
  Future<ActivityStats> getActivityStats() async {
    try {
      final activities = await watchAllActivities(limit: 1000).first;

      int studentActivities = 0;
      int teacherActivities = 0;
      final Map<String, int> activityTypeCounts = {};
      final Map<String, int> userActivityCounts = {};

      for (final activity in activities) {
        if (activity.userRole == 'student') {
          studentActivities++;
        } else if (activity.userRole == 'teacher') {
          teacherActivities++;
        }

        activityTypeCounts[activity.activityType] =
            (activityTypeCounts[activity.activityType] ?? 0) + 1;
        userActivityCounts[activity.userId] = (userActivityCounts[activity.userId] ?? 0) + 1;
      }

      return ActivityStats(
        totalActivities: activities.length,
        studentActivities: studentActivities,
        teacherActivities: teacherActivities,
        activityTypeCounts: activityTypeCounts,
        mostActiveUsers: userActivityCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..take(5),
      );
    } catch (e) {
      debugPrint('Error getting activity stats: $e');
      return ActivityStats(
        totalActivities: 0,
        studentActivities: 0,
        teacherActivities: 0,
        activityTypeCounts: {},
        mostActiveUsers: [],
      );
    }
  }
}

class SuperAdminActivity {
  final String id;
  final String userId;
  final String userRole; // 'student' or 'teacher'
  final String userName;
  final String activityType;
  final String title;
  final String description;
  final String? relatedId;
  final Map<String, dynamic> metadata;
  final int timestamp;
  final DateTime createdAt;

  SuperAdminActivity({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.userName,
    required this.activityType,
    required this.title,
    required this.description,
    this.relatedId,
    required this.metadata,
    required this.timestamp,
    required this.createdAt,
  });

  factory SuperAdminActivity.fromStudentActivity(
    String id,
    String userId,
    Map<String, dynamic> data,
  ) {
    return SuperAdminActivity(
      id: id,
      userId: userId,
      userRole: 'student',
      userName: data['userName'] ?? 'Student ${userId.substring(0, 8)}...',
      activityType: data['activityType'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      relatedId: data['relatedId'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      timestamp: data['timestamp'] ?? 0,
      createdAt: data['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'])
          : DateTime.now(),
    );
  }

  factory SuperAdminActivity.fromTeacherActivity(
    String id,
    String userId,
    Map<String, dynamic> data,
  ) {
    return SuperAdminActivity(
      id: id,
      userId: userId,
      userRole: 'teacher',
      userName: data['userName'] ?? 'Teacher ${userId.substring(0, 8)}...',
      activityType: data['activityType'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      relatedId: data['relatedId'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      timestamp: data['timestamp'] ?? 0,
      createdAt: data['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'])
          : DateTime.now(),
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
      // Student activities
      case 'lesson_completed':
        return Icons.menu_book;
      case 'quiz_completed':
        return Icons.quiz;
      case 'review_completed':
        return Icons.refresh;
      case 'character_practice':
        return Icons.edit;
      case 'story_read':
        return Icons.book;
      case 'challenge_completed':
        return Icons.emoji_events;
      case 'daily_goal_achieved':
        return Icons.flag;
      case 'level_up':
        return Icons.trending_up;
      case 'user_login':
        return Icons.login;
      case 'user_logout':
        return Icons.logout;

      // Teacher activities
      case 'quiz_created':
        return Icons.add_box;
      case 'class_created':
        return Icons.group_add;
      case 'lesson_created':
        return Icons.add_circle;
      case 'student_enrolled':
        return Icons.person_add;
      case 'lesson_delivered':
        return Icons.school;
      case 'teacher_login':
        return Icons.login;
      case 'teacher_logout':
        return Icons.logout;

      default:
        return Icons.timeline;
    }
  }

  Color get color {
    switch (activityType) {
      // Student activities - Blue tones
      case 'lesson_completed':
        return const Color(0xFF2196F3);
      case 'quiz_completed':
        return const Color(0xFF1976D2);
      case 'review_completed':
        return const Color(0xFF1565C0);
      case 'character_practice':
        return const Color(0xFF0D47A1);
      case 'story_read':
        return const Color(0xFF42A5F5);
      case 'challenge_completed':
        return const Color(0xFF1E88E5);
      case 'daily_goal_achieved':
        return const Color(0xFF21CBF3);
      case 'level_up':
        return const Color(0xFF00BCD4);

      // Teacher activities - Green tones
      case 'quiz_created':
        return const Color(0xFF4CAF50);
      case 'class_created':
        return const Color(0xFF388E3C);
      case 'lesson_created':
        return const Color(0xFF2E7D32);
      case 'student_enrolled':
        return const Color(0xFF1B5E20);
      case 'lesson_delivered':
        return const Color(0xFF66BB6A);

      // Authentication - Orange tones
      case 'user_login':
      case 'teacher_login':
        return const Color(0xFFFF9800);
      case 'user_logout':
      case 'teacher_logout':
        return const Color(0xFFF57C00);

      default:
        return const Color(0xFF757575);
    }
  }

  String get formattedDescription {
    switch (activityType) {
      case 'quiz_completed':
        final score = metadata['score'] as int? ?? 0;
        final total = metadata['totalQuestions'] as int? ?? 0;
        final percentage = metadata['percentage'] as int? ?? 0;
        return '$description (Score: $score/$total - $percentage%)';
      case 'character_practice':
        final score = metadata['score'] as int? ?? 0;
        return '$description (Score: $score)';
      case 'story_read':
        final pagesRead = metadata['pagesRead'] as int? ?? 0;
        final totalPages = metadata['totalPages'] as int? ?? 0;
        return '$description ($pagesRead/$totalPages pages)';
      default:
        return description;
    }
  }
}

class ActivityStats {
  final int totalActivities;
  final int studentActivities;
  final int teacherActivities;
  final Map<String, int> activityTypeCounts;
  final List<MapEntry<String, int>> mostActiveUsers;

  ActivityStats({
    required this.totalActivities,
    required this.studentActivities,
    required this.teacherActivities,
    required this.activityTypeCounts,
    required this.mostActiveUsers,
  });
}
