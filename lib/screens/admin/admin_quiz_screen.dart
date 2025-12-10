import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/models/admin_quiz_model.dart';
import 'package:nihongo_japanese_app/services/auth_service.dart';
import 'package:nihongo_japanese_app/services/teacher_activity_service.dart';
import 'package:nihongo_japanese_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class AdminQuizScreen extends StatefulWidget {
  final String level;
  final String category;
  final Color cardColor;

  const AdminQuizScreen({
    super.key,
    required this.level,
    required this.category,
    required this.cardColor,
  });

  @override
  State<AdminQuizScreen> createState() => _AdminQuizScreenState();
}

class _AdminQuizScreenState extends State<AdminQuizScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  // Get theme icon for display
  IconData _getThemeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.phone_android;
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.sakura:
        return Icons.local_florist;
      case AppThemeMode.matcha:
        return Icons.eco;
      case AppThemeMode.sunset:
        return Icons.wb_sunny;
      case AppThemeMode.ocean:
        return Icons.water;
      case AppThemeMode.lavender:
        return Icons.spa;
      case AppThemeMode.autumn:
        return Icons.park;
      case AppThemeMode.fuji:
        return Icons.landscape;
      case AppThemeMode.blueLight:
        return Icons.blur_on;
    }
  }

  // Form controllers for quiz
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _timeLimitController = TextEditingController();
  final _passingScoreController = TextEditingController();

  // Question form controllers
  final _questionController = TextEditingController();
  final _option1Controller = TextEditingController();
  final _option2Controller = TextEditingController();
  final _option3Controller = TextEditingController();
  final _option4Controller = TextEditingController();
  final _explanationController = TextEditingController();
  final _pointsController = TextEditingController();
  int _correctAnswerIndex = 0;

  List<AdminQuiz> _quizzes = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _timeLimitController.text = '30';
    _passingScoreController.text = '70';
    _searchController.addListener(_filterQuizzes);
    _initializeAndLoadQuizzes();
  }

  Future<void> _initializeAndLoadQuizzes() async {
    await _initializeFirebaseStructure();
    await _loadQuizzes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _timeLimitController.dispose();
    _passingScoreController.dispose();
    _searchController.dispose();

    // Question controllers
    _questionController.dispose();
    _option1Controller.dispose();
    _option2Controller.dispose();
    _option3Controller.dispose();
    _option4Controller.dispose();
    _explanationController.dispose();
    _pointsController.dispose();

    super.dispose();
  }

  void _filterQuizzes() {
    print('🔍 Filtering quizzes. Search text: "${_searchController.text}"');
    print('📊 Total quizzes before filtering: ${_quizzes.length}');
    setState(() {});
    print('📊 Filtered quizzes count: ${_filteredQuizzes.length}');
  }

  Future<void> _loadQuizzes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('🔍 Loading quizzes for Level: ${widget.level}, Category: ${widget.category}');

      // First try to get all quizzes and filter locally for better reliability
      final snapshot = await FirebaseDatabase.instance.ref().child('admin_quizzes').once();

      print(
          '📡 Firebase response received: ${snapshot.snapshot.value != null ? 'Data exists' : 'No data'}');

      if (snapshot.snapshot.value != null) {
        final dynamic rawValue = snapshot.snapshot.value;
        print('📊 Raw Firebase data type: ${rawValue.runtimeType}');

        // Handle different data types safely
        if (rawValue is Map<dynamic, dynamic>) {
          print('📝 Processing ${rawValue.length} quiz entries from Firebase');

          final List<AdminQuiz> processedQuizzes = [];

          for (final entry in rawValue.entries) {
            try {
              final quiz = entry.value as Map<dynamic, dynamic>;
              final quizData = Map<String, dynamic>.from(quiz);
              quizData['id'] = entry.key as String;

              print(
                  '🔍 Checking quiz: ${quizData['title']} (${quizData['level']} - ${quizData['category']})');
              print('🎯 Looking for: ${widget.level} - ${widget.category}');

              // Check if this quiz matches our level and category
              if (quizData['level'] == widget.level && quizData['category'] == widget.category) {
                print('✅ Quiz matches! Processing: ${quizData['title']}');
                print('📝 Raw questions data: ${quizData['questions']}');
                print('📝 Questions type: ${quizData['questions']?.runtimeType}');

                // Handle different question data structures
                if (quizData['questions'] is Map) {
                  // Questions stored as a map with numeric keys (0, 1, 2, etc.)
                  final questionsMap = quizData['questions'] as Map<dynamic, dynamic>;
                  print('📝 Questions map keys: ${questionsMap.keys.toList()}');
                  print(
                      '📝 Questions map values: ${questionsMap.values.map((v) => v is Map ? (v)['question'] : v).toList()}');

                  // Convert map to list, maintaining order by numeric keys
                  final questionsList = <dynamic>[];
                  final sortedKeys = questionsMap.keys
                      .toList()
                      .where((key) =>
                          key is int || key is String && int.tryParse(key.toString()) != null)
                      .toList()
                    ..sort((a, b) {
                      final aInt = a is int ? a : int.parse(a.toString());
                      final bInt = b is int ? b : int.parse(b.toString());
                      return aInt.compareTo(bInt);
                    });

                  for (final key in sortedKeys) {
                    questionsList.add(questionsMap[key]);
                  }

                  quizData['questions'] = questionsList;
                  print(
                      '🔄 Converted questions map to ordered list: ${questionsList.length} questions');
                } else if (quizData['questions'] is List) {
                  print(
                      '✅ Questions already in list format: ${(quizData['questions'] as List).length} questions');
                } else {
                  print('⚠️ Questions data is neither map nor list: ${quizData['questions']}');
                  quizData['questions'] = [];
                }

                print('📝 Final questions data before parsing: ${quizData['questions']}');
                print('📝 Questions data type: ${quizData['questions'].runtimeType}');

                try {
                  final adminQuiz = AdminQuiz.fromMap(quizData);
                  processedQuizzes.add(adminQuiz);
                  print(
                      '✅ Successfully processed quiz: ${adminQuiz.title} with ${adminQuiz.questions.length} questions');

                  // Debug each question
                  for (int i = 0; i < adminQuiz.questions.length; i++) {
                    final q = adminQuiz.questions[i];
                    print('📝 Question $i: ${q.question}');
                    print('📝 Options: ${q.options}');
                    print('📝 Correct: ${q.correctAnswerIndex}');
                  }
                } catch (e, stackTrace) {
                  print('❌ Error creating AdminQuiz: $e');
                  print('❌ Stack trace: $stackTrace');
                  print('❌ Quiz data that failed: $quizData');
                }
              } else {
                print('❌ Quiz does not match current selection');
              }
            } catch (e) {
              print('❌ Error processing quiz entry ${entry.key}: $e');
              print('Entry value: ${entry.value}');
            }
          }

          _quizzes = processedQuizzes;
          print(
              '🎉 Successfully loaded ${_quizzes.length} quizzes for ${widget.level} - ${widget.category}');
        } else {
          print('❌ Unexpected data type from Firebase: ${rawValue.runtimeType}');
          _quizzes = [];
        }
      } else {
        // No quizzes exist yet - this is normal for a new system
        print('📭 No admin_quizzes node found in Firebase - this is normal for a new system');
        _quizzes = [];
      }
    } catch (e) {
      print('❌ Error loading quizzes: $e');
      setState(() {
        _errorMessage = 'Failed to load quizzes: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('🏁 Finished loading quizzes. Total loaded: ${_quizzes.length}');
    }
  }

  String _generateQuizId() {
    return 'quiz_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  Future<void> _showManageQuestionsDialog(AdminQuiz quiz) async {
    print('🔍 Opening question management screen for quiz: ${quiz.title}');
    print('📊 Quiz has ${quiz.questions.length} questions');

    bool isAdmin = await _authService.isAdmin();
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access denied: Administrator privileges required.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    // Navigate to a full-screen modal
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            QuestionManagementScreen(quiz: quiz),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        barrierDismissible: false,
        fullscreenDialog: true,
      ),
    );

    // Refresh the quiz list after returning from question management
    _loadQuizzes();
  }

  Future<void> _showEditQuizDialog(AdminQuiz quiz) async {
    print('🔍 Opening edit quiz dialog for quiz: ${quiz.title}');

    bool isAdmin = await _authService.isAdmin();
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access denied: Administrator privileges required.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    // Pre-fill the form controllers with existing quiz data
    _titleController.text = quiz.title;
    _descriptionController.text = quiz.description;
    _timeLimitController.text = quiz.timeLimit.toString();
    _passingScoreController.text = quiz.passingScore.toString();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit, color: Theme.of(context).colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Edit Quiz: ${quiz.title}',
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
                  const SizedBox(height: 20),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Quiz Title',
                                border: OutlineInputBorder(),
                                hintText: 'Enter quiz title...',
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Title is required' : null,
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                                hintText: 'Enter quiz description...',
                              ),
                              maxLines: 3,
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Description is required' : null,
                            ),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _timeLimitController,
                                    decoration: const InputDecoration(
                                      labelText: 'Time Limit (minutes)',
                                      border: OutlineInputBorder(),
                                      hintText: '30',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Time limit is required';
                                      }
                                      final time = int.tryParse(value);
                                      if (time == null || time <= 0) {
                                        return 'Please enter a valid time limit';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _passingScoreController,
                                    decoration: const InputDecoration(
                                      labelText: 'Passing Score (%)',
                                      border: OutlineInputBorder(),
                                      hintText: '70',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Passing score is required';
                                      }
                                      final score = int.tryParse(value);
                                      if (score == null || score < 0 || score > 100) {
                                        return 'Please enter a valid score (0-100)';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Quiz status toggle
                            Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Quiz Status:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: quiz.isActive,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      // This will be handled when saving
                                    });
                                  },
                                  activeColor: Theme.of(context).colorScheme.primary,
                                ),
                                Text(
                                  quiz.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: quiz.isActive
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Quiz info display
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quiz Information:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.category,
                                          color: Theme.of(context).colorScheme.primary, size: 16),
                                      const SizedBox(width: 8),
                                      Text('Category: ${quiz.category}'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.school,
                                          color: Theme.of(context).colorScheme.secondary, size: 16),
                                      const SizedBox(width: 8),
                                      Text('Level: ${quiz.level}'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.question_answer,
                                          color: Colors.purple[600], size: 16),
                                      const SizedBox(width: 8),
                                      Text('Questions: ${quiz.questions.length}'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          color: Theme.of(context).colorScheme.primary, size: 16),
                                      const SizedBox(width: 8),
                                      Text('Created: ${quiz.createdAt.toString().split(' ')[0]}'),
                                    ],
                                  ),
                                ],
                              ),
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
                            backgroundColor: Theme.of(context).colorScheme.outline,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateQuiz(quiz),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                          child: const Text('Update Quiz'),
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

  Future<void> _updateQuiz(AdminQuiz quiz) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Create updated quiz object
      final updatedQuiz = quiz.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        timeLimit: int.parse(_timeLimitController.text),
        passingScore: int.parse(_passingScoreController.text),
        updatedAt: DateTime.now(),
      );

      // Update Firebase
      await FirebaseDatabase.instance.ref().child('admin_quizzes').child(quiz.id).update({
        'title': updatedQuiz.title,
        'description': updatedQuiz.description,
        'timeLimit': updatedQuiz.timeLimit,
        'passingScore': updatedQuiz.passingScore,
        'updatedAt': updatedQuiz.updatedAt!.toIso8601String(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Quiz updated successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      // Refresh the quiz list
      _loadQuizzes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update quiz: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _initializeFirebaseStructure() async {
    try {
      // Check if admin_quizzes node exists, if not create it
      final snapshot = await FirebaseDatabase.instance.ref().child('admin_quizzes').once();

      if (snapshot.snapshot.value == null) {
        print('Initializing admin_quizzes structure in Firebase');
        // Create a placeholder entry to initialize the structure
        await FirebaseDatabase.instance.ref().child('admin_quizzes').child('_placeholder').set({
          'id': '_placeholder',
          'title': 'System Initialized',
          'description': 'Quiz system has been initialized',
          'category': 'System',
          'level': 'System',
          'questions': [],
          'timeLimit': 0,
          'passingScore': 0,
          'isActive': false,
          'createdAt': DateTime.now().toIso8601String(),
        });

        // Remove the placeholder
        await FirebaseDatabase.instance.ref().child('admin_quizzes').child('_placeholder').remove();

        print('Firebase structure initialized successfully');
      }
    } catch (e) {
      print('Error initializing Firebase structure: $e');
    }
  }

  Future<void> _showCreateQuizDialog() async {
    bool isAdmin = await _authService.isAdmin();
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access denied: Administrator privileges required.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    _titleController.clear();
    _descriptionController.clear();
    _timeLimitController.text = '30';
    _passingScoreController.text = '70';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Create New Quiz',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Level: ${widget.level} | Category: ${widget.category}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Quiz Title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty ? 'Title is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) =>
                              value == null || value.isEmpty ? 'Description is required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _timeLimitController,
                                decoration: const InputDecoration(
                                  labelText: 'Time Limit (minutes)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Time limit is required';
                                  }
                                  final time = int.tryParse(value);
                                  if (time == null || time <= 0) {
                                    return 'Enter a valid time limit';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _passingScoreController,
                                decoration: const InputDecoration(
                                  labelText: 'Passing Score (%)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Passing score is required';
                                  }
                                  final score = int.tryParse(value);
                                  if (score == null || score < 0 || score > 100) {
                                    return 'Enter a valid score (0-100)';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Great! After creating the quiz, you can add questions using the "Manage Questions" button.',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _createQuiz(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Create Quiz'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final quiz = AdminQuiz(
        id: _generateQuizId(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: widget.category,
        level: widget.level,
        questions: [], // Empty questions list for now
        timeLimit: int.parse(_timeLimitController.text),
        passingScore: int.parse(_passingScoreController.text),
        createdAt: DateTime.now(),
      );

      await FirebaseDatabase.instance.ref().child('admin_quizzes').child(quiz.id).set(quiz.toMap());

      // Log teacher activity
      try {
        await TeacherActivityService().logQuizCreated(
          quiz.id,
          quiz.title,
        );
      } catch (activityError) {
        print('Error logging quiz creation activity: $activityError');
      }

      if (mounted) {
        Navigator.pop(context);
        _titleController.clear();
        _descriptionController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Quiz successfully created.'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        _loadQuizzes(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to create quiz: $e';
        if (e.toString().contains('permission_denied')) {
          errorMessage = 'You do not have permission to create quizzes.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _deleteQuiz(AdminQuiz quiz) async {
    bool isAdmin = await _authService.isAdmin();
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access denied: Administrator privileges required.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz'),
        content:
            Text('Are you sure you want to delete "${quiz.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await FirebaseDatabase.instance.ref().child('admin_quizzes').child(quiz.id).remove();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Quiz successfully deleted.'),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
          _loadQuizzes(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete quiz: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleQuizStatus(AdminQuiz quiz) async {
    bool isAdmin = await _authService.isAdmin();
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access denied: Administrator privileges required.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    try {
      final updatedQuiz = quiz.copyWith(
        isActive: !quiz.isActive,
        updatedAt: DateTime.now(),
      );

      await FirebaseDatabase.instance.ref().child('admin_quizzes').child(quiz.id).update({
        'isActive': updatedQuiz.isActive,
        'updatedAt': updatedQuiz.updatedAt!.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Quiz ${updatedQuiz.isActive ? 'activated' : 'deactivated'} successfully.'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        _loadQuizzes(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update quiz status: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  List<AdminQuiz> get _filteredQuizzes {
    if (_searchController.text.isEmpty) {
      return _quizzes;
    }
    return _quizzes.where((quiz) {
      return quiz.title.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          quiz.description.toLowerCase().contains(_searchController.text.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin - Quiz Management'),
        backgroundColor: widget.cardColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Add theme switcher button
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return PopupMenuButton<AppThemeMode>(
                icon: const Icon(Icons.palette),
                tooltip: 'Change Theme',
                onSelected: (AppThemeMode theme) {
                  themeProvider.setAppTheme(theme);
                },
                itemBuilder: (BuildContext context) {
                  return AppThemeMode.values.map((AppThemeMode theme) {
                    return PopupMenuItem<AppThemeMode>(
                      value: theme,
                      child: Row(
                        children: [
                          Icon(
                            _getThemeIcon(theme),
                            color: themeProvider.appThemeMode == theme
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            themeProvider.getThemeName(theme),
                            style: TextStyle(
                              color: themeProvider.appThemeMode == theme
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: themeProvider.appThemeMode == theme
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
              );
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 1200),
        margin: EdgeInsets.symmetric(
          horizontal: isDesktop
              ? 32
              : isTablet
                  ? 24
                  : 16,
        ),
        child: Column(
          children: [
            // Search and Create Button
            Container(
              margin: EdgeInsets.only(
                top: isDesktop
                    ? 24
                    : isTablet
                        ? 20
                        : 16,
                bottom: isDesktop
                    ? 24
                    : isTablet
                        ? 20
                        : 16,
              ),
              child: Column(
                children: [
                  if (isDesktop || isTablet)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search quizzes...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 20 : 16,
                                vertical: isDesktop ? 16 : 12,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isDesktop ? 24 : 20),
                        ElevatedButton.icon(
                          onPressed: _showCreateQuizDialog,
                          icon: const Icon(Icons.add),
                          label: Text(
                            'Create Quiz',
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 24 : 20,
                              vertical: isDesktop ? 16 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search quizzes...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showCreateQuizDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Quiz'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Quiz List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: isDesktop
                                    ? 80
                                    : isTablet
                                        ? 72
                                        : 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(
                                  height: isDesktop
                                      ? 24
                                      : isTablet
                                          ? 20
                                          : 16),
                              Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: isDesktop
                                      ? 18
                                      : isTablet
                                          ? 16
                                          : 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(
                                  height: isDesktop
                                      ? 24
                                      : isTablet
                                          ? 20
                                          : 16),
                              ElevatedButton(
                                onPressed: _loadQuizzes,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 32 : 24,
                                    vertical: isDesktop ? 16 : 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _filteredQuizzes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.quiz_outlined,
                                    size: isDesktop
                                        ? 80
                                        : isTablet
                                            ? 72
                                            : 64,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(
                                      height: isDesktop
                                          ? 24
                                          : isTablet
                                              ? 20
                                              : 16),
                                  Text(
                                    'No quizzes found',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: isDesktop
                                          ? 22
                                          : isTablet
                                              ? 20
                                              : 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(
                                      height: isDesktop
                                          ? 12
                                          : isTablet
                                              ? 10
                                              : 8),
                                  Text(
                                    'Create your first quiz to get started!',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: isDesktop
                                          ? 16
                                          : isTablet
                                              ? 14
                                              : 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  // Debug info
                                  SizedBox(
                                      height: isDesktop
                                          ? 24
                                          : isTablet
                                              ? 20
                                              : 16),
                                  Container(
                                    padding: EdgeInsets.all(isDesktop
                                        ? 20
                                        : isTablet
                                            ? 16
                                            : 12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Debug Information:',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isDesktop
                                                ? 16
                                                : isTablet
                                                    ? 14
                                                    : 12,
                                          ),
                                        ),
                                        SizedBox(
                                            height: isDesktop
                                                ? 16
                                                : isTablet
                                                    ? 12
                                                    : 8),
                                        Text(
                                          'Total quizzes: ${_quizzes.length}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontSize: isDesktop
                                                ? 14
                                                : isTablet
                                                    ? 12
                                                    : 10,
                                          ),
                                        ),
                                        Text(
                                          'Filtered quizzes: ${_filteredQuizzes.length}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontSize: isDesktop
                                                ? 14
                                                : isTablet
                                                    ? 12
                                                    : 10,
                                          ),
                                        ),
                                        Text(
                                          'Search text: "${_searchController.text}"',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontSize: isDesktop
                                                ? 12
                                                : isTablet
                                                    ? 10
                                                    : 8,
                                          ),
                                        ),
                                        Text(
                                          'Level: ${widget.level}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontSize: isDesktop
                                                ? 14
                                                : isTablet
                                                    ? 12
                                                    : 10,
                                          ),
                                        ),
                                        Text(
                                          'Category: ${widget.category}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontSize: isDesktop
                                                ? 14
                                                : isTablet
                                                    ? 12
                                                    : 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop
                                    ? 0
                                    : isTablet
                                        ? 0
                                        : 0,
                              ),
                              itemCount: _filteredQuizzes.length,
                              itemBuilder: (context, index) {
                                final quiz = _filteredQuizzes[index];
                                return Container(
                                  margin: EdgeInsets.only(
                                      bottom: isDesktop
                                          ? 20
                                          : isTablet
                                              ? 18
                                              : 16),
                                  child: Card(
                                    elevation: 6,
                                    shadowColor:
                                        Theme.of(context).colorScheme.shadow.withOpacity(0.2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.all(isDesktop
                                          ? 24
                                          : isTablet
                                              ? 20
                                              : 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Quiz header
                                          Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(isDesktop
                                                    ? 16
                                                    : isTablet
                                                        ? 12
                                                        : 8),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.2),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.quiz,
                                                  color: Theme.of(context).colorScheme.primary,
                                                  size: isDesktop
                                                      ? 28
                                                      : isTablet
                                                          ? 24
                                                          : 20,
                                                ),
                                              ),
                                              SizedBox(
                                                  width: isDesktop
                                                      ? 20
                                                      : isTablet
                                                          ? 16
                                                          : 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            quiz.title,
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: isDesktop
                                                                  ? 20
                                                                  : isTablet
                                                                      ? 18
                                                                      : 16,
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: EdgeInsets.symmetric(
                                                            horizontal: isDesktop
                                                                ? 12
                                                                : isTablet
                                                                    ? 10
                                                                    : 8,
                                                            vertical: isDesktop
                                                                ? 6
                                                                : isTablet
                                                                    ? 5
                                                                    : 4,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: quiz.isActive
                                                                ? Theme.of(context)
                                                                    .colorScheme
                                                                    .primary
                                                                    .withOpacity(0.1)
                                                                : Theme.of(context)
                                                                    .colorScheme
                                                                    .outline
                                                                    .withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(
                                                              color: quiz.isActive
                                                                  ? Theme.of(context)
                                                                      .colorScheme
                                                                      .primary
                                                                      .withOpacity(0.3)
                                                                  : Theme.of(context)
                                                                      .colorScheme
                                                                      .outline
                                                                      .withOpacity(0.3),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            quiz.isActive ? 'Active' : 'Inactive',
                                                            style: TextStyle(
                                                              color: quiz.isActive
                                                                  ? Theme.of(context)
                                                                      .colorScheme
                                                                      .primary
                                                                  : Theme.of(context)
                                                                      .colorScheme
                                                                      .outline,
                                                              fontSize: isDesktop
                                                                  ? 14
                                                                  : isTablet
                                                                      ? 12
                                                                      : 10,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(
                                                        height: isDesktop
                                                            ? 12
                                                            : isTablet
                                                                ? 10
                                                                : 8),
                                                    Text(
                                                      quiz.description,
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: isDesktop
                                                            ? 16
                                                            : isTablet
                                                                ? 14
                                                                : 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),

                                          SizedBox(
                                              height: isDesktop
                                                  ? 20
                                                  : isTablet
                                                      ? 16
                                                      : 12),

                                          // Quiz info chips
                                          Wrap(
                                            spacing: isDesktop
                                                ? 12
                                                : isTablet
                                                    ? 10
                                                    : 8,
                                            runSpacing: isDesktop
                                                ? 8
                                                : isTablet
                                                    ? 6
                                                    : 4,
                                            children: [
                                              _buildInfoChip(
                                                '${quiz.questions.length} Questions',
                                                Icons.question_answer,
                                                Colors.blue,
                                                isDesktop,
                                                isTablet,
                                              ),
                                              _buildInfoChip(
                                                '${quiz.timeLimit} min',
                                                Icons.timer,
                                                Colors.orange,
                                                isDesktop,
                                                isTablet,
                                              ),
                                              _buildInfoChip(
                                                '${quiz.passingScore}% Pass',
                                                Icons.check_circle,
                                                Colors.green,
                                                isDesktop,
                                                isTablet,
                                              ),
                                            ],
                                          ),

                                          SizedBox(
                                              height: isDesktop
                                                  ? 20
                                                  : isTablet
                                                      ? 16
                                                      : 12),

                                          // Action buttons
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _showManageQuestionsDialog(quiz),
                                                  icon: Icon(
                                                    Icons.question_answer,
                                                    size: isDesktop
                                                        ? 20
                                                        : isTablet
                                                            ? 18
                                                            : 16,
                                                  ),
                                                  label: Text(
                                                    'Manage Questions',
                                                    style: TextStyle(
                                                      fontSize: isDesktop
                                                          ? 16
                                                          : isTablet
                                                              ? 14
                                                              : 12,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.purple[600],
                                                    foregroundColor: Colors.white,
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: isDesktop
                                                          ? 20
                                                          : isTablet
                                                              ? 16
                                                              : 12,
                                                      vertical: isDesktop
                                                          ? 12
                                                          : isTablet
                                                              ? 10
                                                              : 8,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                  width: isDesktop
                                                      ? 16
                                                      : isTablet
                                                          ? 12
                                                          : 8),
                                              PopupMenuButton<String>(
                                                icon: Icon(
                                                  Icons.more_vert,
                                                  size: isDesktop
                                                      ? 24
                                                      : isTablet
                                                          ? 22
                                                          : 20,
                                                ),
                                                onSelected: (value) {
                                                  switch (value) {
                                                    case 'edit':
                                                      _showEditQuizDialog(quiz);
                                                      break;
                                                    case 'toggle':
                                                      _toggleQuizStatus(quiz);
                                                      break;
                                                    case 'delete':
                                                      _deleteQuiz(quiz);
                                                      break;
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.edit, color: Colors.blue),
                                                        const SizedBox(width: 8),
                                                        Text('Edit Quiz'),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'toggle',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          quiz.isActive
                                                              ? Icons.visibility_off
                                                              : Icons.visibility,
                                                          color: Colors.orange,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(quiz.isActive
                                                            ? 'Deactivate'
                                                            : 'Activate'),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.delete, color: Colors.red),
                                                        SizedBox(width: 8),
                                                        Text('Delete'),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color, bool isDesktop, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop
            ? 12
            : isTablet
                ? 10
                : 8,
        vertical: isDesktop
            ? 6
            : isTablet
                ? 5
                : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isDesktop
                ? 16
                : isTablet
                    ? 14
                    : 12,
            color: color,
          ),
          SizedBox(
              width: isDesktop
                  ? 6
                  : isTablet
                      ? 5
                      : 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: isDesktop
                  ? 14
                  : isTablet
                      ? 12
                      : 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Full-screen modal screen for question management
class QuestionManagementScreen extends StatefulWidget {
  final AdminQuiz quiz;

  const QuestionManagementScreen({
    super.key,
    required this.quiz,
  });

  @override
  State<QuestionManagementScreen> createState() => _QuestionManagementScreenState();
}

class _QuestionManagementScreenState extends State<QuestionManagementScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Get theme icon for display
  IconData _getThemeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.phone_android;
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.sakura:
        return Icons.local_florist;
      case AppThemeMode.matcha:
        return Icons.eco;
      case AppThemeMode.sunset:
        return Icons.wb_sunny;
      case AppThemeMode.ocean:
        return Icons.water;
      case AppThemeMode.lavender:
        return Icons.spa;
      case AppThemeMode.autumn:
        return Icons.park;
      case AppThemeMode.fuji:
        return Icons.landscape;
      case AppThemeMode.blueLight:
        return Icons.blur_on;
    }
  }

  // Form controllers for question
  final _questionController = TextEditingController();
  final _option1Controller = TextEditingController();
  final _option2Controller = TextEditingController();
  final _option3Controller = TextEditingController();
  final _option4Controller = TextEditingController();
  final _explanationController = TextEditingController();
  final _pointsController = TextEditingController();
  int _correctAnswerIndex = 0;

  List<QuizQuestion> _questions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.quiz.questions);
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

  Future<void> _refreshQuestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Reload the quiz to get updated questions
      final snapshot =
          await FirebaseDatabase.instance.ref().child('admin_quizzes').child(widget.quiz.id).once();

      if (snapshot.snapshot.value != null) {
        final updatedQuiz = AdminQuiz.fromMap(
          Map<String, dynamic>.from(snapshot.snapshot.value as Map),
        );
        setState(() {
          _questions = List.from(updatedQuiz.questions);
        });
      }
    } catch (e) {
      print('Error refreshing questions: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddQuestionDialog() async {
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
                            const SizedBox(height: 8),

                            // Option 1
                            Row(
                              children: [
                                Radio<int>(
                                  value: 0,
                                  groupValue: _correctAnswerIndex,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _correctAnswerIndex = value!;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _option1Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Option A',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value == null || value.isEmpty
                                        ? 'Option A is required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Option 2
                            Row(
                              children: [
                                Radio<int>(
                                  value: 1,
                                  groupValue: _correctAnswerIndex,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _correctAnswerIndex = value!;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _option2Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Option B',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value == null || value.isEmpty
                                        ? 'Option B is required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Option 3
                            Row(
                              children: [
                                Radio<int>(
                                  value: 2,
                                  groupValue: _correctAnswerIndex,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _correctAnswerIndex = value!;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _option3Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Option C',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value == null || value.isEmpty
                                        ? 'Option C is required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Option 4
                            Row(
                              children: [
                                Radio<int>(
                                  value: 3,
                                  groupValue: _correctAnswerIndex,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _correctAnswerIndex = value!;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _option4Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Option D',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value == null || value.isEmpty
                                        ? 'Option D is required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _explanationController,
                              decoration: const InputDecoration(
                                labelText: 'Explanation',
                                border: OutlineInputBorder(),
                                hintText: 'Explain why this answer is correct...',
                              ),
                              maxLines: 3,
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Explanation is required' : null,
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _pointsController,
                              decoration: const InputDecoration(
                                labelText: 'Points',
                                border: OutlineInputBorder(),
                                hintText: 'Points for correct answer',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Points are required' : null,
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
      await FirebaseDatabase.instance.ref().child('admin_quizzes').child(widget.quiz.id).update({
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

  Future<void> _deleteQuestion(int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        setState(() {
          _questions.removeAt(index);
        });

        await FirebaseDatabase.instance.ref().child('admin_quizzes').child(widget.quiz.id).update({
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
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _showEditQuestionDialog(QuizQuestion question, int index) async {
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
                            const SizedBox(height: 8),

                            // Option 1
                            Row(
                              children: [
                                Radio<int>(
                                  value: 0,
                                  groupValue: _correctAnswerIndex,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _correctAnswerIndex = value!;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _option1Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Option A',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value == null || value.isEmpty
                                        ? 'Option A is required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Option 2
                            Row(
                              children: [
                                Radio<int>(
                                  value: 1,
                                  groupValue: _correctAnswerIndex,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _correctAnswerIndex = value!;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _option2Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Option B',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value == null || value.isEmpty
                                        ? 'Option B is required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Option 3
                            Row(
                              children: [
                                Radio<int>(
                                  value: 2,
                                  groupValue: _correctAnswerIndex,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _correctAnswerIndex = value!;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _option3Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Option C',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value == null || value.isEmpty
                                        ? 'Option C is required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Option 4
                            Row(
                              children: [
                                Radio<int>(
                                  value: 3,
                                  groupValue: _correctAnswerIndex,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _correctAnswerIndex = value!;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _option4Controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Option D',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value == null || value.isEmpty
                                        ? 'Option D is required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _explanationController,
                              decoration: const InputDecoration(
                                labelText: 'Explanation',
                                border: OutlineInputBorder(),
                                hintText: 'Explain why this answer is correct...',
                              ),
                              maxLines: 3,
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Explanation is required' : null,
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _pointsController,
                              decoration: const InputDecoration(
                                labelText: 'Points',
                                border: OutlineInputBorder(),
                                hintText: 'Points for correct answer',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Points are required' : null,
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
      await FirebaseDatabase.instance.ref().child('admin_quizzes').child(widget.quiz.id).update({
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Questions: ${widget.quiz.title}'),
        backgroundColor: widget.quiz.isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Add theme switcher button
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return PopupMenuButton<AppThemeMode>(
                icon: const Icon(Icons.palette),
                tooltip: 'Change Theme',
                onSelected: (AppThemeMode theme) {
                  themeProvider.setAppTheme(theme);
                },
                itemBuilder: (BuildContext context) {
                  return AppThemeMode.values.map((AppThemeMode theme) {
                    return PopupMenuItem<AppThemeMode>(
                      value: theme,
                      child: Row(
                        children: [
                          Icon(
                            _getThemeIcon(theme),
                            color: themeProvider.appThemeMode == theme
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            themeProvider.getThemeName(theme),
                            style: TextStyle(
                              color: themeProvider.appThemeMode == theme
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: themeProvider.appThemeMode == theme
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
              );
            },
          ),
          IconButton(
            onPressed: _refreshQuestions,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Questions',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 1200),
        margin: EdgeInsets.symmetric(
          horizontal: isDesktop
              ? 32
              : isTablet
                  ? 24
                  : 16,
        ),
        child: Column(
          children: [
            // Header info
            Container(
              margin: EdgeInsets.only(
                top: isDesktop
                    ? 24
                    : isTablet
                        ? 20
                        : 16,
                bottom: isDesktop
                    ? 24
                    : isTablet
                        ? 20
                        : 16,
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop
                        ? 16
                        : isTablet
                            ? 12
                            : 8),
                    decoration: BoxDecoration(
                      color: widget.quiz.isActive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.quiz.isActive
                            ? Colors.green.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.quiz,
                      color: widget.quiz.isActive ? Colors.green[600] : Colors.grey[600],
                      size: isDesktop
                          ? 32
                          : isTablet
                              ? 28
                              : 24,
                    ),
                  ),
                  SizedBox(
                      width: isDesktop
                          ? 20
                          : isTablet
                              ? 16
                              : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quiz: ${widget.quiz.title}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop
                                    ? 24
                                    : isTablet
                                        ? 20
                                        : 18,
                              ),
                        ),
                        SizedBox(height: isDesktop ? 8 : 6),
                        Text(
                          '${widget.quiz.level} • ${widget.quiz.category} • ${_questions.length} Questions',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[600],
                                fontSize: isDesktop
                                    ? 16
                                    : isTablet
                                        ? 14
                                        : 12,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop
                          ? 16
                          : isTablet
                              ? 12
                              : 8,
                      vertical: isDesktop
                          ? 8
                          : isTablet
                              ? 6
                              : 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.quiz.isActive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.quiz.isActive
                            ? Colors.green.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      widget.quiz.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: widget.quiz.isActive ? Colors.green[700] : Colors.grey[600],
                        fontSize: isDesktop
                            ? 14
                            : isTablet
                                ? 12
                                : 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Questions List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _questions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.question_mark,
                                size: isDesktop
                                    ? 80
                                    : isTablet
                                        ? 72
                                        : 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(
                                  height: isDesktop
                                      ? 24
                                      : isTablet
                                          ? 20
                                          : 16),
                              Text(
                                'No questions yet',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: isDesktop
                                      ? 22
                                      : isTablet
                                          ? 20
                                          : 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(
                                  height: isDesktop
                                      ? 12
                                      : isTablet
                                          ? 10
                                          : 8),
                              Text(
                                'Add your first question to get started!',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: isDesktop
                                      ? 16
                                      : isTablet
                                          ? 14
                                          : 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _questions.length,
                          itemBuilder: (context, index) {
                            final question = _questions[index];
                            return Container(
                              margin: EdgeInsets.only(
                                  bottom: isDesktop
                                      ? 20
                                      : isTablet
                                          ? 16
                                          : 12),
                              child: Card(
                                elevation: 4,
                                shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Container(
                                  padding: EdgeInsets.all(isDesktop
                                      ? 24
                                      : isTablet
                                          ? 20
                                          : 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Question header
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.2),
                                            radius: isDesktop
                                                ? 20
                                                : isTablet
                                                    ? 18
                                                    : 16,
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: isDesktop
                                                    ? 16
                                                    : isTablet
                                                        ? 14
                                                        : 12,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                              width: isDesktop
                                                  ? 16
                                                  : isTablet
                                                      ? 12
                                                      : 8),
                                          Expanded(
                                            child: Text(
                                              question.question,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: isDesktop
                                                    ? 18
                                                    : isTablet
                                                        ? 16
                                                        : 14,
                                              ),
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: Icon(
                                              Icons.more_vert,
                                              size: isDesktop
                                                  ? 24
                                                  : isTablet
                                                      ? 22
                                                      : 20,
                                            ),
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showEditQuestionDialog(question, index);
                                              } else if (value == 'delete') {
                                                _deleteQuestion(index);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit,
                                                        color:
                                                            Theme.of(context).colorScheme.primary),
                                                    SizedBox(width: 8),
                                                    Text('Edit'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete, color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text('Delete'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                          height: isDesktop
                                              ? 20
                                              : isTablet
                                                  ? 16
                                                  : 12),

                                      // Options
                                      Text(
                                        'Answer Options:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color
                                              ?.withOpacity(0.8),
                                          fontSize: isDesktop
                                              ? 16
                                              : isTablet
                                                  ? 14
                                                  : 12,
                                        ),
                                      ),
                                      SizedBox(
                                          height: isDesktop
                                              ? 12
                                              : isTablet
                                                  ? 10
                                                  : 8),
                                      ...question.options.asMap().entries.map((entry) {
                                        final optionIndex = entry.key;
                                        final option = entry.value;
                                        final isCorrect =
                                            optionIndex == question.correctAnswerIndex;
                                        return Container(
                                          margin: EdgeInsets.only(
                                              bottom: isDesktop
                                                  ? 10
                                                  : isTablet
                                                      ? 8
                                                      : 6),
                                          padding: EdgeInsets.all(isDesktop
                                              ? 16
                                              : isTablet
                                                  ? 12
                                                  : 8),
                                          decoration: BoxDecoration(
                                            color: isCorrect ? Colors.green[50] : Colors.grey[50],
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isCorrect
                                                  ? Colors.green[300]!
                                                  : Colors.grey[300]!,
                                              width: 2,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: isDesktop
                                                    ? 28
                                                    : isTablet
                                                        ? 24
                                                        : 20,
                                                height: isDesktop
                                                    ? 28
                                                    : isTablet
                                                        ? 24
                                                        : 20,
                                                decoration: BoxDecoration(
                                                  color: isCorrect
                                                      ? Colors.green[600]
                                                      : Colors.grey[400],
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    String.fromCharCode(65 + optionIndex),
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: isDesktop
                                                          ? 14
                                                          : isTablet
                                                              ? 12
                                                              : 10,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                  width: isDesktop
                                                      ? 16
                                                      : isTablet
                                                          ? 12
                                                          : 8),
                                              Expanded(
                                                child: Text(
                                                  option,
                                                  style: TextStyle(
                                                    fontSize: isDesktop
                                                        ? 16
                                                        : isTablet
                                                            ? 14
                                                            : 12,
                                                    fontWeight: isCorrect
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                              if (isCorrect)
                                                Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green[600],
                                                  size: isDesktop
                                                      ? 24
                                                      : isTablet
                                                          ? 22
                                                          : 20,
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),

                                      SizedBox(
                                          height: isDesktop
                                              ? 20
                                              : isTablet
                                                  ? 16
                                                  : 12),

                                      // Question details
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.lightbulb_outline,
                                            color: Colors.orange[600],
                                            size: isDesktop
                                                ? 20
                                                : isTablet
                                                    ? 18
                                                    : 16,
                                          ),
                                          SizedBox(
                                              width: isDesktop
                                                  ? 12
                                                  : isTablet
                                                      ? 8
                                                      : 6),
                                          Expanded(
                                            child: Text(
                                              question.explanation,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: isDesktop
                                                    ? 15
                                                    : isTablet
                                                        ? 13
                                                        : 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                          height: isDesktop
                                              ? 12
                                              : isTablet
                                                  ? 10
                                                  : 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.stars,
                                            color: Colors.amber[600],
                                            size: isDesktop
                                                ? 20
                                                : isTablet
                                                    ? 18
                                                    : 16,
                                          ),
                                          SizedBox(
                                              width: isDesktop
                                                  ? 12
                                                  : isTablet
                                                      ? 8
                                                      : 6),
                                          Text(
                                            '${question.points} points',
                                            style: TextStyle(
                                              color: Colors.amber[700],
                                              fontSize: isDesktop
                                                  ? 15
                                                  : isTablet
                                                      ? 13
                                                      : 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Add Question Button
            Container(
              margin: EdgeInsets.only(
                top: isDesktop
                    ? 24
                    : isTablet
                        ? 20
                        : 16,
                bottom: isDesktop
                    ? 24
                    : isTablet
                        ? 20
                        : 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showAddQuestionDialog,
                  icon: Icon(
                    Icons.add,
                    size: isDesktop
                        ? 24
                        : isTablet
                            ? 22
                            : 20,
                  ),
                  label: Text(
                    'Add New Question',
                    style: TextStyle(
                      fontSize: isDesktop
                          ? 18
                          : isTablet
                              ? 16
                              : 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isDesktop
                          ? 20
                          : isTablet
                              ? 18
                              : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
