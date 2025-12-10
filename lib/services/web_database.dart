import 'dart:convert';
import 'database_interface.dart';

class WebDatabaseImpl implements DatabaseInterface {
  @override
  Future<List<Map<String, dynamic>>> getLessons() async {
    return [
      {
        'id': 'web-1',
        'title': 'Web Version Coming Soon',
        'description': 'The web version is under development. Please use the mobile app for full functionality.',
        'category': 'Information',
        'level': 'N/A'
      }
    ];
  }

  @override
  Future<Map<String, dynamic>?> getLessonById(String id) async {
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getExampleSentences(String lessonId) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getHiragana() async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getKatakana() async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getKanji() async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getChallenges() async {
    final hiraganaChallenges = await getChallengesByTopic('hiragana-basic');
    final katakanaChallenges = await getChallengesByTopic('katakana-basic');
    return [...hiraganaChallenges, ...katakanaChallenges];
  }

  @override
  Future<Map<String, dynamic>?> getChallengeById(String id) async {
    // Get all challenges from all topics
    final hiraganaChallenges = await getChallengesByTopic('hiragana-basic');
    final katakanaChallenges = await getChallengesByTopic('katakana-basic');
    
    // Combine all challenges
    final allChallenges = [...hiraganaChallenges, ...katakanaChallenges];
    
    // Find the challenge with matching ID
    for (var challenge in allChallenges) {
      if (challenge['id'] == id) {
        return challenge;
      }
    }
    
    return null;
  }

  @override
  Future<int> getTotalChallenges() async {
    final hiraganaChallenges = await getChallengesByTopic('hiragana-basic');
    final katakanaChallenges = await getChallengesByTopic('katakana-basic');
    return hiraganaChallenges.length + katakanaChallenges.length;
  }

  @override
  Future<List<Map<String, dynamic>>> getChallengeTopics() async {
    return [
      {
        'id': 'hiragana-basic',
        'title': 'Basic Hiragana',
        'description': 'Learn the basic Hiragana characters (あ-ん)',
        'category': 'Hiragana',
        'icon_name': 'brush',
        'color': 'blue',
        'total_challenges': 25,
        'completed_challenges': 0
      },
      {
        'id': 'katakana-basic',
        'title': 'Basic Katakana',
        'description': 'Learn the basic Katakana characters (ア-ン)',
        'category': 'Katakana',
        'icon_name': 'brush',
        'color': 'purple',
        'total_challenges': 25,
        'completed_challenges': 0
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getChallengesByTopic(String topicId) async {
    if (topicId == 'hiragana-basic') {
      return [
        {
          'id': 'hiragana-basic-1',
          'title': 'Basic Hiragana Challenge 1',
          'description': 'Test your knowledge of basic Hiragana characters',
          'category': 'Hiragana',
          'level': 'Beginner',
          'question': 'What is the reading for あ?',
          'options': jsonEncode(['a', 'i', 'u', 'e']),
          'correct_answer': 'a',
          'explanation': 'あ is the basic Hiragana character that represents the "a" sound in Japanese.',
          'next_challenge_id': 'hiragana-basic-2',
          'topic_id': 'hiragana-basic'
        },
        {
          'id': 'hiragana-basic-2',
          'title': 'Basic Hiragana Challenge 2',
          'description': 'Test your knowledge of basic Hiragana characters',
          'category': 'Hiragana',
          'level': 'Beginner',
          'question': 'What is the reading for い?',
          'options': jsonEncode(['a', 'i', 'u', 'e']),
          'correct_answer': 'i',
          'explanation': 'い is the basic Hiragana character that represents the "i" sound in Japanese.',
          'next_challenge_id': 'hiragana-basic-3',
          'topic_id': 'hiragana-basic'
        }
      ];
    } else if (topicId == 'katakana-basic') {
      return [
        {
          'id': 'katakana-basic-1',
          'title': 'Basic Katakana Challenge 1',
          'description': 'Test your knowledge of basic Katakana characters',
          'category': 'Katakana',
          'level': 'Beginner',
          'question': 'What is the reading for ア?',
          'options': jsonEncode(['a', 'i', 'u', 'e']),
          'correct_answer': 'a',
          'explanation': 'ア is the basic Katakana character that represents the "a" sound in Japanese.',
          'next_challenge_id': 'katakana-basic-2',
          'topic_id': 'katakana-basic'
        },
        {
          'id': 'katakana-basic-2',
          'title': 'Basic Katakana Challenge 2',
          'description': 'Test your knowledge of basic Katakana characters',
          'category': 'Katakana',
          'level': 'Beginner',
          'question': 'What is the reading for イ?',
          'options': jsonEncode(['a', 'i', 'u', 'e']),
          'correct_answer': 'i',
          'explanation': 'イ is the basic Katakana character that represents the "i" sound in Japanese.',
          'next_challenge_id': 'katakana-basic-3',
          'topic_id': 'katakana-basic'
        }
      ];
    }
    return [];
  }

  @override
  Future<int> getCompletedChallengesForTopic(String topicId) async {
    // Web implementation will be added later
    return 0;
  }
  
  // Flashcard methods
  @override
  Future<List<Map<String, dynamic>>> getFlashcards() async {
    // Simulate database fetch with a delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Return sample flashcards
    return [
      {
        'id': '1',
        'front': 'こんにちは',
        'back': 'Hello',
        'category': 'Greetings',
        'created_at': DateTime.now().toIso8601String(),
        'last_reviewed': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'review_count': 5,
        'correct_count': 3,
      },
      {
        'id': '2',
        'front': 'ありがとう',
        'back': 'Thank you',
        'category': 'Greetings',
        'created_at': DateTime.now().toIso8601String(),
        'last_reviewed': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'review_count': 3,
        'correct_count': 2,
      },
      {
        'id': '3',
        'front': 'さようなら',
        'back': 'Goodbye',
        'category': 'Greetings',
        'created_at': DateTime.now().toIso8601String(),
        'last_reviewed': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'review_count': 2,
        'correct_count': 1,
      },
      {
        'id': '4',
        'front': '水',
        'back': 'Water',
        'category': 'Basic Nouns',
        'created_at': DateTime.now().toIso8601String(),
        'last_reviewed': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        'review_count': 1,
        'correct_count': 1,
      },
      {
        'id': '5',
        'front': '食べる',
        'back': 'To eat',
        'category': 'Basic Verbs',
        'created_at': DateTime.now().toIso8601String(),
        'last_reviewed': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        'review_count': 1,
        'correct_count': 0,
      },
    ];
  }
  
  @override
  Future<Map<String, dynamic>?> getFlashcardById(String id) async {
    final flashcards = await getFlashcards();
    for (var flashcard in flashcards) {
      if (flashcard['id'] == id) {
        return flashcard;
      }
    }
    return null;
  }
  
  @override
  Future<void> updateFlashcardReview(String id, bool isCorrect) async {
    // In a real implementation, this would update the database
    // For the web version, we'll just simulate a delay
    await Future.delayed(const Duration(milliseconds: 300));
    print('Updated flashcard $id review: $isCorrect');
  }
  
  @override
  Future<void> addFlashcard(Map<String, dynamic> flashcard) async {
    // In a real implementation, this would add to the database
    // For the web version, we'll just simulate a delay
    await Future.delayed(const Duration(milliseconds: 300));
    print('Added flashcard: ${flashcard['id']}');
  }
  
  @override
  Future<void> deleteFlashcard(String id) async {
    // In a real implementation, this would delete from the database
    // For the web version, we'll just simulate a delay
    await Future.delayed(const Duration(milliseconds: 300));
    print('Deleted flashcard: $id');
  }

  @override
  Future<List<Map<String, dynamic>>> getFlashcardCategories() async {
    // Simulate database fetch
    await Future.delayed(const Duration(milliseconds: 500));
    
    return [
      {
        'id': 'cat1',
        'name': 'Greetings',
        'description': 'Basic Japanese greetings and introductions',
        'icon': 'waving_hand',
        'color': '#4CAF50',
      },
      {
        'id': 'cat2',
        'name': 'Basic Nouns',
        'description': 'Common everyday objects and places',
        'icon': 'category',
        'color': '#2196F3',
      },
      {
        'id': 'cat3',
        'name': 'Basic Verbs',
        'description': 'Essential Japanese verbs',
        'icon': 'directions_run',
        'color': '#FF9800',
      },
      {
        'id': 'cat4',
        'name': 'Basic Adjectives',
        'description': 'Common descriptive words',
        'icon': 'format_color_fill',
        'color': '#9C27B0',
      },
      {
        'id': 'cat5',
        'name': 'Time Expressions',
        'description': 'Words related to time and dates',
        'icon': 'schedule',
        'color': '#E91E63',
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getFlashcardsByCategory(String categoryId) async {
    // Simulate database fetch
    await Future.delayed(const Duration(milliseconds: 500));
    
    final allFlashcards = await getFlashcards();
    return allFlashcards.where((card) => card['category_id'] == categoryId).toList();
  }

  @override
  Future<Map<String, dynamic>?> getFlashcardCategoryById(String id) async {
    // Simulate database fetch
    await Future.delayed(const Duration(milliseconds: 500));
    
    final categories = await getFlashcardCategories();
    return categories.firstWhere((cat) => cat['id'] == id);
  }

  @override
  Future<void> addFlashcardCategory(Map<String, dynamic> category) async {
    // Simulate database operation
    await Future.delayed(const Duration(milliseconds: 500));
    print('Added flashcard category: ${category['name']}');
  }

  @override
  Future<void> updateFlashcardCategory(String id, Map<String, dynamic> category) async {
    // Simulate database operation
    await Future.delayed(const Duration(milliseconds: 500));
    print('Updated flashcard category: $id');
  }

  @override
  Future<void> deleteFlashcardCategory(String id) async {
    // Simulate database operation
    await Future.delayed(const Duration(milliseconds: 500));
    print('Deleted flashcard category: $id');
  }
} 