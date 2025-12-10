import 'package:nihongo_japanese_app/services/database_service.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChallengeProgressService {
  static final ChallengeProgressService _instance = ChallengeProgressService._internal();
  static SharedPreferences? _prefs;

  factory ChallengeProgressService() {
    return _instance;
  }

  ChallengeProgressService._internal();

  // Reset service (useful when user changes)
  void reset() {
    _prefs = null;
    print('ChallengeProgressService reset for user change');
  }

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Save completed challenge
  Future<void> saveCompletedChallenge(String topicId, String challengeId) async {
    final prefs = await this.prefs;
    final completedKey = 'completed_challenges_$topicId';
    final completedChallenges = prefs.getStringList(completedKey) ?? [];

    if (!completedChallenges.contains(challengeId)) {
      completedChallenges.add(challengeId);
      await prefs.setStringList(completedKey, completedChallenges);
    }
  }

  // Check if a challenge is completed
  Future<bool> isChallengeCompleted(String topicId, String challengeId) async {
    final prefs = await this.prefs;
    final completedKey = 'completed_challenges_$topicId';
    final completedChallenges = prefs.getStringList(completedKey) ?? [];
    return completedChallenges.contains(challengeId);
  }

  // Get completed challenges for a topic
  Future<List<String>> getCompletedChallengesForTopic(String topicId) async {
    final prefs = await this.prefs;
    final completedKey = 'completed_challenges_$topicId';
    return prefs.getStringList(completedKey) ?? [];
  }

  // Save score for a topic
  Future<void> saveTopicScore(String topicId, int score) async {
    final prefs = await this.prefs;
    final scoreKey = 'topic_score_$topicId';
    await prefs.setInt(scoreKey, score);
  }

  // Get score for a topic
  Future<int> getTopicScore(String topicId) async {
    final prefs = await this.prefs;
    final scoreKey = 'topic_score_$topicId';
    return prefs.getInt(scoreKey) ?? 0;
  }

  // Save streak for a topic
  Future<void> saveTopicStreak(String topicId, int streak) async {
    final prefs = await this.prefs;
    final streakKey = 'topic_streak_$topicId';
    await prefs.setInt(streakKey, streak);
  }

  // Get streak for a topic
  Future<int> getTopicStreak(String topicId) async {
    final prefs = await this.prefs;
    final streakKey = 'topic_streak_$topicId';
    return prefs.getInt(streakKey) ?? 0;
  }

  // Save last completed challenge ID for a topic
  Future<void> saveLastCompletedChallenge(String topicId, String challengeId) async {
    final prefs = await this.prefs;
    final lastChallengeKey = 'last_challenge_$topicId';
    await prefs.setString(lastChallengeKey, challengeId);
  }

  // Get last completed challenge ID for a topic
  Future<String?> getLastCompletedChallenge(String topicId) async {
    final prefs = await this.prefs;
    final lastChallengeKey = 'last_challenge_$topicId';
    return prefs.getString(lastChallengeKey);
  }

  // Save overall progress
  Future<void> saveOverallProgress({
    required int totalScore,
    required int totalChallengesCompleted,
    required int totalTopicsCompleted,
  }) async {
    final prefs = await this.prefs;
    await prefs.setInt('total_score', totalScore);
    await prefs.setInt('total_challenges_completed', totalChallengesCompleted);
    await prefs.setInt('total_topics_completed', totalTopicsCompleted);

    // Sync to Firebase
    final firebaseSync = FirebaseUserSyncService();
    await firebaseSync.syncUserProgressToFirebase();
  }

  // Get overall progress
  Future<Map<String, int>> getOverallProgress() async {
    final prefs = await this.prefs;
    return {
      'total_score': prefs.getInt('total_score') ?? 0,
      'total_challenges_completed': prefs.getInt('total_challenges_completed') ?? 0,
      'total_topics_completed': prefs.getInt('total_topics_completed') ?? 0,
    };
  }

  // Save streak bonus for a topic
  Future<void> saveTopicStreakBonus(String topicId, int streakBonus) async {
    final prefs = await this.prefs;
    final streakBonusKey = 'topic_streak_bonus_$topicId';
    await prefs.setInt(streakBonusKey, streakBonus);
  }

  // Get streak bonus for a topic
  Future<int> getTopicStreakBonus(String topicId) async {
    final prefs = await this.prefs;
    final streakBonusKey = 'topic_streak_bonus_$topicId';
    return prefs.getInt(streakBonusKey) ?? 0;
  }

  // Reset progress for a topic
  Future<void> resetTopicProgress(String topicId) async {
    final prefs = await this.prefs;
    await prefs.remove('completed_challenges_$topicId');
    await prefs.remove('topic_score_$topicId');
    await prefs.remove('topic_streak_$topicId');
    await prefs.remove('last_challenge_$topicId');
    await prefs.remove('topic_streak_bonus_$topicId');
  }

  // Reset all progress
  Future<void> resetAllProgress() async {
    final prefs = await this.prefs;
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('completed_challenges_') ||
          key.startsWith('topic_score_') ||
          key.startsWith('topic_streak_') ||
          key.startsWith('last_challenge_') ||
          key == 'total_score' ||
          key == 'total_challenges_completed' ||
          key == 'total_topics_completed') {
        await prefs.remove(key);
      }
    }
  }

  Future<void> saveRecentActivity(String topicId, String activityType) async {
    final prefs = await this.prefs;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Save the recent activity with timestamp
    await prefs.setString('recent_activity_type', activityType);
    await prefs.setString('recent_activity_topic', topicId);
    await prefs.setInt('recent_activity_timestamp', timestamp);
  }

  Future<Map<String, dynamic>> getRecentActivity() async {
    final prefs = await this.prefs;

    final activityType = prefs.getString('recent_activity_type');
    final topicId = prefs.getString('recent_activity_topic');
    final timestamp = prefs.getInt('recent_activity_timestamp');

    if (activityType == null || topicId == null || timestamp == null) {
      return {};
    }

    // Get completion status for the topic
    final completedChallenges = await getCompletedChallengesForTopic(topicId);

    // Get actual total challenges from database
    final challenges = await DatabaseService().getChallengesByTopic(topicId);
    final totalChallenges = challenges.length;
    final isCompleted = completedChallenges.length >= totalChallenges;

    return {
      'type': activityType,
      'topicId': topicId,
      'timestamp': timestamp,
      'completedChallenges': completedChallenges.length,
      'totalChallenges': totalChallenges,
      'isCompleted': isCompleted,
    };
  }

  // Get total points across all topics
  Future<int> getTotalPoints() async {
    final prefs = await this.prefs;
    final keys = prefs.getKeys();
    int totalPoints = 0;

    for (var key in keys) {
      if (key.startsWith('topic_score_')) {
        final score = prefs.getInt(key) ?? 0;
        totalPoints += score;
      }
    }

    return totalPoints;
  }
}
