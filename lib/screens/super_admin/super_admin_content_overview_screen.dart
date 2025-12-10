import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../models/admin_quiz_model.dart';
import '../../models/lesson_model.dart';
import '../../services/class_management_service.dart';
import '../../services/teacher_activity_service.dart';

class SuperAdminContentOverviewScreen extends StatefulWidget {
  const SuperAdminContentOverviewScreen({super.key});

  @override
  State<SuperAdminContentOverviewScreen> createState() => _SuperAdminContentOverviewScreenState();
}

class _SuperAdminContentOverviewScreenState extends State<SuperAdminContentOverviewScreen> {
  bool _isLoading = true;
  int _lessonsCount = 0;
  int _quizzesCount = 0;
  int _classesCount = 0;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _isLoading = true);

    try {
      final db = FirebaseDatabase.instance.ref();

      // Load lessons count
      final lessonsSnap = await db.child('lessons').get();
      if (lessonsSnap.exists && lessonsSnap.value is Map) {
        _lessonsCount = (lessonsSnap.value as Map).length;
      }

      // Load quizzes count
      final quizzesSnap = await db.child('admin_quizzes').get();
      if (quizzesSnap.exists && quizzesSnap.value is Map) {
        _quizzesCount = (quizzesSnap.value as Map).length -
            ((quizzesSnap.child('_placeholder').exists) ? 1 : 0);
      }

      // Load classes count
      final classesSnap = await db.child('classes').get();
      if (classesSnap.exists && classesSnap.value is Map) {
        _classesCount = (classesSnap.value as Map).length;
      }
    } catch (e) {
      debugPrint('Error loading counts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading content...'),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              children: [
                _buildLessonsTab(),
                _buildQuizzesTab(),
                _buildClassesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Content Management',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 6),
          Text('Create, manage, and overview all educational content',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              )),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          Tab(
            icon: Icon(Icons.menu_book, size: 20),
            text: 'Lessons',
            height: 60,
          ),
          Tab(
            icon: Icon(Icons.quiz, size: 20),
            text: 'Quizzes',
            height: 60,
          ),
          Tab(
            icon: Icon(Icons.class_, size: 20),
            text: 'Classes',
            height: 60,
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildOverviewCard(
            title: 'Lessons',
            count: _lessonsCount,
            icon: Icons.menu_book,
            color: Theme.of(context).colorScheme.secondary,
            onCreateTap: () => _showCreateLessonDialog(),
            onManageTap: () => Navigator.pushNamed(context, '/super_admin/content/lessons'),
          ),
          const SizedBox(height: 16),
          _buildQuickActionsCard(
            title: 'Lesson Management',
            actions: [
              _buildActionButton(
                'Create New Lesson',
                Icons.add_circle_outline,
                () => _showCreateLessonDialog(),
              ),
              _buildActionButton(
                'Add Example Sentences',
                Icons.style,
                () => _showAddExampleSentenceDialog(),
              ),
              _buildActionButton(
                'Add Flashcards',
                Icons.flash_on,
                () => _showAddFlashcardDialog(),
              ),
              _buildActionButton(
                'View All Lessons',
                Icons.list_alt,
                () => Navigator.pushNamed(context, '/super_admin/content/lessons'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuizzesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildOverviewCard(
            title: 'Quizzes',
            count: _quizzesCount,
            icon: Icons.quiz,
            color: Theme.of(context).colorScheme.tertiary,
            onCreateTap: () => _showCreateQuizDialog(),
            onManageTap: () => Navigator.pushNamed(context, '/super_admin/content/quizzes'),
          ),
          const SizedBox(height: 16),
          _buildQuickActionsCard(
            title: 'Quiz Management',
            actions: [
              _buildActionButton(
                'Create New Quiz',
                Icons.add_circle_outline,
                () => _showCreateQuizDialog(),
              ),
              _buildActionButton(
                'Add Quiz Questions',
                Icons.quiz,
                () => _showAddQuizQuestionDialog(),
              ),
              _buildActionButton(
                'View All Quizzes',
                Icons.list_alt,
                () => Navigator.pushNamed(context, '/super_admin/content/quizzes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildOverviewCard(
            title: 'Classes',
            count: _classesCount,
            icon: Icons.class_,
            color: Theme.of(context).colorScheme.primary,
            onCreateTap: () => _showCreateClassDialog(),
            onManageTap: () => Navigator.pushNamed(context, '/super_admin/content/classes'),
          ),
          const SizedBox(height: 16),
          _buildQuickActionsCard(
            title: 'Class Management',
            actions: [
              _buildActionButton(
                'Create New Class',
                Icons.add_circle_outline,
                () => _showCreateClassDialog(),
              ),
              _buildActionButton(
                'View All Classes',
                Icons.list_alt,
                () => Navigator.pushNamed(context, '/super_admin/content/classes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onCreateTap,
    required VoidCallback onManageTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count items',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCreateTap,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create New'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onManageTap,
                    icon: const Icon(Icons.manage_accounts, size: 18),
                    label: const Text('Manage'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard({
    required String title,
    required List<Widget> actions,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ...actions,
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateLessonDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'Greetings';
    String selectedLevel = 'Beginner';
    final formKey = GlobalKey<FormState>();

    final categories = [
      'Greetings',
      'Basic Nouns',
      'Basic Verbs',
      'Basic Adjectives',
      'Time Expressions'
    ];
    final levels = ['Beginner', 'Intermediate', 'Advanced'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Lesson'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Lesson Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.trim().isEmpty == true ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Description is required' : null,
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedLevel,
                  decoration: const InputDecoration(
                    labelText: 'Level',
                    border: OutlineInputBorder(),
                  ),
                  items: levels
                      .map((level) => DropdownMenuItem(
                            value: level,
                            child: Text(level),
                          ))
                      .toList(),
                  onChanged: (value) => selectedLevel = value!,
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
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _createLesson(
                  titleController.text.trim(),
                  descriptionController.text.trim(),
                  selectedCategory,
                  selectedLevel,
                );
                Navigator.pop(context);
                // Show option to add content immediately
                _showContentOptionsDialog('lesson');
              }
            },
            child: const Text('Create & Add Content'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _createLesson(
                  titleController.text.trim(),
                  descriptionController.text.trim(),
                  selectedCategory,
                  selectedLevel,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateQuizDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final timeLimitController = TextEditingController(text: '30');
    final passingScoreController = TextEditingController(text: '70');
    String selectedCategory = 'Greetings';
    String selectedLevel = 'Beginner';
    final formKey = GlobalKey<FormState>();

    final categories = [
      'Greetings',
      'Basic Nouns',
      'Basic Verbs',
      'Basic Adjectives',
      'Time Expressions'
    ];
    final levels = ['Beginner', 'Intermediate', 'Advanced'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Quiz'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Quiz Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.trim().isEmpty == true ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Description is required' : null,
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedLevel,
                  decoration: const InputDecoration(
                    labelText: 'Level',
                    border: OutlineInputBorder(),
                  ),
                  items: levels
                      .map((level) => DropdownMenuItem(
                            value: level,
                            child: Text(level),
                          ))
                      .toList(),
                  onChanged: (value) => selectedLevel = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: timeLimitController,
                  decoration: const InputDecoration(
                    labelText: 'Time Limit (minutes)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.trim().isEmpty == true) return 'Time limit is required';
                    final time = int.tryParse(value!);
                    if (time == null || time <= 0) return 'Enter valid time limit';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passingScoreController,
                  decoration: const InputDecoration(
                    labelText: 'Passing Score (%)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.trim().isEmpty == true) return 'Passing score is required';
                    final score = int.tryParse(value!);
                    if (score == null || score < 0 || score > 100)
                      return 'Enter valid score (0-100)';
                    return null;
                  },
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
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _createQuiz(
                  titleController.text.trim(),
                  descriptionController.text.trim(),
                  selectedCategory,
                  selectedLevel,
                  int.parse(timeLimitController.text),
                  int.parse(passingScoreController.text),
                );
                Navigator.pop(context);
                // Show option to add content immediately
                _showContentOptionsDialog('quiz');
              }
            },
            child: const Text('Create & Add Questions'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _createQuiz(
                  titleController.text.trim(),
                  descriptionController.text.trim(),
                  selectedCategory,
                  selectedLevel,
                  int.parse(timeLimitController.text),
                  int.parse(passingScoreController.text),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateClassDialog() {
    final nameController = TextEditingController();
    final yearController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Class'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name Section (e.g., BSIT - A)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Name section is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: yearController,
                decoration: const InputDecoration(
                  labelText: 'Year Range (e.g., 2025 - 2026)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Year range is required' : null,
              ),
            ],
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
                await _createClass(
                  nameController.text.trim(),
                  yearController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createLesson(
      String title, String description, String category, String level) async {
    try {
      final lesson = Lesson(
        id: _generateLessonId(category, level),
        title: title,
        description: description,
        category: category,
        level: level,
      );

      await FirebaseDatabase.instance.ref().child('lessons').child(lesson.id).set(lesson.toMap());

      // Log activity
      try {
        await TeacherActivityService().logLessonCreated(
          lesson.id,
          lesson.title,
          lesson.category,
        );
      } catch (activityError) {
        debugPrint('Error logging lesson creation activity: $activityError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lesson successfully created!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'Add Content',
              textColor: Colors.white,
              onPressed: () => _showAddExampleSentenceDialog(),
            ),
          ),
        );
        _loadCounts(); // Refresh counts
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create lesson: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _createQuiz(String title, String description, String category, String level,
      int timeLimit, int passingScore) async {
    try {
      final quiz = AdminQuiz(
        id: _generateQuizId(category, level),
        title: title,
        description: description,
        category: category,
        level: level,
        questions: [], // Empty questions list for now
        timeLimit: timeLimit,
        passingScore: passingScore,
        createdAt: DateTime.now(),
      );

      await FirebaseDatabase.instance.ref().child('admin_quizzes').child(quiz.id).set(quiz.toMap());

      // Log activity
      try {
        await TeacherActivityService().logQuizCreated(
          quiz.id,
          quiz.title,
        );
      } catch (activityError) {
        debugPrint('Error logging quiz creation activity: $activityError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Quiz successfully created!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'Add Questions',
              textColor: Colors.white,
              onPressed: () => _showAddQuizQuestionDialog(),
            ),
          ),
        );
        _loadCounts(); // Refresh counts
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create quiz: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _createClass(String nameSection, String yearRange) async {
    try {
      final classService = ClassManagementService();
      final classId = await classService.createClass(
        nameSection: nameSection,
        yearRange: yearRange,
      );

      // Log activity
      try {
        await TeacherActivityService().logClassCreated(
          classId,
          nameSection,
        );
      } catch (activityError) {
        debugPrint('Error logging class creation activity: $activityError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Class successfully created!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        _loadCounts(); // Refresh counts
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create class: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  String _generateLessonId(String category, String level) {
    final categoryFormatted = category.toUpperCase().replaceAll(' ', '_');
    final levelFormatted = level.toUpperCase().replaceAll(' ', '_');
    return '$categoryFormatted-$levelFormatted-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _generateQuizId(String category, String level) {
    final categoryFormatted = category.toUpperCase().replaceAll(' ', '_');
    final levelFormatted = level.toUpperCase().replaceAll(' ', '_');
    return 'quiz-$categoryFormatted-$levelFormatted-${DateTime.now().millisecondsSinceEpoch}';
  }

  // Content Management Methods
  void _showContentOptionsDialog(String contentType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Content to $contentType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contentType == 'lesson') ...[
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
            ] else if (contentType == 'quiz') ...[
              ListTile(
                leading: const Icon(Icons.quiz),
                title: const Text('Add Quiz Question'),
                subtitle: const Text('Add multiple choice questions to quizzes'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddQuizQuestionDialog();
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showAddExampleSentenceDialog() {
    final japaneseController = TextEditingController();
    final romajiController = TextEditingController();
    final englishController = TextEditingController();
    String selectedLessonId = '';
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
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getLessonsList(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    final lessons = snapshot.data ?? [];
                    if (lessons.isEmpty) {
                      return const Text('No lessons available. Create a lesson first.');
                    }

                    return DropdownButtonFormField<String>(
                      value: selectedLessonId.isEmpty ? null : selectedLessonId,
                      decoration: const InputDecoration(
                        labelText: 'Select Lesson',
                        border: OutlineInputBorder(),
                      ),
                      items: lessons
                          .map((lesson) => DropdownMenuItem<String>(
                                value: lesson['id'] as String,
                                child: Text(lesson['title'] as String),
                              ))
                          .toList(),
                      onChanged: (value) => selectedLessonId = value!,
                      validator: (value) => value == null ? 'Please select a lesson' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
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
                  selectedLessonId,
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

  void _showAddQuizQuestionDialog() {
    final questionController = TextEditingController();
    final option1Controller = TextEditingController();
    final option2Controller = TextEditingController();
    final option3Controller = TextEditingController();
    final option4Controller = TextEditingController();
    final explanationController = TextEditingController();
    final pointsController = TextEditingController(text: '10');
    int correctAnswerIndex = 0;
    String selectedQuizId = '';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Quiz Question'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getQuizzesList(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    final quizzes = snapshot.data ?? [];
                    if (quizzes.isEmpty) {
                      return const Text('No quizzes available. Create a quiz first.');
                    }

                    return DropdownButtonFormField<String>(
                      value: selectedQuizId.isEmpty ? null : selectedQuizId,
                      decoration: const InputDecoration(
                        labelText: 'Select Quiz',
                        border: OutlineInputBorder(),
                      ),
                      items: quizzes
                          .map((quiz) => DropdownMenuItem<String>(
                                value: quiz['id'] as String,
                                child: Text(quiz['title'] as String),
                              ))
                          .toList(),
                      onChanged: (value) => selectedQuizId = value!,
                      validator: (value) => value == null ? 'Please select a quiz' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: questionController,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Question is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: option1Controller,
                  decoration: const InputDecoration(
                    labelText: 'Option 1',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Option 1 is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: option2Controller,
                  decoration: const InputDecoration(
                    labelText: 'Option 2',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Option 2 is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: option3Controller,
                  decoration: const InputDecoration(
                    labelText: 'Option 3',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Option 3 is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: option4Controller,
                  decoration: const InputDecoration(
                    labelText: 'Option 4',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Option 4 is required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: correctAnswerIndex,
                  decoration: const InputDecoration(
                    labelText: 'Correct Answer',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 0,
                        child: Text(
                            'Option 1: ${option1Controller.text.isEmpty ? 'Option 1' : option1Controller.text}')),
                    DropdownMenuItem(
                        value: 1,
                        child: Text(
                            'Option 2: ${option2Controller.text.isEmpty ? 'Option 2' : option2Controller.text}')),
                    DropdownMenuItem(
                        value: 2,
                        child: Text(
                            'Option 3: ${option3Controller.text.isEmpty ? 'Option 3' : option3Controller.text}')),
                    DropdownMenuItem(
                        value: 3,
                        child: Text(
                            'Option 4: ${option4Controller.text.isEmpty ? 'Option 4' : option4Controller.text}')),
                  ],
                  onChanged: (value) => correctAnswerIndex = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: explanationController,
                  decoration: const InputDecoration(
                    labelText: 'Explanation (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pointsController,
                  decoration: const InputDecoration(
                    labelText: 'Points',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.trim().isEmpty == true) return 'Points is required';
                    final points = int.tryParse(value!);
                    if (points == null || points <= 0) return 'Enter valid points';
                    return null;
                  },
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
                await _createQuizQuestion(
                  selectedQuizId,
                  questionController.text.trim(),
                  [
                    option1Controller.text.trim(),
                    option2Controller.text.trim(),
                    option3Controller.text.trim(),
                    option4Controller.text.trim(),
                  ],
                  correctAnswerIndex,
                  explanationController.text.trim(),
                  int.parse(pointsController.text),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add Question'),
          ),
        ],
      ),
    );
  }

  void _showAddFlashcardDialog() {
    final frontController = TextEditingController();
    final backController = TextEditingController();
    String selectedCategory = 'Greetings';
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

  // Helper methods to get lists
  Future<List<Map<String, dynamic>>> _getLessonsList() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref().child('lessons').get();
      if (snapshot.value == null) return [];

      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((entry) {
        final lesson = Map<String, dynamic>.from(entry.value as Map);
        lesson['id'] = entry.key;
        return lesson;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getQuizzesList() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref().child('admin_quizzes').get();
      if (snapshot.value == null) return [];

      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((entry) {
        final quiz = Map<String, dynamic>.from(entry.value as Map);
        quiz['id'] = entry.key;
        return quiz;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Content creation methods
  Future<void> _createExampleSentence(
      String lessonId, String japanese, String romaji, String english) async {
    try {
      final sentence = {
        'japanese': japanese,
        'romaji': romaji,
        'english': english,
        'created_at': DateTime.now().toIso8601String(),
      };

      await FirebaseDatabase.instance
          .ref()
          .child('lessons/$lessonId/example_sentences')
          .push()
          .set(sentence);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Example sentence successfully created!'),
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
            content: Text('Failed to create example sentence: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _createQuizQuestion(String quizId, String question, List<String> options,
      int correctAnswerIndex, String explanation, int points) async {
    try {
      final questionData = QuizQuestion(
        id: 'q_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}',
        question: question,
        options: options,
        correctAnswerIndex: correctAnswerIndex,
        explanation: explanation,
        points: points,
      );

      // Get current quiz data
      final quizSnapshot =
          await FirebaseDatabase.instance.ref().child('admin_quizzes/$quizId').get();
      if (quizSnapshot.value == null) {
        throw Exception('Quiz not found');
      }

      final quizData = Map<String, dynamic>.from(quizSnapshot.value as Map);
      final currentQuestions = List<Map<String, dynamic>>.from(quizData['questions'] ?? []);

      // Add new question
      currentQuestions.add(questionData.toMap());

      // Update quiz with new question
      await FirebaseDatabase.instance.ref().child('admin_quizzes/$quizId').update({
        'questions': currentQuestions,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Quiz question successfully created!'),
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
            content: Text('Failed to create quiz question: $e'),
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

      await FirebaseDatabase.instance.ref().child('flashcards').push().set(flashcard);

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
}
