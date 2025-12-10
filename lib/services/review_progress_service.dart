import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:nihongo_japanese_app/services/user_activity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewProgressService {
  static final ReviewProgressService _instance = ReviewProgressService._internal();
  static SharedPreferences? _prefs;
  final UserActivityService _activityService = UserActivityService();

  factory ReviewProgressService() {
    return _instance;
  }

  ReviewProgressService._internal();

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Save review score for a category
  Future<void> saveCategoryScore(String categoryId, int score) async {
    final prefs = await this.prefs;
    final scoreKey = 'review_score_$categoryId';
    await prefs.setInt(scoreKey, score);

    // Sync to Firebase
    final firebaseSync = FirebaseUserSyncService();
    await firebaseSync.syncUserProgressToFirebase();
  }

  // Get review score for a category
  Future<int> getCategoryScore(String categoryId) async {
    final prefs = await this.prefs;
    final scoreKey = 'review_score_$categoryId';
    return prefs.getInt(scoreKey) ?? 0;
  }

  // Save streak for a category
  Future<void> saveCategoryStreak(String categoryId, int streak) async {
    final prefs = await this.prefs;
    final streakKey = 'review_streak_$categoryId';
    await prefs.setInt(streakKey, streak);
  }

  // Get streak for a category
  Future<int> getCategoryStreak(String categoryId) async {
    final prefs = await this.prefs;
    final streakKey = 'review_streak_$categoryId';
    return prefs.getInt(streakKey) ?? 0;
  }

  // Save max streak for a category
  Future<void> saveCategoryMaxStreak(String categoryId, int maxStreak) async {
    final prefs = await this.prefs;
    final maxStreakKey = 'review_max_streak_$categoryId';
    await prefs.setInt(maxStreakKey, maxStreak);
  }

  // Get max streak for a category
  Future<int> getCategoryMaxStreak(String categoryId) async {
    final prefs = await this.prefs;
    final maxStreakKey = 'review_max_streak_$categoryId';
    return prefs.getInt(maxStreakKey) ?? 0;
  }

  // Save perfect answers count for a category
  Future<void> saveCategoryPerfectAnswers(String categoryId, int perfectAnswers) async {
    final prefs = await this.prefs;
    final perfectAnswersKey = 'review_perfect_answers_$categoryId';
    await prefs.setInt(perfectAnswersKey, perfectAnswers);
  }

  // Get perfect answers count for a category
  Future<int> getCategoryPerfectAnswers(String categoryId) async {
    final prefs = await this.prefs;
    final perfectAnswersKey = 'review_perfect_answers_$categoryId';
    return prefs.getInt(perfectAnswersKey) ?? 0;
  }

  // Save unlocked achievements for a category
  Future<void> saveCategoryAchievements(String categoryId, List<String> achievements) async {
    final prefs = await this.prefs;
    final achievementsKey = 'review_achievements_$categoryId';
    await prefs.setStringList(achievementsKey, achievements);
  }

  // Get unlocked achievements for a category
  Future<List<String>> getCategoryAchievements(String categoryId) async {
    final prefs = await this.prefs;
    final achievementsKey = 'review_achievements_$categoryId';
    return prefs.getStringList(achievementsKey) ?? [];
  }

  // Save completed review for a category
  Future<void> saveCompletedReview(String categoryId) async {
    final prefs = await this.prefs;
    final completedReviewsKey = 'review_completed_$categoryId';
    await prefs.setBool(completedReviewsKey, true);
  }

  // Remove completed review for a category
  Future<void> removeCompletedReview(String categoryId) async {
    final prefs = await this.prefs;
    final completedReviewsKey = 'review_completed_$categoryId';
    await prefs.remove(completedReviewsKey);
  }

  // Get completed reviews for a specific category
  Future<List<String>> getCompletedReviews(String categoryId) async {
    final prefs = await this.prefs;
    final completedReviews = prefs.getStringList('review_completed_$categoryId') ?? [];
    return completedReviews;
  }

  // Get all completed reviews across all categories
  Future<List<String>> getAllCompletedReviews() async {
    final prefs = await this.prefs;
    final allKeys = prefs.getKeys();
    final completedReviews = <String>[];

    for (final key in allKeys) {
      if (key.startsWith('review_completed_')) {
        final categoryId = key.replaceAll('review_completed_', '');
        completedReviews.add(categoryId);
      }
    }

    return completedReviews;
  }

  // Reset progress for a category
  Future<void> resetCategoryProgress(String categoryId) async {
    final prefs = await this.prefs;
    await prefs.remove('review_score_$categoryId');
    await prefs.remove('review_streak_$categoryId');
    await prefs.remove('review_max_streak_$categoryId');
    await prefs.remove('review_perfect_answers_$categoryId');
    await prefs.remove('review_achievements_$categoryId');
    await prefs.remove('review_completed_$categoryId');
  }

  // Get total review points across all categories
  Future<int> getTotalReviewPoints() async {
    final prefs = await this.prefs;
    final keys = prefs.getKeys();
    int totalPoints = 0;

    for (var key in keys) {
      if (key.startsWith('review_score_')) {
        final score = prefs.getInt(key) ?? 0;
        totalPoints += score;
      }
    }

    return totalPoints;
  }

  // Save recent review activity
  Future<void> saveRecentActivity(
    String categoryId, {
    required int score,
    required int correctCount,
    required int totalCards,
    required bool isQuizMode,
  }) async {
    final prefs = await this.prefs;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Debug: Print the category ID being saved
    print('Saving activity for categoryId: $categoryId');

    final activityData = {
      'categoryId': categoryId,
      'score': score,
      'correctCount': correctCount,
      'totalCards': totalCards,
      'isQuizMode': isQuizMode,
      'timestamp': timestamp,
    };

    // Convert to string in a way that preserves the categoryId exactly
    final activityString =
        '{${activityData.entries.map((e) => '${e.key}: ${e.value is String ? e.value : e.value.toString()}').join(', ')}}';

    // Save as the most recent activity
    await prefs.setString('recent_review_activity', activityString);

    // Also save with a unique key to maintain history
    final activityKey = 'recent_review_activity_${categoryId}_$timestamp';
    await prefs.setString(activityKey, activityString);

    // Debug: Print the saved activity string
    print('Saved activity string: $activityString');

    // Limit stored activities to 20 most recent
    await _limitStoredActivities(20);

    // Also save the category and mode for direct navigation
    await saveLastSelectedCategory(categoryId);
    await saveLastSelectedMode(isQuizMode);

    // Log review session activity to Firebase
    await _activityService.logReviewSession(
      categoryId,
      categoryId, // Using categoryId as category name for now
      score,
      totalCards,
    );
  }

  // Helper method to limit the number of stored activities
  Future<void> _limitStoredActivities(int limit) async {
    final prefs = await this.prefs;
    final allKeys =
        prefs.getKeys().where((key) => key.startsWith('recent_review_activity_')).toList();

    if (allKeys.length <= limit) return;

    // Get timestamps from keys
    final keyTimestamps = <String, int>{};
    for (final key in allKeys) {
      final parts = key.split('_');
      if (parts.length >= 4) {
        final timestamp = int.tryParse(parts.last);
        if (timestamp != null) {
          keyTimestamps[key] = timestamp;
        }
      }
    }

    // Sort by timestamp (oldest first)
    final sortedKeys = keyTimestamps.keys.toList()
      ..sort((a, b) => keyTimestamps[a]!.compareTo(keyTimestamps[b]!));

    // Remove oldest entries
    final keysToRemove = sortedKeys.take(sortedKeys.length - limit);
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  // Get recent review activity
  Future<Map<String, dynamic>?> getRecentActivity() async {
    final prefs = await this.prefs;
    final activityString = prefs.getString('recent_review_activity');

    if (activityString == null) return null;

    // Parse the string back into a map
    return _parseActivityString(activityString);
  }

  // Get all recent activities
  Future<List<Map<String, dynamic>>> getAllRecentActivities() async {
    final prefs = await this.prefs;
    final allKeys =
        prefs.getKeys().where((key) => key.startsWith('recent_review_activity_')).toList();

    // Get timestamps from keys for sorting
    final keyTimestamps = <String, int>{};
    for (final key in allKeys) {
      final parts = key.split('_');
      if (parts.length >= 4) {
        final timestamp = int.tryParse(parts.last);
        if (timestamp != null) {
          keyTimestamps[key] = timestamp;
        }
      }
    }

    // Sort by timestamp (newest first)
    final sortedKeys = keyTimestamps.keys.toList()
      ..sort((a, b) => keyTimestamps[b]!.compareTo(keyTimestamps[a]!));

    // Parse each activity string
    final activities = <Map<String, dynamic>>[];
    for (final key in sortedKeys) {
      final activityString = prefs.getString(key);
      if (activityString != null) {
        final activity = _parseActivityString(activityString);
        if (activity != null) {
          activities.add(activity);
        }
      }
    }

    return activities;
  }

  // Helper method to parse activity string
  Map<String, dynamic>? _parseActivityString(String activityString) {
    final pattern = RegExp(r'\{(.*?)\}');
    final match = pattern.firstMatch(activityString);
    if (match == null) return null;

    final pairs = match.group(1)!.split(', ');
    final Map<String, dynamic> result = {};

    for (var pair in pairs) {
      final parts = pair.split(': ');
      if (parts.length != 2) continue;

      final key = parts[0].trim();
      final value = parts[1].trim();

      // Convert values to appropriate types
      if (key == 'timestamp') {
        result[key] = int.tryParse(value) ?? 0;
      } else if (key == 'isQuizMode') {
        result[key] = value.toLowerCase() == 'true';
      } else if (key == 'categoryId') {
        // Make sure to remove any quotes that might be around the categoryId
        // This is critical for proper category matching
        result[key] = value.replaceAll('"', '').replaceAll("'", "");

        // Debug: Print the parsed categoryId
        print('Parsed categoryId: ${result[key]}');
      } else {
        result[key] = int.tryParse(value) ?? 0;
      }
    }

    return result;
  }

  // Get review progress for a category
  Future<Map<String, dynamic>> getCategoryProgress(String categoryId) async {
    final prefs = await this.prefs;
    final score = await getCategoryScore(categoryId);
    final isCompleted = prefs.getBool('review_completed_$categoryId') ?? false;

    return {
      'score': score,
      'isCompleted': isCompleted,
    };
  }

  // Save last selected category
  Future<void> saveLastSelectedCategory(String categoryId) async {
    final prefs = await this.prefs;
    await prefs.setString('last_selected_category', categoryId);
  }

  // Get last selected category
  Future<String?> getLastSelectedCategory() async {
    final prefs = await this.prefs;
    return prefs.getString('last_selected_category');
  }

  // Add method to save last selected mode
  Future<void> saveLastSelectedMode(bool isQuizMode) async {
    final prefs = await this.prefs;
    await prefs.setString('last_selected_mode', isQuizMode ? 'quiz' : 'flashcard');
  }

  // Get last selected mode
  Future<String?> getLastSelectedMode() async {
    final prefs = await this.prefs;
    return prefs.getString('last_selected_mode');
  }
}
