import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../models/admin_quiz_model.dart';

class SuperAdminLessonDetailsScreen extends StatefulWidget {
  final String lessonId;
  const SuperAdminLessonDetailsScreen({super.key, required this.lessonId});

  @override
  State<SuperAdminLessonDetailsScreen> createState() => _SuperAdminLessonDetailsScreenState();
}

class _SuperAdminLessonDetailsScreenState extends State<SuperAdminLessonDetailsScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  Map<String, dynamic>? _lessonData;
  List<Map<String, dynamic>> _exampleSentences = [];

  @override
  void initState() {
    super.initState();
    _loadLessonData();
  }

  Future<void> _loadLessonData() async {
    setState(() => _isLoading = true);
    try {
      final lessonSnapshot = await _db.child('lessons/${widget.lessonId}').get();
      final sentencesSnapshot =
          await _db.child('lessons/${widget.lessonId}/example_sentences').get();

      if (lessonSnapshot.exists) {
        setState(() {
          _lessonData = Map<String, dynamic>.from(lessonSnapshot.value as Map);
        });
      }

      if (sentencesSnapshot.exists) {
        final sentencesData = sentencesSnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _exampleSentences = sentencesData.entries.map((entry) {
            final sentence = Map<String, dynamic>.from(entry.value as Map);
            sentence['id'] = entry.key;
            return sentence;
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading lesson data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_lessonData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson Details')),
        body: const Center(child: Text('Lesson not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_lessonData!['title'] ?? 'Lesson Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddContentDialog,
            tooltip: 'Add Content',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLessonData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lesson Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.label, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          _lessonData!['level'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.category, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          _lessonData!['category'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _lessonData!['description'] ?? 'No description',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Content Management Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Example Sentences (${_exampleSentences.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddExampleSentenceDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Sentence'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Example Sentences List
            if (_exampleSentences.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.style_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No example sentences yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add example sentences to help students learn',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddExampleSentenceDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Sentence'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._exampleSentences.map((sentence) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Icon(
                          Icons.style,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        sentence['japanese'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (sentence['romaji']?.isNotEmpty == true)
                            Text(
                              'Romaji: ${sentence['romaji']}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          Text(
                            'English: ${sentence['english'] ?? ''}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: const Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: const Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditExampleSentenceDialog(sentence);
                          } else if (value == 'delete') {
                            _showDeleteExampleSentenceDialog(sentence);
                          }
                        },
                      ),
                    ),
                  )),

            const SizedBox(height: 24),

            // Add Flashcard Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.flash_on,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Flashcards',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create flashcards for vocabulary practice',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showAddFlashcardDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Flashcard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddContentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Content'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.style),
              title: const Text('Add Example Sentence'),
              subtitle: const Text('Add example sentences for lessons'),
              onTap: () {
                Navigator.pop(context);
                _showAddExampleSentenceDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flash_on),
              title: const Text('Add Flashcard'),
              subtitle: const Text('Create flashcards for lesson practice'),
              onTap: () {
                Navigator.pop(context);
                _showAddFlashcardDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddExampleSentenceDialog() {
    final japaneseController = TextEditingController();
    final romajiController = TextEditingController();
    final englishController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Example Sentence'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: japaneseController,
                  decoration: const InputDecoration(
                    labelText: 'Japanese Sentence',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Japanese sentence is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: romajiController,
                  decoration: const InputDecoration(
                    labelText: 'Romaji (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: englishController,
                  decoration: const InputDecoration(
                    labelText: 'English Translation',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'English translation is required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _createExampleSentence(
                  japaneseController.text.trim(),
                  romajiController.text.trim(),
                  englishController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add Sentence'),
          ),
        ],
      ),
    );
  }

  void _showAddFlashcardDialog() {
    final frontController = TextEditingController();
    final backController = TextEditingController();
    String selectedCategory = _lessonData!['category'] ?? 'Greetings';
    final formKey = GlobalKey<FormState>();

    final categories = [
      'Greetings',
      'Basic Nouns',
      'Basic Verbs',
      'Basic Adjectives',
      'Time Expressions'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Flashcard'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: frontController,
                  decoration: const InputDecoration(
                    labelText: 'Front (Japanese)',
                    border: OutlineInputBorder(),
                    hintText: 'Enter Japanese text or word',
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Front text is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: backController,
                  decoration: const InputDecoration(
                    labelText: 'Back (English)',
                    border: OutlineInputBorder(),
                    hintText: 'Enter English translation',
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Back text is required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) => selectedCategory = value!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _createFlashcard(
                  frontController.text.trim(),
                  backController.text.trim(),
                  selectedCategory,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add Flashcard'),
          ),
        ],
      ),
    );
  }

  void _showEditExampleSentenceDialog(Map<String, dynamic> sentence) {
    final japaneseController = TextEditingController(text: sentence['japanese'] ?? '');
    final romajiController = TextEditingController(text: sentence['romaji'] ?? '');
    final englishController = TextEditingController(text: sentence['english'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Example Sentence'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: japaneseController,
                  decoration: const InputDecoration(
                    labelText: 'Japanese Sentence',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Japanese sentence is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: romajiController,
                  decoration: const InputDecoration(
                    labelText: 'Romaji (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: englishController,
                  decoration: const InputDecoration(
                    labelText: 'English Translation',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'English translation is required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _updateExampleSentence(
                  sentence['id'],
                  japaneseController.text.trim(),
                  romajiController.text.trim(),
                  englishController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteExampleSentenceDialog(Map<String, dynamic> sentence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Example Sentence'),
        content: Text(
            'Are you sure you want to delete this example sentence?\n\n"${sentence['japanese']}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _deleteExampleSentence(sentence['id']);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _createExampleSentence(String japanese, String romaji, String english) async {
    try {
      final sentence = {
        'japanese': japanese,
        'romaji': romaji,
        'english': english,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _db.child('lessons/${widget.lessonId}/example_sentences').push().set(sentence);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Example sentence successfully created!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        _loadLessonData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create example sentence: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _createFlashcard(String front, String back, String category) async {
    try {
      final flashcard = {
        'front': front,
        'back': back,
        'category_id': category,
        'created_at': DateTime.now().toIso8601String(),
        'last_reviewed': DateTime.now().toIso8601String(),
        'review_count': 0,
        'correct_count': 0,
      };

      await _db.child('flashcards').push().set(flashcard);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Flashcard successfully created!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create flashcard: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _updateExampleSentence(
      String sentenceId, String japanese, String romaji, String english) async {
    try {
      final sentence = {
        'japanese': japanese,
        'romaji': romaji,
        'english': english,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _db.child('lessons/${widget.lessonId}/example_sentences/$sentenceId').update(sentence);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Example sentence successfully updated!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        _loadLessonData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update example sentence: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _deleteExampleSentence(String sentenceId) async {
    try {
      await _db.child('lessons/${widget.lessonId}/example_sentences/$sentenceId').remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Example sentence successfully deleted!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        _loadLessonData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete example sentence: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }
}

class SuperAdminQuizDetailsScreen extends StatefulWidget {
  final String quizId;
  const SuperAdminQuizDetailsScreen({super.key, required this.quizId});

  @override
  State<SuperAdminQuizDetailsScreen> createState() => _SuperAdminQuizDetailsScreenState();
}

class _SuperAdminQuizDetailsScreenState extends State<SuperAdminQuizDetailsScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  Map<String, dynamic>? _quizData;
  List<QuizQuestion> _questions = [];

  // Form controllers for question management
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _option1Controller = TextEditingController();
  final TextEditingController _option2Controller = TextEditingController();
  final TextEditingController _option3Controller = TextEditingController();
  final TextEditingController _option4Controller = TextEditingController();
  final TextEditingController _explanationController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController(text: '10');
  int _correctAnswerIndex = 0;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _option1Controller.dispose();
    _option2Controller.dispose();
    _option3Controller.dispose();
    _option4Controller.dispose();
    _explanationController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _loadQuizData() async {
    setState(() => _isLoading = true);
    try {
      final quizSnapshot = await _db.child('admin_quizzes/${widget.quizId}').get();

      if (quizSnapshot.exists) {
        setState(() {
          _quizData = Map<String, dynamic>.from(quizSnapshot.value as Map);
          // Parse questions from the quiz data
          final questionsData = _quizData!['questions'] as List? ?? [];
          _questions = questionsData.map((q) {
            if (q is Map<String, dynamic>) {
              return QuizQuestion.fromMap(q);
            } else if (q is Map<dynamic, dynamic>) {
              return QuizQuestion.fromMap(Map<String, dynamic>.from(q));
            }
            return QuizQuestion(
              id: 'q_${DateTime.now().millisecondsSinceEpoch}',
              question: 'Question',
              options: ['Option 1', 'Option 2', 'Option 3', 'Option 4'],
              correctAnswerIndex: 0,
              explanation: '',
            );
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading quiz data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_quizData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz Details')),
        body: const Center(child: Text('Quiz not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_quizData!['title'] ?? 'Quiz Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddQuestionDialog,
            tooltip: 'Add Question',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuizData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quiz Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.label, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          _quizData!['level'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.category, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          _quizData!['category'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _quizData!['description'] ?? 'No description',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.orange[600], size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Time Limit: ${_quizData!['timeLimit'] ?? 0} minutes',
                          style: TextStyle(
                            color: Colors.orange[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.grade, color: Colors.purple[600], size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Passing Score: ${_quizData!['passingScore'] ?? 0}%',
                          style: TextStyle(
                            color: Colors.purple[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Questions Management Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Questions (${_questions.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddQuestionDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Question'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Questions List
            if (_questions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No questions yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add questions to make this quiz functional',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddQuestionDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Question'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._questions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      question.question,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Options: ${question.options.length}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        if (question.explanation.isNotEmpty)
                          Text(
                            'Explanation: ${question.explanation}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          'Points: ${question.points}',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: const Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: const Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditQuestionDialog(question, index);
                        } else if (value == 'delete') {
                          _showDeleteQuestionDialog(question, index);
                        }
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _showAddQuestionDialog() {
    // Reset form controllers
    _questionController.clear();
    _option1Controller.clear();
    _option2Controller.clear();
    _option3Controller.clear();
    _option4Controller.clear();
    _explanationController.clear();
    _pointsController.text = '10';
    _correctAnswerIndex = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Add New Question',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _questionController,
                              decoration: const InputDecoration(
                                labelText: 'Question Text',
                                border: OutlineInputBorder(),
                                hintText: 'Enter your question here...',
                              ),
                              maxLines: 3,
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Question is required' : null,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Answer Options',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _option1Controller,
                              decoration: const InputDecoration(
                                labelText: 'Option 1',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Option 1 is required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _option2Controller,
                              decoration: const InputDecoration(
                                labelText: 'Option 2',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Option 2 is required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _option3Controller,
                              decoration: const InputDecoration(
                                labelText: 'Option 3',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Option 3 is required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _option4Controller,
                              decoration: const InputDecoration(
                                labelText: 'Option 4',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Option 4 is required' : null,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Correct Answer',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: _correctAnswerIndex,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 0,
                                  child: Text(
                                      'Option 1: ${_option1Controller.text.isEmpty ? 'Option 1' : _option1Controller.text}'),
                                ),
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text(
                                      'Option 2: ${_option2Controller.text.isEmpty ? 'Option 2' : _option2Controller.text}'),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text(
                                      'Option 3: ${_option3Controller.text.isEmpty ? 'Option 3' : _option3Controller.text}'),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text(
                                      'Option 4: ${_option4Controller.text.isEmpty ? 'Option 4' : _option4Controller.text}'),
                                ),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  _correctAnswerIndex = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _explanationController,
                              decoration: const InputDecoration(
                                labelText: 'Explanation (Optional)',
                                border: OutlineInputBorder(),
                                hintText: 'Explain why this is the correct answer...',
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _pointsController,
                              decoration: const InputDecoration(
                                labelText: 'Points',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Points is required';
                                final points = int.tryParse(value);
                                if (points == null || points <= 0) return 'Enter valid points';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _addQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Add Question'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditQuestionDialog(QuizQuestion question, int index) {
    // Pre-fill the form controllers with existing question data
    _questionController.text = question.question;
    _option1Controller.text = question.options[0];
    _option2Controller.text = question.options[1];
    _option3Controller.text = question.options[2];
    _option4Controller.text = question.options[3];
    _explanationController.text = question.explanation;
    _pointsController.text = question.points.toString();
    _correctAnswerIndex = question.correctAnswerIndex;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit, color: Theme.of(context).colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Edit Question ${index + 1}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _questionController,
                              decoration: const InputDecoration(
                                labelText: 'Question Text',
                                border: OutlineInputBorder(),
                                hintText: 'Enter your question here...',
                              ),
                              maxLines: 3,
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Question is required' : null,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Answer Options',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _option1Controller,
                              decoration: const InputDecoration(
                                labelText: 'Option 1',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Option 1 is required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _option2Controller,
                              decoration: const InputDecoration(
                                labelText: 'Option 2',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Option 2 is required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _option3Controller,
                              decoration: const InputDecoration(
                                labelText: 'Option 3',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Option 3 is required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _option4Controller,
                              decoration: const InputDecoration(
                                labelText: 'Option 4',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Option 4 is required' : null,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Correct Answer',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: _correctAnswerIndex,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 0,
                                  child: Text(
                                      'Option 1: ${_option1Controller.text.isEmpty ? 'Option 1' : _option1Controller.text}'),
                                ),
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text(
                                      'Option 2: ${_option2Controller.text.isEmpty ? 'Option 2' : _option2Controller.text}'),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text(
                                      'Option 3: ${_option3Controller.text.isEmpty ? 'Option 3' : _option3Controller.text}'),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text(
                                      'Option 4: ${_option4Controller.text.isEmpty ? 'Option 4' : _option4Controller.text}'),
                                ),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  _correctAnswerIndex = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _explanationController,
                              decoration: const InputDecoration(
                                labelText: 'Explanation (Optional)',
                                border: OutlineInputBorder(),
                                hintText: 'Explain why this is the correct answer...',
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _pointsController,
                              decoration: const InputDecoration(
                                labelText: 'Points',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Points is required';
                                final points = int.tryParse(value);
                                if (points == null || points <= 0) return 'Enter valid points';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[400],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateQuestion(index),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                          child: const Text('Update Question'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteQuestionDialog(QuizQuestion question, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: Text(
            'Are you sure you want to delete question ${index + 1}?\n\n"${question.question}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _deleteQuestion(index);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _addQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final question = QuizQuestion(
        id: 'q_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}',
        question: _questionController.text.trim(),
        options: [
          _option1Controller.text.trim(),
          _option2Controller.text.trim(),
          _option3Controller.text.trim(),
          _option4Controller.text.trim(),
        ],
        correctAnswerIndex: _correctAnswerIndex,
        explanation: _explanationController.text.trim(),
        points: int.parse(_pointsController.text),
      );

      // Add question to the list
      setState(() {
        _questions.add(question);
      });

      // Update Firebase
      await _db.child('admin_quizzes/${widget.quizId}').update({
        'questions': _questions.map((q) => q.toMap()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Question added successfully!'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add question: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _updateQuestion(int index) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Create updated question object
      final updatedQuestion = QuizQuestion(
        id: _questions[index].id, // Keep the same ID
        question: _questionController.text.trim(),
        options: [
          _option1Controller.text.trim(),
          _option2Controller.text.trim(),
          _option3Controller.text.trim(),
          _option4Controller.text.trim(),
        ],
        correctAnswerIndex: _correctAnswerIndex,
        explanation: _explanationController.text.trim(),
        points: int.parse(_pointsController.text),
        imageUrl: _questions[index].imageUrl, // Keep existing image URL if any
      );

      // Update the question in the local list
      setState(() {
        _questions[index] = updatedQuestion;
      });

      // Update Firebase
      await _db.child('admin_quizzes/${widget.quizId}').update({
        'questions': _questions.map((q) => q.toMap()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Question updated successfully!'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update question: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _deleteQuestion(int index) async {
    try {
      setState(() {
        _questions.removeAt(index);
      });

      await _db.child('admin_quizzes/${widget.quizId}').update({
        'questions': _questions.map((q) => q.toMap()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Question deleted successfully!'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete question: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}

class SuperAdminClassDetailsScreen extends StatelessWidget {
  final String classId;
  const SuperAdminClassDetailsScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseDatabase.instance.ref();
    return Scaffold(
      appBar: AppBar(title: const Text('Class Details')),
      body: FutureBuilder<DataSnapshot>(
        future: db.child('classes/$classId').get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || !snap.data!.exists) return const Center(child: Text('Not found'));
          final Map<dynamic, dynamic> c = Map<dynamic, dynamic>.from(snap.data!.value as Map);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _DT('Name Section', c['nameSection']?.toString() ?? ''),
                _DT('Year Range', c['yearRange']?.toString() ?? ''),
                _DT('Class Code', c['classCode']?.toString() ?? ''),
                const SizedBox(height: 16),
                const Divider(),
                const Text('Members', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                FutureBuilder<DataSnapshot>(
                  future: db.child('classMembers/$classId').get(),
                  builder: (context, ms) {
                    if (ms.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (!ms.hasData || !ms.data!.exists) return const Text('No members');
                    final Map<dynamic, dynamic> m =
                        Map<dynamic, dynamic>.from(ms.data!.value as Map);
                    final entries = m.entries.toList();
                    return Column(
                      children: entries
                          .map((e) => FutureBuilder<DataSnapshot>(
                                future: db.child('users/${e.key}').get(),
                                builder: (context, us) {
                                  if (!us.hasData || !us.data!.exists)
                                    return const SizedBox.shrink();
                                  final Map<dynamic, dynamic> u =
                                      Map<dynamic, dynamic>.from(us.data!.value as Map);
                                  final name = ((u['firstName'] ?? '').toString() +
                                          ' ' +
                                          (u['lastName'] ?? '').toString())
                                      .trim();
                                  return ListTile(
                                    leading: const Icon(Icons.person),
                                    title:
                                        Text(name.isEmpty ? (u['email']?.toString() ?? '') : name),
                                    subtitle: Text(u['email']?.toString() ?? ''),
                                  );
                                },
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DT extends StatelessWidget {
  final String k;
  final String v;
  const _DT(this.k, this.v);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child:
                  Text(k, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
