import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nihongo_japanese_app/models/japanese_character.dart';
import 'package:nihongo_japanese_app/models/progress_model.dart';
import 'package:nihongo_japanese_app/models/story.dart';
import 'package:nihongo_japanese_app/models/user_progress.dart';
import 'package:nihongo_japanese_app/services/database_service.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:nihongo_japanese_app/services/user_activity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService() => _instance;

  ProgressService._internal();

  UserProgress _userProgress = UserProgress();
  Progress? _dashboardProgress;
  bool _isInitialized = false;
  final FirebaseUserSyncService _firebaseSync = FirebaseUserSyncService();
  final UserActivityService _activityService = UserActivityService();
  final ValueNotifier<int> _progressTicks = ValueNotifier<int>(0);

  ValueListenable<int> get progressTicks => _progressTicks;

  // Reset progress service (useful when user changes)
  void reset() {
    _userProgress = UserProgress();
    _dashboardProgress = null;
    _isInitialized = false;
    _progressTicks.value = 0;
    print('ProgressService reset for user change');
  }

  // Initialize progress from storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final progressJson = prefs.getString('user_progress');

      if (progressJson != null) {
        // Deserialize progress data
        final Map<String, dynamic> data = jsonDecode(progressJson);

        // Character progress
        if (data.containsKey('characterProgress')) {
          final Map<String, dynamic> charProgress = data['characterProgress'];
          charProgress.forEach((char, progress) {
            final Map<String, dynamic> progressData = progress;
            final characterProgress = CharacterProgress(
              character: char,
              characterType: progressData['characterType'],
            );
            characterProgress.masteryLevel = progressData['masteryLevel'];
            characterProgress.practiceCount = progressData['practiceCount'];
            characterProgress.lastPracticed = DateTime.parse(progressData['lastPracticed']);

            if (progressData.containsKey('recentEvaluations')) {
              for (var eval in progressData['recentEvaluations']) {
                characterProgress.recentEvaluations.add(
                  StrokeEvaluation(
                    strokeCountScore: eval['strokeCountScore'],
                    strokeOrderScore:
                        eval['strokeOrderScore'] ?? 0.0, // Add default for backward compatibility
                    positionScore: eval['positionScore'],
                    directionScore: eval['directionScore'],
                    overallScore: eval['overallScore'],
                    evaluatedAt: DateTime.parse(eval['evaluatedAt']),
                  ),
                );
              }
            }

            _userProgress.characterProgress[char] = characterProgress;
          });
        }

        // Story progress
        if (data.containsKey('storyProgress')) {
          final Map<String, dynamic> storyProgress = data['storyProgress'];
          storyProgress.forEach((storyId, progress) {
            final Map<String, dynamic> progressData = progress;
            final storyProg = StoryProgress(storyId: storyId);
            storyProg.pagesRead = progressData['pagesRead'];
            storyProg.completed = progressData['completed'];
            storyProg.vocabularyLearned = progressData['vocabularyLearned'];
            storyProg.lastRead = DateTime.parse(progressData['lastRead']);

            _userProgress.storyProgress[storyId] = storyProg;
          });
        }

        // Quiz results
        if (data.containsKey('quizResults')) {
          for (var result in data['quizResults']) {
            _userProgress.quizResults.add(
              QuizResult(
                quizType: result['quizType'],
                score: result['score'],
                totalQuestions: result['totalQuestions'],
                timeSpent: Duration(seconds: result['timeSpent']),
                completedAt: DateTime.parse(result['completedAt']),
                categories: List<String>.from(result['categories']),
              ),
            );
          }
        }

        // Overall stats
        if (data.containsKey('totalXp')) {
          _userProgress.totalXp = data['totalXp'];
        }
        if (data.containsKey('currentStreak')) {
          _userProgress.currentStreak = data['currentStreak'];
        }
        if (data.containsKey('longestStreak')) {
          _userProgress.longestStreak = data['longestStreak'];
        }
        if (data.containsKey('level')) {
          _userProgress.level = data['level'];
        }
      }

      // Load dashboard progress
      final dashboardJson = prefs.getString('dashboard_progress');
      if (dashboardJson != null) {
        _dashboardProgress = Progress.fromJson(json.decode(dashboardJson));
      } else {
        _dashboardProgress = await _createDefaultDashboardProgress();
      }

      // Check if we need to reset daily progress (new day)
      await _checkDailyReset();
    } catch (e) {
      print('Error loading progress: $e');
      // If there's an error, start with fresh progress
      _userProgress = UserProgress();
      _dashboardProgress = await _createDefaultDashboardProgress();
    }

    _isInitialized = true;

    // Sync to Firebase after initialization
    await _firebaseSync.syncUserProgressToFirebase();
  }

  // Save progress to storage
  Future<void> saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create serializable data structure
      final Map<String, dynamic> data = {
        'characterProgress': {},
        'storyProgress': {},
        'quizResults': [],
        'totalXp': _userProgress.totalXp,
        'currentStreak': _userProgress.currentStreak,
        'longestStreak': _userProgress.longestStreak,
        'level': _userProgress.level,
      };

      // Serialize character progress
      _userProgress.characterProgress.forEach((char, progress) {
        data['characterProgress'][char] = {
          'characterType': progress.characterType,
          'masteryLevel': progress.masteryLevel,
          'practiceCount': progress.practiceCount,
          'lastPracticed': progress.lastPracticed.toIso8601String(),
          'recentEvaluations': progress.recentEvaluations
              .map((eval) => {
                    'strokeCountScore': eval.strokeCountScore,
                    'strokeOrderScore': eval.strokeOrderScore,
                    'positionScore': eval.positionScore,
                    'directionScore': eval.directionScore,
                    'overallScore': eval.overallScore,
                    'evaluatedAt': eval.evaluatedAt.toIso8601String(),
                  })
              .toList(),
        };
      });

      // Serialize story progress
      _userProgress.storyProgress.forEach((storyId, progress) {
        data['storyProgress'][storyId] = {
          'pagesRead': progress.pagesRead,
          'completed': progress.completed,
          'vocabularyLearned': progress.vocabularyLearned,
          'lastRead': progress.lastRead.toIso8601String(),
        };
      });

      // Serialize quiz results
      for (var result in _userProgress.quizResults) {
        data['quizResults'].add({
          'quizType': result.quizType,
          'score': result.score,
          'totalQuestions': result.totalQuestions,
          'timeSpent': result.timeSpent.inSeconds,
          'completedAt': result.completedAt.toIso8601String(),
          'categories': result.categories,
        });
      }

      // Save to shared preferences
      await prefs.setString('user_progress', jsonEncode(data));

      // Also save dashboard progress
      if (_dashboardProgress != null) {
        await prefs.setString('dashboard_progress', json.encode(_dashboardProgress!.toJson()));
      }

      // Sync comprehensive data to Firebase
      await _firebaseSync.syncUserProgressToFirebase();
      // Notify listeners that progress changed
      _progressTicks.value = _progressTicks.value + 1;
    } catch (e) {
      print('Error saving progress: $e');
    }
  }

  // Get user progress
  UserProgress getUserProgress() {
    return _userProgress;
  }

  // Update character mastery
  Future<void> updateCharacterMastery(
    JapaneseCharacter character,
    double score,
    StrokeEvaluation evaluation,
  ) async {
    if (!_isInitialized) await initialize();

    final charKey = character.character;

    if (!_userProgress.characterProgress.containsKey(charKey)) {
      _userProgress.characterProgress[charKey] = CharacterProgress(
        character: charKey,
        characterType: character.type,
      );
    }

    _userProgress.characterProgress[charKey]!.updateMastery(score);
    _userProgress.characterProgress[charKey]!.addEvaluation(evaluation);

    // Add XP based on score
    int xpGained = (score / 10).round();
    _userProgress.addXp(xpGained);

    // Update streak
    _userProgress.updateStreak(true);

    // Update dashboard progress
    await addStudyMinutes(1);
    await updateDashboardXpAndLevel(_userProgress.totalXp, _userProgress.level);

    await saveProgress();

    // Persist to Firebase immediately for cross-device persistence
    try {
      final mark = score >= 90.0
          ? 'excellent'
          : score >= 70.0
              ? 'goods'
              : 'failed';
      await _firebaseSync.setCharacterMark(
        characterId: charKey,
        script: character.type,
        mark: mark,
        scorePercent: score.round(),
      );
    } catch (_) {}

    // Sync to Firebase
    await _firebaseSync.syncXpChange(_userProgress.totalXp, _userProgress.level);
    await _firebaseSync.syncStreakChange(_userProgress.currentStreak, _userProgress.longestStreak);

    // Log character practice activity
    await _activityService.logCharacterPractice(charKey, character.type, score);

    // Also tick notifier for immediate UI updates
    _progressTicks.value = _progressTicks.value + 1;
  }

  // Compute completion fraction against the actual total characters in the script
  Future<double> getScriptCompletionFraction(String characterType) async {
    if (!_isInitialized) await initialize();

    final db = DatabaseService();
    int total;
    if (characterType == 'hiragana') {
      total = (await db.getHiragana()).length;
    } else if (characterType == 'katakana') {
      total = (await db.getKatakana()).length;
    } else {
      total = 0;
    }

    if (total == 0) return 0.0;

    final completed = _userProgress.characterProgress.values
        .where((p) => p.characterType == characterType && p.masteryLevel >= 70.0)
        .length;

    return completed / total;
  }

  // Update story progress
  Future<void> updateStoryProgress(
    Story story,
    int currentPage,
    int vocabularyLearned,
  ) async {
    if (!_isInitialized) await initialize();

    final storyId = story.id;

    if (!_userProgress.storyProgress.containsKey(storyId)) {
      _userProgress.storyProgress[storyId] = StoryProgress(storyId: storyId);
    }

    _userProgress.storyProgress[storyId]!.updateProgress(currentPage, story.pages.length);

    if (vocabularyLearned > 0) {
      _userProgress.storyProgress[storyId]!.addVocabularyLearned(vocabularyLearned);

      // Add XP for vocabulary learned
      _userProgress.addXp(vocabularyLearned * 5);
    }

    // Add XP for completing a story
    if (_userProgress.storyProgress[storyId]!.completed) {
      _userProgress.addXp(50);

      // Update dashboard progress for completed lesson
      await updateLessonCompletion();
    }

    // Update streak
    _userProgress.updateStreak(true);

    // Update dashboard progress
    await addStudyMinutes(3);
    await updateDashboardXpAndLevel(_userProgress.totalXp, _userProgress.level);

    // Update dashboard lesson progress
    await updateLessonProgress(storyId, "Story: ${story.title}",
        "Read a Japanese story with translations", "book", currentPage / story.pages.length);

    await saveProgress();

    // Sync to Firebase
    await _firebaseSync.syncXpChange(_userProgress.totalXp, _userProgress.level);
    await _firebaseSync.syncStreakChange(_userProgress.currentStreak, _userProgress.longestStreak);

    // Log story reading activity
    await _activityService.logStoryRead(storyId, story.title, currentPage, story.pages.length);
  }

  // Update story mode score (for the story screen game mode)
  Future<void> updateStoryModeScore({
    required int score,
    required int correctAnswers,
    required int maxStreak,
    required int hintsUsed,
    required double livesRemaining,
    required String difficulty,
    required String playerRank,
  }) async {
    if (!_isInitialized) await initialize();

    // Add XP based on score
    int xpGained = (score / 10).round();
    _userProgress.addXp(xpGained);

    // Update streak
    _userProgress.updateStreak(true);

    // Update dashboard progress
    await addStudyMinutes(5); // Story mode takes longer
    await updateDashboardXpAndLevel(_userProgress.totalXp, _userProgress.level);

    // Update dashboard lesson progress for story mode
    await updateLessonProgress(
        "story-mode-${DateTime.now().millisecondsSinceEpoch}",
        "Story Mode - $difficulty",
        "Completed story mode with $correctAnswers correct answers",
        "auto_stories",
        1.0 // Story mode is always completed when this is called
        );

    await saveProgress();

    // Sync to Firebase
    await _firebaseSync.syncXpChange(_userProgress.totalXp, _userProgress.level);
    await _firebaseSync.syncStreakChange(_userProgress.currentStreak, _userProgress.longestStreak);

    // Log story mode completion activity
    await _activityService.logStoryRead(
      "story-mode-${DateTime.now().millisecondsSinceEpoch}",
      "Story Mode - $difficulty",
      1,
      1,
    );
  }

  // Add quiz result
  Future<void> addQuizResult(QuizResult result) async {
    if (!_isInitialized) await initialize();

    _userProgress.quizResults.add(result);

    // Add XP based on score percentage
    double percentage = result.getPercentage();
    int xpGained = (percentage / 2).round();
    _userProgress.addXp(xpGained);

    // Update streak
    _userProgress.updateStreak(true);

    // Update dashboard progress
    await addStudyMinutes(result.timeSpent.inMinutes + 1);
    await updateDashboardXpAndLevel(_userProgress.totalXp, _userProgress.level);

    // Update dashboard lesson progress for quiz
    await updateLessonProgress(
        "quiz-${DateTime.now().millisecondsSinceEpoch}",
        "${result.quizType} Quiz",
        "Quiz on ${result.categories.join(', ')}",
        "quiz",
        percentage / 100);

    await saveProgress();

    // Sync to Firebase
    await _firebaseSync.syncXpChange(_userProgress.totalXp, _userProgress.level);
    await _firebaseSync.syncStreakChange(_userProgress.currentStreak, _userProgress.longestStreak);

    // Log quiz completion activity
    await _activityService.logQuizCompleted(
      "quiz-${DateTime.now().millisecondsSinceEpoch}",
      "${result.quizType} Quiz",
      result.score,
      result.totalQuestions,
    );
  }

  // Add lesson completion
  Future<void> addLessonCompletion(String lessonId, String lessonTitle, String category) async {
    if (!_isInitialized) await initialize();

    // Add XP for lesson completion
    int xpGained = 50; // Base XP for lesson completion
    _userProgress.addXp(xpGained);

    // Update streak
    _userProgress.updateStreak(true);

    // Update dashboard progress
    await addStudyMinutes(5); // Lessons take about 5 minutes
    await updateDashboardXpAndLevel(_userProgress.totalXp, _userProgress.level);

    // Update dashboard lesson progress
    await updateLessonProgress(
      lessonId,
      lessonTitle,
      "Completed lesson: $lessonTitle",
      "lesson",
      1.0, // Lesson is fully completed
    );

    await saveProgress();

    // Sync to Firebase
    await _firebaseSync.syncXpChange(_userProgress.totalXp, _userProgress.level);
    await _firebaseSync.syncStreakChange(_userProgress.currentStreak, _userProgress.longestStreak);

    debugPrint('Lesson completion added: $lessonTitle');
  }

  // Get character progress
  CharacterProgress? getCharacterProgress(String character) {
    return _userProgress.characterProgress[character];
  }

  // Get story progress
  StoryProgress? getStoryProgress(String storyId) {
    return _userProgress.storyProgress[storyId];
  }

  // Get quiz results
  List<QuizResult> getQuizResults() {
    return _userProgress.quizResults;
  }

  // Get mastery level for a character type
  double getMasteryLevel(String characterType) {
    return _userProgress.getMasteryLevel(characterType);
  }

  // Get overall mastery level
  double getOverallMasteryLevel() {
    return _userProgress.getOverallMasteryLevel();
  }

  // DASHBOARD PROGRESS METHODS

  // Get dashboard progress
  Future<Progress> getDashboardProgress() async {
    if (!_isInitialized) await initialize();

    _dashboardProgress ??= await _createDefaultDashboardProgress();

    return _dashboardProgress!;
  }

  // Create default dashboard progress
  Future<Progress> _createDefaultDashboardProgress() async {
    final defaultProgress = Progress(
      totalLessonsCompleted: 3,
      totalLessons: 100,
      streak: _userProgress.currentStreak,
      dailyGoalMinutes: 15,
      minutesStudiedToday: 0,
      lastStudyDate: DateTime.now(),
      recentLessons: [
        LessonProgress(
          id: 'greeting',
          title: 'Basic Greetings',
          description: 'Learn common Japanese greetings',
          iconName: 'chat_bubble_outline',
          progress: 0.8,
          lastAccessed: DateTime.now().subtract(const Duration(days: 1)),
        ),
        LessonProgress(
          id: 'numbers',
          title: 'Numbers 1-10',
          description: 'Count from 1 to 10 in Japanese',
          iconName: 'format_list_numbered',
          progress: 0.5,
          lastAccessed: DateTime.now().subtract(const Duration(days: 2)),
        ),
        LessonProgress(
          id: 'kanji',
          title: 'Basic Kanji',
          description: 'Learn your first 5 kanji characters',
          iconName: 'translate',
          progress: 0.3,
          lastAccessed: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
      totalXp: _userProgress.totalXp,
      level: _userProgress.level,
    );

    return defaultProgress;
  }

  // Check if we need to reset daily progress (new day)
  Future<void> _checkDailyReset() async {
    if (_dashboardProgress == null) return;

    final now = DateTime.now();
    final lastStudyDate = _dashboardProgress!.lastStudyDate;

    if (now.year != lastStudyDate.year ||
        now.month != lastStudyDate.month ||
        now.day != lastStudyDate.day) {
      // It's a new day, reset daily progress
      _dashboardProgress = _dashboardProgress!.copyWith(
        minutesStudiedToday: 0,
        lastStudyDate: now,
      );

      await saveProgress();
    }
  }

  // Add study minutes
  Future<Progress> addStudyMinutes(int minutes) async {
    if (!_isInitialized) await initialize();

    _dashboardProgress ??= await _createDefaultDashboardProgress();

    _dashboardProgress = _dashboardProgress!.copyWith(
      minutesStudiedToday: _dashboardProgress!.minutesStudiedToday + minutes,
      lastStudyDate: DateTime.now(),
      streak: _userProgress.currentStreak,
    );

    await saveProgress();
    return _dashboardProgress!;
  }

  // Update lesson progress
  Future<Progress> updateLessonProgress(String lessonId, String title, String description,
      String iconName, double newProgress) async {
    if (!_isInitialized) await initialize();

    _dashboardProgress ??= await _createDefaultDashboardProgress();

    // Find if the lesson exists in recent lessons
    final lessonIndex =
        _dashboardProgress!.recentLessons.indexWhere((lesson) => lesson.id == lessonId);

    if (lessonIndex >= 0) {
      // Update existing lesson
      final updatedLessons = List<LessonProgress>.from(_dashboardProgress!.recentLessons);
      final oldLesson = updatedLessons[lessonIndex];

      // Create updated lesson
      final updatedLesson = LessonProgress(
        id: oldLesson.id,
        title: oldLesson.title,
        description: oldLesson.description,
        iconName: oldLesson.iconName,
        progress: newProgress,
        lastAccessed: DateTime.now(),
      );

      // Replace old lesson with updated one
      updatedLessons[lessonIndex] = updatedLesson;

      // Sort lessons by last accessed
      updatedLessons.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));

      // Calculate new total completed lessons
      int totalCompleted = _dashboardProgress!.totalLessonsCompleted;
      if (oldLesson.progress < 1.0 && newProgress >= 1.0) {
        totalCompleted += 1;
      }

      _dashboardProgress = _dashboardProgress!.copyWith(
        recentLessons: updatedLessons,
        totalLessonsCompleted: totalCompleted,
      );
    } else {
      // This is a new lesson, add it to recent lessons
      final newLesson = LessonProgress(
        id: lessonId,
        title: title,
        description: description,
        iconName: iconName,
        progress: newProgress,
        lastAccessed: DateTime.now(),
      );

      final updatedLessons = List<LessonProgress>.from(_dashboardProgress!.recentLessons);
      updatedLessons.add(newLesson);

      // Keep only the most recent 5 lessons
      if (updatedLessons.length > 5) {
        updatedLessons.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
        updatedLessons.removeRange(5, updatedLessons.length);
      }

      _dashboardProgress = _dashboardProgress!.copyWith(
        recentLessons: updatedLessons,
      );
    }

    await saveProgress();
    return _dashboardProgress!;
  }

  // Update lesson completion
  Future<Progress> updateLessonCompletion() async {
    if (!_isInitialized) await initialize();

    _dashboardProgress ??= await _createDefaultDashboardProgress();

    _dashboardProgress = _dashboardProgress!.copyWith(
      totalLessonsCompleted: _dashboardProgress!.totalLessonsCompleted + 1,
    );

    await saveProgress();
    return _dashboardProgress!;
  }

  // Update dashboard XP and level
  Future<Progress> updateDashboardXpAndLevel(int xp, int level) async {
    if (!_isInitialized) await initialize();

    _dashboardProgress ??= await _createDefaultDashboardProgress();

    _dashboardProgress = _dashboardProgress!.copyWith(
      totalXp: xp,
      level: level,
    );

    await saveProgress();
    return _dashboardProgress!;
  }

  // Set daily goal
  Future<Progress> setDailyGoal(int minutes) async {
    if (!_isInitialized) await initialize();

    _dashboardProgress ??= await _createDefaultDashboardProgress();

    _dashboardProgress = _dashboardProgress!.copyWith(
      dailyGoalMinutes: minutes,
    );

    await saveProgress();
    return _dashboardProgress!;
  }

  // Reset progress (for testing)
  Future<Progress> resetDashboardProgress() async {
    _dashboardProgress = await _createDefaultDashboardProgress();
    await saveProgress();
    return _dashboardProgress!;
  }
}
