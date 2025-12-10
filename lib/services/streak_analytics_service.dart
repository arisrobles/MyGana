import 'package:nihongo_japanese_app/services/challenge_progress_service.dart';
import 'package:nihongo_japanese_app/services/database_service.dart';
import 'package:nihongo_japanese_app/services/review_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakAnalyticsService {
  static final StreakAnalyticsService _instance = StreakAnalyticsService._internal();
  static SharedPreferences? _prefs;

  factory StreakAnalyticsService() {
    return _instance;
  }

  StreakAnalyticsService._internal();

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Calculate overall streak percentage across all challenges and reviews
  Future<double> getOverallStreakPercentage() async {
    try {
      final challengeStreakData = await _getChallengeStreakData();
      final reviewStreakData = await _getReviewStreakData();

      // Combine all streak data
      final allStreakData = [...challengeStreakData, ...reviewStreakData];

      if (allStreakData.isEmpty) return 0.0;

      // Calculate total attempts and successful streaks
      int totalAttempts = 0;
      int successfulStreaks = 0;

      for (final data in allStreakData) {
        totalAttempts += data['totalAttempts'] as int;
        successfulStreaks += data['successfulStreaks'] as int;
      }

      return totalAttempts > 0 ? (successfulStreaks / totalAttempts) * 100 : 0.0;
    } catch (e) {
      print('Error calculating overall streak percentage: $e');
      return 0.0;
    }
  }

  /// Get streak percentage for challenges only
  Future<double> getChallengeStreakPercentage() async {
    try {
      final challengeStreakData = await _getChallengeStreakData();

      if (challengeStreakData.isEmpty) return 0.0;

      int totalAttempts = 0;
      int successfulStreaks = 0;

      for (final data in challengeStreakData) {
        totalAttempts += data['totalAttempts'] as int;
        successfulStreaks += data['successfulStreaks'] as int;
      }

      return totalAttempts > 0 ? (successfulStreaks / totalAttempts) * 100 : 0.0;
    } catch (e) {
      print('Error calculating challenge streak percentage: $e');
      return 0.0;
    }
  }

  /// Get streak percentage for reviews only
  Future<double> getReviewStreakPercentage() async {
    try {
      final reviewStreakData = await _getReviewStreakData();

      if (reviewStreakData.isEmpty) return 0.0;

      int totalAttempts = 0;
      int successfulStreaks = 0;

      for (final data in reviewStreakData) {
        totalAttempts += data['totalAttempts'] as int;
        successfulStreaks += data['successfulStreaks'] as int;
      }

      return totalAttempts > 0 ? (successfulStreaks / totalAttempts) * 100 : 0.0;
    } catch (e) {
      print('Error calculating review streak percentage: $e');
      return 0.0;
    }
  }

  /// Get detailed streak data for challenges
  Future<List<Map<String, dynamic>>> _getChallengeStreakData() async {
    try {
      final challengeService = ChallengeProgressService();
      final databaseService = DatabaseService();

      // Get all challenge topics
      final topics = await databaseService.getChallengeTopics();
      final streakData = <Map<String, dynamic>>[];

      for (final topic in topics) {
        final topicId = topic['id'] as String;

        // Get completed challenges for this topic
        final completedChallenges = await challengeService.getCompletedChallengesForTopic(topicId);

        // Get all challenges for this topic to calculate total
        final allChallenges = await databaseService.getChallengesByTopic(topicId);

        // Get current streak for this topic
        final currentStreak = await challengeService.getTopicStreak(topicId);

        // Estimate successful streaks based on completed challenges and current streak
        // This is an approximation since we don't store individual question attempts
        final totalAttempts = allChallenges.length;
        final successfulStreaks = completedChallenges.length;

        if (totalAttempts > 0) {
          streakData.add({
            'topicId': topicId,
            'topicName': topic['title'] as String,
            'totalAttempts': totalAttempts,
            'successfulStreaks': successfulStreaks,
            'currentStreak': currentStreak,
            'type': 'challenge',
          });
        }
      }

      return streakData;
    } catch (e) {
      print('Error getting challenge streak data: $e');
      return [];
    }
  }

  /// Get detailed streak data for reviews
  Future<List<Map<String, dynamic>>> _getReviewStreakData() async {
    try {
      final reviewService = ReviewProgressService();
      final databaseService = DatabaseService();

      // Get all flashcard categories
      final categories = await databaseService.getFlashcardCategories();
      final streakData = <Map<String, dynamic>>[];

      for (final category in categories) {
        final categoryId = category['id'] as String;

        // Get streak data for this category
        final currentStreak = await reviewService.getCategoryStreak(categoryId);
        final maxStreak = await reviewService.getCategoryMaxStreak(categoryId);
        final score = await reviewService.getCategoryScore(categoryId);

        // Estimate attempts based on score and streaks
        // This is an approximation since we don't store individual card attempts
        final totalAttempts = score > 0 ? (score / 100).ceil() : 0; // Rough estimate
        final successfulStreaks = maxStreak;

        if (totalAttempts > 0) {
          streakData.add({
            'categoryId': categoryId,
            'categoryName': category['name'] as String,
            'totalAttempts': totalAttempts,
            'successfulStreaks': successfulStreaks,
            'currentStreak': currentStreak,
            'type': 'review',
          });
        }
      }

      return streakData;
    } catch (e) {
      print('Error getting review streak data: $e');
      return [];
    }
  }

  /// Get streak statistics summary
  Future<Map<String, dynamic>> getStreakStatistics() async {
    try {
      final overallPercentage = await getOverallStreakPercentage();
      final challengePercentage = await getChallengeStreakPercentage();
      final reviewPercentage = await getReviewStreakPercentage();

      return {
        'overallPercentage': overallPercentage,
        'challengePercentage': challengePercentage,
        'reviewPercentage': reviewPercentage,
        'overallPercentageFormatted': '${overallPercentage.toStringAsFixed(1)}%',
        'challengePercentageFormatted': '${challengePercentage.toStringAsFixed(1)}%',
        'reviewPercentageFormatted': '${reviewPercentage.toStringAsFixed(1)}%',
      };
    } catch (e) {
      print('Error getting streak statistics: $e');
      return {
        'overallPercentage': 0.0,
        'challengePercentage': 0.0,
        'reviewPercentage': 0.0,
        'overallPercentageFormatted': '0.0%',
        'challengePercentageFormatted': '0.0%',
        'reviewPercentageFormatted': '0.0%',
      };
    }
  }

  /// Get streak performance level based on percentage
  String getStreakPerformanceLevel(double percentage) {
    if (percentage >= 90) return 'Excellent';
    if (percentage >= 80) return 'Great';
    if (percentage >= 70) return 'Good';
    if (percentage >= 60) return 'Fair';
    return 'Needs Improvement';
  }

  /// Get streak performance color based on percentage
  int getStreakPerformanceColor(double percentage) {
    if (percentage >= 90) return 0xFF4CAF50; // Green
    if (percentage >= 80) return 0xFF8BC34A; // Light Green
    if (percentage >= 70) return 0xFFFFC107; // Amber
    if (percentage >= 60) return 0xFFFF9800; // Orange
    return 0xFFF44336; // Red
  }
}
