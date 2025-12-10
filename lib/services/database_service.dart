import 'database_interface.dart';
import '../models/flashcard.dart';
import '../models/review_categories.dart';
import 'package:nihongo_japanese_app/models/japanese_character.dart';
import 'package:nihongo_japanese_app/services/character_converter.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static DatabaseInterface? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal() {
    _database = getDatabaseImplementation();
  }

  Future<List<Map<String, dynamic>>> getLessons() async {
    return await _database!.getLessons();
  }

  Future<Map<String, dynamic>?> getLessonById(String id) async {
    return await _database!.getLessonById(id);
  }

  Future<List<Map<String, dynamic>>> getExampleSentences(
    String lessonId, {
    String? characterType,
  }) async {
    final examples = await _database!.getExampleSentences(lessonId);
    
    if (characterType != null && (characterType == 'Hiragana' || characterType == 'Katakana')) {
      // Filter examples based on character type
      return examples.where((example) {
        final isKatakana = example['japanese'].toString().codeUnitAt(0) >= 0x30A0 &&
                          example['japanese'].toString().codeUnitAt(0) <= 0x30FF;
        return characterType == 'Katakana' ? isKatakana : !isKatakana;
      }).toList();
    }
    
    return examples;
  }

  Future<List<JapaneseCharacter>> getHiragana() async {
    final data = await _database!.getHiragana();
    return CharacterConverter.convertToJapaneseCharacters(data, 'hiragana');
  }

  Future<List<JapaneseCharacter>> getKatakana() async {
    final data = await _database!.getKatakana();
    return CharacterConverter.convertToJapaneseCharacters(data, 'katakana');
  }

  Future<List<Map<String, dynamic>>> getKanji() async {
    return await _database!.getKanji();
  }

  Future<List<Map<String, dynamic>>> getChallenges() async {
    return await _database!.getChallenges();
  }

  Future<Map<String, dynamic>?> getChallengeById(String id) async {
    return await _database!.getChallengeById(id);
  }

  Future<int> getTotalChallenges() async {
    return await _database!.getTotalChallenges();
  }

  Future<List<Map<String, dynamic>>> getChallengeTopics() async {
    return await _database!.getChallengeTopics();
  }

  Future<List<Map<String, dynamic>>> getChallengesByTopic(String topicId) async {
    return await _database!.getChallengesByTopic(topicId);
  }

  Future<int> getCompletedChallengesForTopic(String topicId) async {
    return await _database!.getCompletedChallengesForTopic(topicId);
  }

  Future<List<Flashcard>> getFlashcards() async {
    final flashcards = await _database!.getFlashcards();
    return flashcards.map((map) => Flashcard.fromMap(map)).toList();
  }
  
  Future<Flashcard?> getFlashcardById(String id) async {
    final map = await _database!.getFlashcardById(id);
    return map != null ? Flashcard.fromMap(map) : null;
  }
  
  Future<void> updateFlashcardReview(String id, bool isCorrect) async {
    await _database!.updateFlashcardReview(id, isCorrect);
  }
  
  Future<void> addFlashcard(Map<String, dynamic> flashcard) async {
    await _database!.addFlashcard(flashcard);
  }
  
  Future<void> deleteFlashcard(String id) async {
    await _database!.deleteFlashcard(id);
  }

  // Flashcard category methods
  Future<List<Map<String, dynamic>>> getFlashcardCategories() async {
    return await _database!.getFlashcardCategories();
  }

  Future<List<Flashcard>> getFlashcardsByCategory(String categoryId) async {
    final flashcards = await _database!.getFlashcardsByCategory(categoryId);
    return flashcards.map((map) => Flashcard.fromMap(map)).toList();
  }

  Future<Map<String, dynamic>?> getFlashcardCategoryById(String id) async {
    return await _database!.getFlashcardCategoryById(id);
  }

  Future<void> addFlashcardCategory(Map<String, dynamic> category) async {
    await _database!.addFlashcardCategory(category);
  }

  Future<void> updateFlashcardCategory(String id, Map<String, dynamic> category) async {
    await _database!.updateFlashcardCategory(id, category);
  }

  Future<void> deleteFlashcardCategory(String id) async {
    await _database!.deleteFlashcardCategory(id);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    return ReviewCategories.getCategories();
  }
}