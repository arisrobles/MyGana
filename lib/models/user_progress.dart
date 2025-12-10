class UserProgress {
  // Character practice progress
  Map<String, CharacterProgress> characterProgress = {};
  
  // Story progress
  Map<String, StoryProgress> storyProgress = {};
  
  // Quiz progress
  List<QuizResult> quizResults = [];
  
  // Overall stats
  int totalXp = 0;
  int currentStreak = 0;
  int longestStreak = 0;
  int level = 1;
  
  // Get mastery level for a specific character type
  double getMasteryLevel(String characterType) {
    if (characterProgress.isEmpty) return 0.0;
    
    int totalCharacters = 0;
    int masteredCharacters = 0;
    
    characterProgress.forEach((char, progress) {
      if (progress.characterType == characterType) {
        totalCharacters++;
        if (progress.masteryLevel >= 70) {
          masteredCharacters++;
        }
      }
    });
    
    return totalCharacters > 0 ? masteredCharacters / totalCharacters : 0.0;
  }
  
  // Get overall mastery level
  double getOverallMasteryLevel() {
    if (characterProgress.isEmpty) return 0.0;
    
    int totalCharacters = characterProgress.length;
    int masteredCharacters = characterProgress.values
        .where((progress) => progress.masteryLevel >= 70)
        .length;
    
    return masteredCharacters / totalCharacters;
  }
  
  // Add XP and update level
  void addXp(int xp) {
    totalXp += xp;
    // Simple level calculation: level = 1 + (totalXp / 1000)
    level = 1 + (totalXp ~/ 1000);
  }
  
  // Update streak
  void updateStreak(bool practiced) {
    if (practiced) {
      currentStreak++;
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
    } else {
      currentStreak = 0;
    }
  }
}

class CharacterProgress {
  final String character;
  final String characterType; // 'hiragana', 'katakana', or 'kanji'
  double masteryLevel = 0.0; // 0-100
  int practiceCount = 0;
  DateTime lastPracticed = DateTime.now();
  List<StrokeEvaluation> recentEvaluations = [];
  
  CharacterProgress({
    required this.character,
    required this.characterType,
  });
  
  // Update mastery level based on new evaluation
  void updateMastery(double score) {
    // Weight recent scores more heavily
    if (masteryLevel == 0) {
      masteryLevel = score;
    } else {
      // 70% new score, 30% old mastery
      masteryLevel = (score * 0.7) + (masteryLevel * 0.3);
    }
    
    practiceCount++;
    lastPracticed = DateTime.now();
  }
  
  // Add stroke evaluation
  void addEvaluation(StrokeEvaluation evaluation) {
    recentEvaluations.add(evaluation);
    if (recentEvaluations.length > 5) {
      recentEvaluations.removeAt(0);
    }
  }
  
  // Get areas that need improvement
  List<String> getImprovementAreas() {
    if (recentEvaluations.isEmpty) return [];
    
    List<String> areas = [];
    
    // Calculate average scores for each aspect
    double avgStrokeCount = recentEvaluations.map((e) => e.strokeCountScore).reduce((a, b) => a + b) / recentEvaluations.length;
    double avgPosition = recentEvaluations.map((e) => e.positionScore).reduce((a, b) => a + b) / recentEvaluations.length;
    double avgDirection = recentEvaluations.map((e) => e.directionScore).reduce((a, b) => a + b) / recentEvaluations.length;
    
    // Identify weak areas
    if (avgStrokeCount < 70) areas.add('Stroke Count');
    if (avgPosition < 70) areas.add('Stroke Position');
    if (avgDirection < 70) areas.add('Stroke Direction');
    
    return areas;
  }
}

class StrokeEvaluation {
  final double strokeCountScore; // 0-100
  final double strokeOrderScore; // 0-100
  final double positionScore; // 0-100
  final double directionScore; // 0-100
  final double overallScore; // 0-100
  final DateTime evaluatedAt;

  StrokeEvaluation({
    required this.strokeCountScore,
    required this.strokeOrderScore,
    required this.positionScore,
    required this.directionScore,
    required this.overallScore,
    required this.evaluatedAt,
  });
}

class StoryProgress {
  final String storyId;
  int pagesRead = 0;
  bool completed = false;
  int vocabularyLearned = 0;
  DateTime lastRead = DateTime.now();
  
  StoryProgress({
    required this.storyId,
  });
  
  // Update progress
  void updateProgress(int currentPage, int totalPages) {
    pagesRead = currentPage + 1;
    if (pagesRead >= totalPages) {
      completed = true;
    }
    lastRead = DateTime.now();
  }
  
  // Add vocabulary learned
  void addVocabularyLearned(int count) {
    vocabularyLearned += count;
  }
}

class QuizResult {
  final String quizType; // 'timed' or 'review'
  final int score;
  final int totalQuestions;
  final Duration timeSpent;
  final DateTime completedAt;
  final List<String> categories; // e.g., 'hiragana', 'grammar', etc.
  
  QuizResult({
    required this.quizType,
    required this.score,
    required this.totalQuestions,
    required this.timeSpent,
    required this.completedAt,
    required this.categories,
  });
  
  // Get percentage score
  double getPercentage() {
    return (score / totalQuestions) * 100;
  }
}

