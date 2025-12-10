import 'package:firebase_database/firebase_database.dart';
import 'database_interface.dart';

class FirebaseDatabaseService implements DatabaseInterface {
  static final FirebaseDatabaseService _instance = FirebaseDatabaseService._internal();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  factory FirebaseDatabaseService() {
    return _instance;
  }

  FirebaseDatabaseService._internal();

  // Helper method to convert Firebase DataSnapshot to Map

  @override
  Future<List<Map<String, dynamic>>> getLessons() async {
    final snapshot = await _database.child('lessons').get();
    if (snapshot.value == null) return [];
    
    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries.map((entry) {
      final lesson = Map<String, dynamic>.from(entry.value as Map);
      lesson['id'] = entry.key;
      return lesson;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getLessonById(String id) async {
    final snapshot = await _database.child('lessons/$id').get();
    if (snapshot.value == null) return null;
    
    final lesson = Map<String, dynamic>.from(snapshot.value as Map);
    lesson['id'] = id;
    return lesson;
  }

  @override
  Future<List<Map<String, dynamic>>> getExampleSentences(String lessonId) async {
    final snapshot = await _database.child('lessons/$lessonId/example_sentences').get();
    if (snapshot.value == null) return [];
    
    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries.map((entry) {
      final sentence = Map<String, dynamic>.from(entry.value as Map);
      sentence['id'] = entry.key;
      return sentence;
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getHiragana() async {
    final snapshot = await _database.child('characters/hiragana').get();
    if (snapshot.value == null) return [];
    
    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries.map((entry) {
      final char = Map<String, dynamic>.from(entry.value as Map);
      char['id'] = entry.key;
      return char;
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getKatakana() async {
    final snapshot = await _database.child('characters/katakana').get();
    if (snapshot.value == null) return [];
    
    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries.map((entry) {
      final char = Map<String, dynamic>.from(entry.value as Map);
      char['id'] = entry.key;
      return char;
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getKanji() async {
    final snapshot = await _database.child('characters/kanji').get();
    if (snapshot.value == null) return [];
    
    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries.map((entry) {
      final char = Map<String, dynamic>.from(entry.value as Map);
      char['id'] = entry.key;
      return char;
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getChallenges() async {
    final snapshot = await _database.child('challenges').get();
    if (snapshot.value == null) return [];
    
    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries.map((entry) {
      final challenge = Map<String, dynamic>.from(entry.value as Map);
      challenge['id'] = entry.key;
      return challenge;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getChallengeById(String id) async {
    final snapshot = await _database.child('challenges/$id').get();
    if (snapshot.value == null) return null;
    
    final challenge = Map<String, dynamic>.from(snapshot.value as Map);
    challenge['id'] = id;
    return challenge;
  }

  @override
  Future<int> getTotalChallenges() async {
    final snapshot = await _database.child('challenges').get();
    if (snapshot.value == null) return 0;
    return (snapshot.value as Map).length;
  }

  @override
  Future<List<Map<String, dynamic>>> getChallengeTopics() async {
    final snapshot = await _database.child('challenge_topics').get();
    if (snapshot.value == null) return [];
    
    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries.map((entry) {
      final topic = Map<String, dynamic>.from(entry.value as Map);
      topic['id'] = entry.key;
      return topic;
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getChallengesByTopic(String topicId) async {
    final snapshot = await _database.child('challenges').orderByChild('topic_id').equalTo(topicId).get();
    if (snapshot.value == null) return [];
    
    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries.map((entry) {
      final challenge = Map<String, dynamic>.from(entry.value as Map);
      challenge['id'] = entry.key;
      return challenge;
    }).toList();
  }

  @override
  Future<int> getCompletedChallengesForTopic(String topicId) async {
    // This would need to be implemented with user authentication
    // For now, return 0 as it's user-specific data
    return 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getFlashcards() async {
    final snapshot = await _database.child('flashcards').get();
    if (snapshot.value == null) return [];
    
    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries.map((entry) {
      final flashcard = Map<String, dynamic>.from(entry.value as Map);
      flashcard['id'] = entry.key;
      return flashcard;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getFlashcardById(String id) async {
    final snapshot = await _database.child('flashcards/$id').get();
    if (snapshot.value == null) return null;
    
    final flashcard = Map<String, dynamic>.from(snapshot.value as Map);
    flashcard['id'] = id;
    return flashcard;
  }

  @override
  Future<void> updateFlashcardReview(String id, bool isCorrect) async {
    final flashcardRef = _database.child('flashcards/$id');
    final snapshot = await flashcardRef.get();
    
    if (snapshot.value != null) {
      final Map<String, dynamic> flashcard = Map<String, dynamic>.from(snapshot.value as Map);
      final int reviewCount = (flashcard['review_count'] as int?) ?? 0;
      final int correctCount = (flashcard['correct_count'] as int?) ?? 0;
      
      await flashcardRef.update({
        'last_reviewed': ServerValue.timestamp,
        'review_count': reviewCount + 1,
        'correct_count': isCorrect ? correctCount + 1 : correctCount,
      });
    }
  }

  @override
  Future<void> addFlashcard(Map<String, dynamic> flashcard) async {
    await _database.child('flashcards').push().set({
      ...flashcard,
      'created_at': ServerValue.timestamp,
      'last_reviewed': ServerValue.timestamp,
      'review_count': 0,
      'correct_count': 0,
    });
  }

  @override
  Future<void> deleteFlashcard(String id) async {
    await _database.child('flashcards/$id').remove();
  }

  @override
  Future<List<Map<String, dynamic>>> getFlashcardCategories() async {
    final snapshot = await _database.child('flashcard_categories').get();
    if (snapshot.value == null) return [];
    
    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries.map((entry) {
      final category = Map<String, dynamic>.from(entry.value as Map);
      category['id'] = entry.key;
      return category;
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getFlashcardsByCategory(String categoryId) async {
    final snapshot = await _database.child('flashcards').orderByChild('category_id').equalTo(categoryId).get();
    if (snapshot.value == null) return [];
    
    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    return data.entries.map((entry) {
      final flashcard = Map<String, dynamic>.from(entry.value as Map);
      flashcard['id'] = entry.key;
      return flashcard;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getFlashcardCategoryById(String id) async {
    final snapshot = await _database.child('flashcard_categories/$id').get();
    if (snapshot.value == null) return null;
    
    final category = Map<String, dynamic>.from(snapshot.value as Map);
    category['id'] = id;
    return category;
  }

  @override
  Future<void> addFlashcardCategory(Map<String, dynamic> category) async {
    await _database.child('flashcard_categories').push().set(category);
  }

  @override
  Future<void> updateFlashcardCategory(String id, Map<String, dynamic> category) async {
    await _database.child('flashcard_categories/$id').update(category);
  }

  @override
  Future<void> deleteFlashcardCategory(String id) async {
    await _database.child('flashcard_categories/$id').remove();
  }

  // Real-time streams
  Stream<List<Map<String, dynamic>>> watchLessons() {
    return _database.child('lessons').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((entry) {
        final lesson = Map<String, dynamic>.from(entry.value as Map);
        lesson['id'] = entry.key;
        return lesson;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> watchFlashcards() {
    return _database.child('flashcards').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((entry) {
        final flashcard = Map<String, dynamic>.from(entry.value as Map);
        flashcard['id'] = entry.key;
        return flashcard;
      }).toList();
    });
  }
} 