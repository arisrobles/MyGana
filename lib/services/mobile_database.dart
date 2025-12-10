import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'database_interface.dart';

class MobileDatabaseImpl implements DatabaseInterface {
  static final MobileDatabaseImpl _instance = MobileDatabaseImpl._internal();
  static Database? _database;

  factory MobileDatabaseImpl() {
    return _instance;
  }

  @override
  Future<List<Map<String, dynamic>>> getChallengeTopics() async {
    final db = await database;
    return await db.query('challenge_topics');
  }

  @override 
  Future<List<Map<String, dynamic>>> getChallengesByTopic(String topicId) async {
    final db = await database;
    
    try {
      // First verify the topic exists and get topic details
      final topics = await db.query(
        'challenge_topics',
        where: 'id = ?',
        whereArgs: [topicId],
      );
      
      print('Checking topic $topicId - exists: ${topics.isNotEmpty}');
      
      final topicTitle = topics.isNotEmpty ? topics.first['title'] as String : '';
      final topicDescription = topics.isNotEmpty ? topics.first['description'] as String : '';
      
      // Get all challenges for this topic
      final List<Map<String, dynamic>> challenges = await db.query(
        'challenges',
        where: 'topic_id = ?',
        whereArgs: [topicId],
        orderBy: 'id ASC',
      );

      // Update challenge titles and descriptions to match topic
      final updatedChallenges = challenges.map((challenge) {
        return {
          ...challenge,
          'title': topicTitle,
          'description': topicDescription,
        };
      }).toList();

      print('Topic: $topicId');
      print('Total challenges found: ${updatedChallenges.length}');
      if (updatedChallenges.isNotEmpty) {
        print('First challenge: ${updatedChallenges.first['id']}');
        print('Last challenge: ${updatedChallenges.last['id']}');
      }

      // Verify challenge data integrity
      for (var challenge in updatedChallenges) {
        if (!challenge.containsKey('id') || 
            !challenge.containsKey('title') || 
            !challenge.containsKey('options')) {
          print('WARNING: Invalid challenge data found in $topicId:');
          print(challenge);
        }
      }

      return updatedChallenges;
    } catch (e, stackTrace) {
      print('Error fetching challenges for topic $topicId:');
      print(e);
      print('Stack trace:');
      print(stackTrace);
      return [];
    }
  }

  @override
  Future<int> getCompletedChallengesForTopic(String topicId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM challenges c
      JOIN user_progress up ON c.id = up.lesson_id
      WHERE c.topic_id = ?
    ''', [topicId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  MobileDatabaseImpl._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'MyGana.db');
    
    // Check if database exists
    bool exists = await databaseExists(path);
    
    if (!exists) {
      // Copy from asset
      try {
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load(join('assets', 'MyGana.db'));
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
      } catch (e) {
        throw Exception('Failed to copy database from assets: $e');
      }
    }
    
    return await openDatabase(path);
  }

  @override
  Future<List<Map<String, dynamic>>> getLessons() async {
    final db = await database;
    return await db.query('lessons');
  }

  @override
  Future<Map<String, dynamic>?> getLessonById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'lessons',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  @override
  Future<List<Map<String, dynamic>>> getExampleSentences(String lessonId) async {
    final db = await database;
    return await db.query(
      'example_sentences',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getHiragana() async {
    final db = await database;
    return await db.query('hiragana');
  }

  @override
  Future<List<Map<String, dynamic>>> getKatakana() async {
    final db = await database;
    return await db.query('katakana');
  }

  @override
  Future<List<Map<String, dynamic>>> getKanji() async {
    final db = await database;
    return await db.query('kanji');
  }

  @override
  Future<List<Map<String, dynamic>>> getChallenges() async {
    final db = await database;
    return await db.query('challenges', orderBy: 'id ASC');
  }

  @override
  Future<Map<String, dynamic>?> getChallengeById(String id) async {
    final db = await database;
    
    print('Fetching challenge with ID $id');
    
    // Get all challenges that match the ID
    final List<Map<String, dynamic>> maps = await db.query(
      'challenges',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) {
      print('No challenge found with ID $id');
      return null;
    }

    print('Found challenge: ${maps.first}');
    return maps.first;
  }

  @override
  Future<int> getTotalChallenges() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM challenges');
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  // Flashcard methods
  @override
  Future<List<Map<String, dynamic>>> getFlashcards() async {
    final db = await database;
    return await db.query('flashcards', orderBy: 'last_reviewed ASC');
  }
  
  @override
  Future<Map<String, dynamic>?> getFlashcardById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'flashcards',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }
  
  @override
  Future<void> updateFlashcardReview(String id, bool isCorrect) async {
    final db = await database;
    
    // First get the current values
    final flashcard = await getFlashcardById(id);
    if (flashcard == null) return;
    
    final int reviewCount = flashcard['review_count'] as int? ?? 0;
    final int correctCount = flashcard['correct_count'] as int? ?? 0;
    
    // Then update with incremented values
    await db.update(
      'flashcards',
      {
        'last_reviewed': DateTime.now().toIso8601String(),
        'review_count': reviewCount + 1,
        'correct_count': isCorrect ? correctCount + 1 : correctCount,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  @override
  Future<void> addFlashcard(Map<String, dynamic> flashcard) async {
    final db = await database;
    await db.insert('flashcards', flashcard);
  }
  
  @override
  Future<void> deleteFlashcard(String id) async {
    final db = await database;
    await db.delete(
      'flashcards',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getFlashcardCategories() async {
    final db = await database;
    return await db.query('flashcard_categories');
  }

  @override
  Future<List<Map<String, dynamic>>> getFlashcardsByCategory(String categoryId) async {
    final db = await database;
    return await db.query(
      'flashcards',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }

  @override
  Future<Map<String, dynamic>?> getFlashcardCategoryById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'flashcard_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<void> addFlashcardCategory(Map<String, dynamic> category) async {
    final db = await database;
    await db.insert('flashcard_categories', category);
  }

  @override
  Future<void> updateFlashcardCategory(String id, Map<String, dynamic> category) async {
    final db = await database;
    await db.update(
      'flashcard_categories',
      category,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteFlashcardCategory(String id) async {
    final db = await database;
    await db.delete(
      'flashcard_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
} 