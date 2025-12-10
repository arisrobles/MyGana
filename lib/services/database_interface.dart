import 'package:flutter/foundation.dart';
import 'mobile_database.dart';
import 'web_database.dart';

abstract class DatabaseInterface {
  Future<List<Map<String, dynamic>>> getLessons();
  Future<Map<String, dynamic>?> getLessonById(String id);
  Future<List<Map<String, dynamic>>> getExampleSentences(String lessonId);
  Future<List<Map<String, dynamic>>> getHiragana();
  Future<List<Map<String, dynamic>>> getKatakana();
  Future<List<Map<String, dynamic>>> getKanji();
  Future<List<Map<String, dynamic>>> getChallenges();
  Future<Map<String, dynamic>?> getChallengeById(String id);
  Future<int> getTotalChallenges();
  Future<List<Map<String, dynamic>>> getChallengeTopics();
  Future<List<Map<String, dynamic>>> getChallengesByTopic(String topicId);
  Future<int> getCompletedChallengesForTopic(String topicId);
  
  // Flashcard methods
  Future<List<Map<String, dynamic>>> getFlashcards();
  Future<Map<String, dynamic>?> getFlashcardById(String id);
  Future<void> updateFlashcardReview(String id, bool isCorrect);
  Future<void> addFlashcard(Map<String, dynamic> flashcard);
  Future<void> deleteFlashcard(String id);
  
  // Flashcard category methods
  Future<List<Map<String, dynamic>>> getFlashcardCategories();
  Future<List<Map<String, dynamic>>> getFlashcardsByCategory(String categoryId);
  Future<Map<String, dynamic>?> getFlashcardCategoryById(String id);
  Future<void> addFlashcardCategory(Map<String, dynamic> category);
  Future<void> updateFlashcardCategory(String id, Map<String, dynamic> category);
  Future<void> deleteFlashcardCategory(String id);
}

DatabaseInterface getDatabaseImplementation() {
  if (kIsWeb) {
    return WebDatabaseImpl();
  } else {
    return MobileDatabaseImpl();
  }
} 