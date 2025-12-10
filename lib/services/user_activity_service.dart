import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class UserActivityService {
  static final UserActivityService _instance = UserActivityService._internal();
  factory UserActivityService() => _instance;
  UserActivityService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Log a user activity
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
    final activityId = _database.ref('userActivity/${user.uid}').push().key!;

    final activityData = {
      'activityType': activityType,
      'title': title,
      'description': description,
      'relatedId': relatedId,
      'metadata': metadata ?? {},
      'timestamp': timestamp,
      'createdAt': ServerValue.timestamp,
      'userId': user.uid,
    };

    try {
      await _database.ref('userActivity/${user.uid}/$activityId').set(activityData);
      debugPrint('User activity logged: $activityType');
    } catch (e) {
      debugPrint('Error logging user activity: $e');
    }
  }

  // Helper methods for common student activities
  Future<void> logLessonCompleted(String lessonId, String lessonTitle, String category) async {
    await logActivity(
      activityType: 'lesson_completed',
      title: 'Lesson Completed',
      description: 'Completed lesson: $lessonTitle',
      relatedId: lessonId,
      metadata: {
        'lessonTitle': lessonTitle,
        'category': category,
      },
    );
  }

  Future<void> logQuizCompleted(
      String quizId, String quizTitle, int score, int totalQuestions) async {
    await logActivity(
      activityType: 'quiz_completed',
      title: 'Quiz Completed',
      description: 'Completed quiz: $quizTitle with score $score/$totalQuestions',
      relatedId: quizId,
      metadata: {
        'quizTitle': quizTitle,
        'score': score,
        'totalQuestions': totalQuestions,
        'percentage': totalQuestions > 0 ? (score / totalQuestions * 100).round() : 0,
      },
    );
  }

  Future<void> logReviewSession(
      String categoryId, String categoryName, int score, int totalCards) async {
    await logActivity(
      activityType: 'review_completed',
      title: 'Review Session Completed',
      description: 'Completed review session: $categoryName',
      relatedId: categoryId,
      metadata: {
        'categoryName': categoryName,
        'score': score,
        'totalCards': totalCards,
        'percentage': totalCards > 0 ? (score / totalCards * 100).round() : 0,
      },
    );
  }

  Future<void> logCharacterPractice(String character, String script, double score) async {
    await logActivity(
      activityType: 'character_practice',
      title: 'Character Practice',
      description: 'Practiced character: $character ($script)',
      relatedId: character,
      metadata: {
        'character': character,
        'script': script,
        'score': score.round(),
      },
    );
  }

  Future<void> logStoryRead(
      String storyId, String storyTitle, int pagesRead, int totalPages) async {
    await logActivity(
      activityType: 'story_read',
      title: 'Story Read',
      description: 'Read story: $storyTitle',
      relatedId: storyId,
      metadata: {
        'storyTitle': storyTitle,
        'pagesRead': pagesRead,
        'totalPages': totalPages,
        'completionPercentage': totalPages > 0 ? (pagesRead / totalPages * 100).round() : 0,
      },
    );
  }

  Future<void> logChallengeCompleted(
      String topicId, String topicName, int score, int totalChallenges) async {
    await logActivity(
      activityType: 'challenge_completed',
      title: 'Challenge Completed',
      description: 'Completed challenge: $topicName',
      relatedId: topicId,
      metadata: {
        'topicName': topicName,
        'score': score,
        'totalChallenges': totalChallenges,
      },
    );
  }

  Future<void> logDailyGoalAchieved(int xpGained, int streakDays) async {
    await logActivity(
      activityType: 'daily_goal_achieved',
      title: 'Daily Goal Achieved',
      description: 'Achieved daily learning goal',
      metadata: {
        'xpGained': xpGained,
        'streakDays': streakDays,
      },
    );
  }

  Future<void> logLevelUp(int newLevel, int totalXp) async {
    await logActivity(
      activityType: 'level_up',
      title: 'Level Up!',
      description: 'Reached level $newLevel',
      metadata: {
        'newLevel': newLevel,
        'totalXp': totalXp,
      },
    );
  }

  // Authentication activities
  Future<void> logLogin(String loginMethod) async {
    await logActivity(
      activityType: 'user_login',
      title: 'User Login',
      description: 'Logged in successfully',
      metadata: {
        'loginMethod': loginMethod, // 'email', 'google', 'anonymous', etc.
        'loginTime': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logLogout() async {
    await logActivity(
      activityType: 'user_logout',
      title: 'User Logout',
      description: 'Logged out successfully',
      metadata: {
        'logoutTime': DateTime.now().toIso8601String(),
      },
    );
  }

  // Get recent activities for the current user
  Stream<List<UserActivity>> watchRecentActivities({int limit = 20}) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _database
        .ref('userActivity/${user.uid}')
        .orderByChild('timestamp')
        .limitToLast(limit)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <UserActivity>[];
      }

      final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(
        event.snapshot.value as Map,
      );

      final activities = <UserActivity>[];
      for (final entry in data.entries) {
        try {
          final activityData = Map<String, dynamic>.from(entry.value);
          activities.add(UserActivity.fromMap(entry.key, activityData));
        } catch (e) {
          debugPrint('Error parsing user activity: $e');
        }
      }

      // Sort by timestamp (newest first)
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return activities;
    });
  }

  // Clear all user activities (useful for testing)
  Future<void> clearAllActivities() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _database.ref('userActivity/${user.uid}').remove();
      debugPrint('All user activities cleared successfully');
    } catch (e) {
      debugPrint('Error clearing user activities: $e');
    }
  }
}

class UserActivity {
  final String id;
  final String userId;
  final String activityType;
  final String title;
  final String description;
  final String? relatedId;
  final Map<String, dynamic> metadata;
  final int timestamp;
  final DateTime createdAt;

  UserActivity({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.title,
    required this.description,
    this.relatedId,
    required this.metadata,
    required this.timestamp,
    required this.createdAt,
  });

  factory UserActivity.fromMap(String id, Map<String, dynamic> data) {
    return UserActivity(
      id: id,
      userId: data['userId'] ?? '',
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

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'activityType': activityType,
      'title': title,
      'description': description,
      'relatedId': relatedId,
      'metadata': metadata,
      'timestamp': timestamp,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
