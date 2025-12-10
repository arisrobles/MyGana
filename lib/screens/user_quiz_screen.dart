import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/models/admin_quiz_model.dart';
import 'package:nihongo_japanese_app/services/daily_points_service.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserQuizScreen extends StatefulWidget {
  const UserQuizScreen({super.key});

  @override
  State<UserQuizScreen> createState() => _UserQuizScreenState();
}

class _UserQuizScreenState extends State<UserQuizScreen> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final DailyPointsService _pointsService = DailyPointsService();
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 3));

  List<AdminQuiz> _availableQuizzes = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedLevel = 'All';
  int _completedToday = 0;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadAvailableQuizzes();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableQuizzes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('🔍 Loading available quizzes for users...');

      final snapshot = await FirebaseDatabase.instance.ref().child('admin_quizzes').once();

      if (snapshot.snapshot.value != null) {
        final dynamic rawValue = snapshot.snapshot.value;

        if (rawValue is Map<dynamic, dynamic>) {
          final List<AdminQuiz> processedQuizzes = [];

          for (final entry in rawValue.entries) {
            try {
              final quiz = entry.value as Map<dynamic, dynamic>;
              final quizData = Map<String, dynamic>.from(quiz);
              quizData['id'] = entry.key as String;

              // Only include active quizzes
              if (quizData['isActive'] == true) {
                // Handle questions data structure
                if (quizData['questions'] is Map) {
                  final questionsMap = quizData['questions'] as Map<dynamic, dynamic>;
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
                }

                final adminQuiz = AdminQuiz.fromMap(quizData);
                processedQuizzes.add(adminQuiz);
              }
            } catch (e) {
              print('❌ Error processing quiz entry ${entry.key}: $e');
            }
          }

          _availableQuizzes = processedQuizzes;
          print('✅ Loaded ${_availableQuizzes.length} active quizzes');
        }
      } else {
        _availableQuizzes = [];
        print('📭 No quizzes found');
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
      // Load completed count after quizzes are loaded
      _loadCompletedToday();
    }
  }

  List<AdminQuiz> get _filteredQuizzes {
    return _availableQuizzes.where((quiz) {
      final matchesSearch = _searchQuery.isEmpty ||
          quiz.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          quiz.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          quiz.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          quiz.level.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == 'All' || quiz.category == _selectedCategory;
      final matchesLevel = _selectedLevel == 'All' || quiz.level == _selectedLevel;

      return matchesSearch && matchesCategory && matchesLevel;
    }).toList();
  }

  List<String> get _availableCategories {
    final categories = _availableQuizzes.map((quiz) => quiz.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  List<String> get _availableLevels {
    final levels = _availableQuizzes.map((quiz) => quiz.level).toSet().toList();
    levels.sort();
    return ['All', ...levels];
  }

  Future<void> _startQuiz(AdminQuiz quiz) async {
    // Check if user has already completed this quiz today
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final completedKey = 'quiz_completed_${quiz.id}_$today';
    final isCompleted = prefs.getBool(completedKey) ?? false;

    if (isCompleted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You have already completed "${quiz.title}" today!'),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    // Navigate to quiz taking screen
    if (mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizTakingScreen(quiz: quiz),
        ),
      );

      // Refresh the quiz list if a quiz was completed
      if (result == true) {
        _loadAvailableQuizzes();
        _loadCompletedToday(); // Refresh completed count
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quiz Challenge',
          style: TextStyle(fontFamily: 'TheLastShuriken', fontSize: 25),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _resetAllQuizzes,
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset All Quizzes (Testing)',
          ),
          IconButton(
            onPressed: _loadAvailableQuizzes,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Quizzes',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Enhanced header section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.8),
                      primaryColor.withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Animated quiz icon
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.quiz,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Quiz Challenge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'TheLastShuriken',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Take quizzes created by admins and earn moji points based on your score!',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Quiz stats
                    _buildQuizStats(),
                  ],
                ),
              ),

              // Enhanced search and filter section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? theme.cardColor : Colors.grey[50],
                  border: Border(
                    bottom: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!),
                  ),
                ),
                child: Column(
                  children: [
                    // Search bar
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search quizzes...',
                        prefixIcon: Icon(Icons.search, color: primaryColor),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: isDarkMode ? theme.cardColor : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Category', _selectedCategory, _availableCategories,
                              (value) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          }),
                          const SizedBox(width: 8),
                          _buildFilterChip('Level', _selectedLevel, _availableLevels, (value) {
                            setState(() {
                              _selectedLevel = value;
                            });
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Quiz list
              Expanded(
                child: _buildQuizList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizCard(AdminQuiz quiz, double availableWidth) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: availableWidth - 32, // Account for horizontal padding
              child: Card(
                elevation: 8,
                shadowColor: primaryColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  onTap: () => _startQuiz(quiz),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.cardColor,
                          theme.brightness == Brightness.dark
                              ? theme.cardColor.withOpacity(0.8)
                              : Colors.grey[50]!,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Quiz header
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      primaryColor.withOpacity(0.8),
                                      primaryColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.quiz,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      quiz.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: theme.brightness == Brightness.dark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      quiz.description,
                                      style: TextStyle(
                                        color: theme.brightness == Brightness.dark
                                            ? Colors.grey[300]
                                            : Colors.grey[600],
                                        fontSize: 14,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.green[400]!, Colors.green[600]!],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Quiz info chips
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildInfoChip(
                                    '${quiz.questions.length} Questions',
                                    Icons.question_answer,
                                    Colors.blue,
                                  ),
                                  _buildInfoChip(
                                    '${quiz.timeLimit} min',
                                    Icons.timer,
                                    Colors.orange,
                                  ),
                                  _buildInfoChip(
                                    '${quiz.passingScore}% Pass',
                                    Icons.check_circle,
                                    Colors.green,
                                  ),
                                  FutureBuilder<Map<String, dynamic>>(
                                    future: _getQuizStatusAndPoints(quiz),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        final data = snapshot.data!;
                                        final status = data['status'] as String;
                                        final earnedPoints = data['points'] as int;

                                        IconData icon;
                                        Color color;
                                        String label;

                                        if (status == 'Completed') {
                                          icon = Icons.check_circle;
                                          color = Colors.green;
                                          label = '$earnedPoints Moji Points Earned';
                                        } else if (status == 'Failed') {
                                          icon = Icons.cancel;
                                          color = Colors.red;
                                          label = 'Failed';
                                        } else {
                                          icon = Icons.info_outline;
                                          color = Colors.grey;
                                          label = 'Not Completed';
                                        }

                                        return _buildInfoChip(label, icon, color);
                                      }
                                      return _buildInfoChip(
                                          'Loading...', Icons.hourglass_empty, Colors.grey);
                                    },
                                  ),
                                  _buildInfoChip(
                                    quiz.level,
                                    Icons.school,
                                    Colors.purple,
                                  ),
                                  _buildInfoChip(
                                    quiz.category,
                                    Icons.category,
                                    Colors.teal,
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // Moji Points explanation
                          FutureBuilder<Map<String, dynamic>>(
                            future: _getQuizStatusAndPoints(quiz),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final data = snapshot.data!;
                                final status = data['status'] as String;
                                final earnedPoints = data['points'] as int;

                                Color backgroundColor;
                                Color borderColor;
                                Color iconColor;
                                Color textColor;
                                IconData icon;
                                String text;

                                if (status == 'Completed') {
                                  backgroundColor = Colors.green[50]!;
                                  borderColor = Colors.green[200]!;
                                  iconColor = Colors.green[600]!;
                                  textColor = Colors.green[700]!;
                                  icon = Icons.check_circle;
                                  text = 'Completed! You earned $earnedPoints Moji Points!';
                                } else if (status == 'Failed') {
                                  backgroundColor = Colors.red[50]!;
                                  borderColor = Colors.red[200]!;
                                  iconColor = Colors.red[600]!;
                                  textColor = Colors.red[700]!;
                                  icon = Icons.cancel;
                                  text =
                                      'Quiz failed. Score below ${quiz.passingScore}% passing requirement.';
                                } else {
                                  backgroundColor = Colors.amber[50]!;
                                  borderColor = Colors.amber[200]!;
                                  iconColor = Colors.amber[600]!;
                                  textColor = Colors.amber[700]!;
                                  icon = Icons.info_outline;
                                  text =
                                      'Moji Points: 50 base + (score% × 2) bonus. Pass ${quiz.passingScore}% to earn points!';
                                }

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: backgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(icon, color: iconColor, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          text,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.hourglass_empty, color: Colors.grey, size: 16),
                                    SizedBox(width: 8),
                                    Text('Loading...',
                                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          // Start button
                          FutureBuilder<Map<String, dynamic>>(
                            future: _getQuizStatusAndPoints(quiz),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final data = snapshot.data!;
                                final status = data['status'] as String;

                                bool isCompleted = status == 'Completed';
                                bool isFailed = status == 'Failed';

                                IconData icon;
                                String label;
                                Color backgroundColor;
                                Color shadowColor;

                                if (isCompleted) {
                                  icon = Icons.refresh;
                                  label = 'Retake Quiz';
                                  backgroundColor = Colors.orange[600]!;
                                  shadowColor = Colors.orange.withOpacity(0.3);
                                } else if (isFailed) {
                                  icon = Icons.refresh;
                                  label = 'Retry Quiz';
                                  backgroundColor = Colors.red[600]!;
                                  shadowColor = Colors.red.withOpacity(0.3);
                                } else {
                                  icon = Icons.play_arrow;
                                  label = 'Start Quiz';
                                  backgroundColor = primaryColor;
                                  shadowColor = primaryColor.withOpacity(0.3);
                                }

                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _startQuiz(quiz),
                                    icon: Icon(icon, size: 20),
                                    label: Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: backgroundColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 4,
                                      shadowColor: shadowColor,
                                    ),
                                  ),
                                );
                              }
                              return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _startQuiz(quiz),
                                  icon: const Icon(Icons.play_arrow, size: 20),
                                  label: const Text(
                                    'Start Quiz',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                    shadowColor: primaryColor.withOpacity(0.3),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuizList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAvailableQuizzes,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredQuizzes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No quizzes available'
                  : 'No quizzes found matching "$_searchQuery"',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Check back later for new challenges!'
                  : 'Try a different search term',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _filteredQuizzes.length,
          itemBuilder: (context, index) {
            final quiz = _filteredQuizzes[index];
            return _buildQuizCard(quiz, constraints.maxWidth);
          },
        );
      },
    );
  }

  Widget _buildQuizStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('${_availableQuizzes.length}', 'Available', Icons.quiz),
          _buildStatItem('${_filteredQuizzes.length}', 'Filtered', Icons.filter_list),
          _buildStatItem('$_completedToday', 'Completed Today', Icons.check_circle),
          _buildStatItem('${_calculateTotalPotentialPoints()}', 'Max Points', Icons.stars),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
      String label, String selectedValue, List<String> options, Function(String) onChanged) {
    return Container(
      height: 40,
      child: DropdownButton<String>(
        value: selectedValue,
        onChanged: (value) => onChanged(value!),
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: option == selectedValue
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).cardColor
                        : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: option == selectedValue
                      ? Theme.of(context).primaryColor
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[600]!
                          : Colors.grey[300]!),
                ),
              ),
              child: Text(
                option,
                style: TextStyle(
                  color: option == selectedValue
                      ? Theme.of(context).primaryColor
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.grey[700]),
                  fontSize: 14,
                  fontWeight: option == selectedValue ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
        underline: const SizedBox(),
        icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).primaryColor),
      ),
    );
  }

  Future<void> _loadCompletedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];

      int completedCount = 0;
      for (final quiz in _availableQuizzes) {
        final completedKey = 'quiz_completed_${quiz.id}_$today';
        final isCompleted = prefs.getBool(completedKey) ?? false;
        if (isCompleted) {
          completedCount++;
        }
      }

      if (mounted) {
        setState(() {
          _completedToday = completedCount;
        });
      }
    } catch (e) {
      print('Error loading completed today count: $e');
    }
  }

  Future<void> _resetAllQuizzes() async {
    // Show confirmation dialog
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Quizzes'),
        content: const Text(
          'This will reset all quiz completion data for today. This action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldReset == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final today = DateTime.now().toIso8601String().split('T')[0];

        // Remove all quiz completion data for today
        for (final quiz in _availableQuizzes) {
          final completedKey = 'quiz_completed_${quiz.id}_$today';
          final resultKey = 'quiz_result_${quiz.id}_$today';
          await prefs.remove(completedKey);
          await prefs.remove(resultKey);
        }

        // Refresh the UI
        _loadCompletedToday();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('All quizzes have been reset!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } catch (e) {
        print('Error resetting quizzes: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting quizzes: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  int _calculateTotalPotentialPoints() {
    // Calculate total potential moji points from all available quizzes
    // Each quiz can give up to 250 points (50 base + 200 bonus for 100%)
    return _availableQuizzes.length * 250;
  }

  Future<Map<String, dynamic>> _getQuizStatusAndPoints(AdminQuiz quiz) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final resultKey = 'quiz_result_${quiz.id}_$today';

      final resultString = prefs.getString(resultKey);
      if (resultString != null) {
        final result = jsonDecode(resultString);
        final points = result['points'] ?? 0;
        final passed = result['passed'] ?? false;

        if (passed) {
          return {'status': 'Completed', 'points': points};
        } else {
          return {'status': 'Failed', 'points': 0};
        }
      }
      return {'status': 'Not Completed', 'points': 0};
    } catch (e) {
      print('Error getting quiz status and points: $e');
      return {'status': 'Not Completed', 'points': 0};
    }
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 120, // Limit chip width
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuizTakingScreen extends StatefulWidget {
  final AdminQuiz quiz;

  const QuizTakingScreen({super.key, required this.quiz});

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final DailyPointsService _pointsService = DailyPointsService();
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 3));

  int _currentQuestionIndex = 0;
  int _selectedAnswerIndex = -1;
  bool _isAnswerSubmitted = false;
  bool _showResult = false;
  bool _isQuizCompleted = false;

  // Timer
  Timer? _quizTimer;
  int _remainingTime = 0; // in seconds

  // Score tracking
  int _correctAnswers = 0;
  int _totalQuestions = 0;
  int _earnedPoints = 0;
  List<bool> _questionResults = [];

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _bounceController;
  late AnimationController _progressController;
  late AnimationController _pointsAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _pointsAnimation;

  // Points animation variables
  List<Map<String, dynamic>> _pointsAnimations = [];
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _totalQuestions = widget.quiz.questions.length;
    _remainingTime = widget.quiz.timeLimit * 60; // Convert minutes to seconds
    _questionResults = List.filled(_totalQuestions, false);
    _initializeAnimations();
    _startQuizTimer();
    _startAnimationTimer();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pointsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeInOut));

    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _pointsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pointsAnimationController, curve: Curves.easeOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _bounceController.forward();
    _progressController.forward();
  }

  void _startQuizTimer() {
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        _submitQuiz();
      }
    });
  }

  void _startAnimationTimer() {
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (mounted && _pointsAnimations.isNotEmpty) {
        setState(() {
          // This will trigger a rebuild to update the animation progress
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(int index) {
    if (!_isAnswerSubmitted) {
      setState(() {
        _selectedAnswerIndex = index;
      });
    }
  }

  void _submitAnswer() {
    if (_selectedAnswerIndex == -1) return;

    final isCorrect =
        _selectedAnswerIndex == widget.quiz.questions[_currentQuestionIndex].correctAnswerIndex;

    setState(() {
      _isAnswerSubmitted = true;
      _showResult = true;

      _questionResults[_currentQuestionIndex] = isCorrect;

      if (isCorrect) {
        _correctAnswers++;
        // Don't add individual question points here, we'll calculate moji points at the end
      }
    });

    // Play sound effect
    _playSound(isCorrect ? 'correct.wav' : 'error.wav');

    // Auto-advance after 2 seconds
    Timer(const Duration(seconds: 2), () {
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _totalQuestions - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = -1;
        _isAnswerSubmitted = false;
        _showResult = false;
      });

      // Reset animations for next question
      _slideController.reset();
      _slideController.forward();
    } else {
      _submitQuiz();
    }
  }

  void _submitQuiz() async {
    _quizTimer?.cancel();
    setState(() {
      _isQuizCompleted = true;
    });

    // Play completion sound
    _playSound('complete.wav');

    // Show confetti if passed
    final percentage = (_correctAnswers / _totalQuestions) * 100;
    if (percentage >= widget.quiz.passingScore) {
      _confettiController.play();
    }

    // Save quiz result
    await _saveQuizResult();
  }

  Future<void> _saveQuizResult() async {
    final percentage = (_correctAnswers / _totalQuestions) * 100;
    final passed = percentage >= widget.quiz.passingScore;

    // Calculate moji points based on percentage score
    int mojiPointsEarned = 0;
    if (passed) {
      // Base points for passing (minimum 50 points)
      mojiPointsEarned = 50;

      // Bonus points based on percentage score
      // 100% = 200 points, 90% = 180 points, 80% = 160 points, etc.
      final bonusPoints = (percentage * 2).round();
      mojiPointsEarned += bonusPoints;

      // Add the calculated moji points to user's total
      await _addPoints(mojiPointsEarned);

      // Update the earned points for display
      _earnedPoints = mojiPointsEarned;
    }

    // Save completion status (only if passed)
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final completedKey = 'quiz_completed_${widget.quiz.id}_$today';
    await prefs.setBool(completedKey, passed);

    // Save quiz result
    final resultKey = 'quiz_result_${widget.quiz.id}_$today';
    await prefs.setString(
        resultKey,
        jsonEncode({
          'score': _correctAnswers,
          'total': _totalQuestions,
          'percentage': percentage,
          'passed': passed,
          'points': mojiPointsEarned,
          'completedAt': DateTime.now().toIso8601String(),
        }));
  }

  Future<void> _playSound(String soundFile) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  Future<void> _addPoints(int points) async {
    final prefs = await SharedPreferences.getInstance();

    // Save to dedicated quiz points key
    final currentQuizPoints = prefs.getInt('quiz_total_points') ?? 0;
    await prefs.setInt('quiz_total_points', currentQuizPoints + points);

    // Also save to general total_points for backward compatibility
    final currentTotalPoints = prefs.getInt('total_points') ?? 0;
    final newTotalPoints = currentTotalPoints + points;
    await prefs.setInt('total_points', newTotalPoints);

    // Sync to Firebase
    final firebaseSync = FirebaseUserSyncService();
    await firebaseSync.syncMojiPoints(newTotalPoints);

    // Show animated points
    _showPointsAnimation(points);
  }

  void _showPointsAnimation(int points) {
    setState(() {
      _pointsAnimations.add({
        'points': points,
        'startTime': DateTime.now(),
        'id': DateTime.now().millisecondsSinceEpoch,
      });
    });

    // Remove animation after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _pointsAnimations
              .removeWhere((anim) => DateTime.now().difference(anim['startTime']).inSeconds >= 3);
        });
      }
    });
  }

  @override
  void dispose() {
    _quizTimer?.cancel();
    _animationTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _bounceController.dispose();
    _progressController.dispose();
    _pointsAnimationController.dispose();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isQuizCompleted) {
      return _buildQuizResultScreen();
    }

    final currentQuestion = widget.quiz.questions[_currentQuestionIndex];
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.quiz.title,
          style: const TextStyle(fontFamily: 'TheLastShuriken', fontSize: 20),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _showExitConfirmationDialog();
          },
        ),
      ),
      body: Stack(
        children: [
          // Main content
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Progress bar and timer
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Enhanced progress bar
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return Container(
                              height: 12,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: theme.brightness == Brightness.dark
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                              ),
                              child: Stack(
                                children: [
                                  Container(
                                    width: MediaQuery.of(context).size.width *
                                        (_currentQuestionIndex + 1) /
                                        _totalQuestions *
                                        _progressAnimation.value,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      gradient: LinearGradient(
                                        colors: [
                                          primaryColor.withOpacity(0.8),
                                          primaryColor,
                                          primaryColor.withOpacity(0.9),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Question ${_currentQuestionIndex + 1} of $_totalQuestions',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _remainingTime < 60
                                      ? [Colors.red[400]!, Colors.red[600]!]
                                      : [Colors.blue[400]!, Colors.blue[600]!],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_remainingTime < 60 ? Colors.red : Colors.blue)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedBuilder(
                                    animation: _bounceAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _remainingTime < 60
                                            ? 1.0 + (_bounceAnimation.value * 0.1)
                                            : 1.0,
                                        child: Icon(
                                          Icons.timer,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTime(_remainingTime),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Question content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Enhanced question text
                          AnimatedBuilder(
                            animation: _bounceAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 0.95 + (0.05 * _bounceAnimation.value),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.purple[50]!,
                                        Colors.purple[100]!,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.purple[300]!,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.purple.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    currentQuestion.question,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // Answer options
                          Expanded(
                            child: ListView.builder(
                              itemCount: currentQuestion.options.length,
                              itemBuilder: (context, index) {
                                final isSelected = _selectedAnswerIndex == index;
                                final isCorrect = index == currentQuestion.correctAnswerIndex;
                                final showResult = _showResult;

                                Color? borderColor;
                                Color? textColor;

                                if (showResult) {
                                  if (isCorrect) {
                                    borderColor = Colors.green[400];
                                    textColor = Colors.green[800];
                                  } else if (isSelected && !isCorrect) {
                                    borderColor = Colors.red[400];
                                    textColor = Colors.red[800];
                                  } else {
                                    borderColor = Colors.grey[300];
                                    textColor = Colors.grey[600];
                                  }
                                } else if (isSelected) {
                                  borderColor = Colors.purple[400];
                                  textColor = Colors.purple[800];
                                } else {
                                  borderColor = Colors.grey[300];
                                  textColor = Colors.black87;
                                }

                                return TweenAnimationBuilder<double>(
                                  duration: Duration(milliseconds: 300 + (index * 100)),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: Opacity(
                                        opacity: value,
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          child: InkWell(
                                            onTap: () => _selectAnswer(index),
                                            borderRadius: BorderRadius.circular(16),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              padding: const EdgeInsets.all(18),
                                              decoration: BoxDecoration(
                                                gradient: showResult && isCorrect
                                                    ? LinearGradient(
                                                        colors: [
                                                          Colors.green[100]!,
                                                          Colors.green[50]!
                                                        ],
                                                      )
                                                    : showResult && isSelected && !isCorrect
                                                        ? LinearGradient(
                                                            colors: [
                                                              Colors.red[100]!,
                                                              Colors.red[50]!
                                                            ],
                                                          )
                                                        : isSelected
                                                            ? LinearGradient(
                                                                colors: [
                                                                  Colors.purple[100]!,
                                                                  Colors.purple[50]!
                                                                ],
                                                              )
                                                            : LinearGradient(
                                                                colors: [
                                                                  Colors.white,
                                                                  Colors.grey[50]!
                                                                ],
                                                              ),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: borderColor!,
                                                  width: isSelected ? 3 : 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: borderColor.withOpacity(0.2),
                                                    blurRadius: isSelected ? 8 : 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  AnimatedContainer(
                                                    duration: const Duration(milliseconds: 200),
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          borderColor,
                                                          borderColor.withOpacity(0.8)
                                                        ],
                                                      ),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: borderColor.withOpacity(0.3),
                                                          blurRadius: 4,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        String.fromCharCode(65 + index),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Text(
                                                      currentQuestion.options[index],
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: textColor,
                                                        fontWeight: isSelected
                                                            ? FontWeight.w600
                                                            : FontWeight.normal,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                  ),
                                                  if (showResult && isCorrect)
                                                    Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green[600],
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.check,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  if (showResult && isSelected && !isCorrect)
                                                    Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red[600],
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          // Enhanced submit button
                          if (!_isAnswerSubmitted)
                            AnimatedBuilder(
                              animation: _bounceAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _selectedAnswerIndex != -1
                                      ? 1.0 + (_bounceAnimation.value * 0.02)
                                      : 1.0,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _selectedAnswerIndex == -1 ? null : _submitAnswer,
                                      icon: const Icon(Icons.send, size: 20),
                                      label: const Text(
                                        'Submit Answer',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _selectedAnswerIndex == -1
                                            ? Colors.grey[400]
                                            : primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: _selectedAnswerIndex == -1 ? 2 : 6,
                                        shadowColor: primaryColor.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 10,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.amber,
              ],
            ),
          ),

          // Animated points overlay
          ..._pointsAnimations.map((anim) => _buildAnimatedPoints(anim)).toList(),
        ],
      ),
    );
  }

  Widget _buildAnimatedPoints(Map<String, dynamic> animation) {
    final points = animation['points'] as int;
    final startTime = animation['startTime'] as DateTime;
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    final progress = (elapsed / 3000).clamp(0.0, 1.0);

    return Positioned(
      left: MediaQuery.of(context).size.width / 2 - 50,
      top: MediaQuery.of(context).size.height / 2 - 50 + (progress * -100),
      child: Opacity(
        opacity: 1.0 - progress,
        child: Transform.scale(
          scale: 0.5 + (progress * 0.5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber[400]!, Colors.amber[600]!],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.stars,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '+$points Moji Points!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizResultScreen() {
    final percentage = (_correctAnswers / _totalQuestions) * 100;
    final passed = percentage >= widget.quiz.passingScore;
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quiz Results',
          style: TextStyle(fontFamily: 'TheLastShuriken', fontSize: 20),
        ),
        backgroundColor: passed ? Colors.green[700] : Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Result header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: passed
                          ? [Colors.green[600]!, Colors.green[500]!]
                          : [Colors.red[600]!, Colors.red[500]!],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                        size: 64,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        passed ? 'Congratulations!' : 'Better luck next time!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        passed
                            ? 'You passed the quiz!'
                            : 'You need ${widget.quiz.passingScore}% to pass',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Score details
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your Score',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildScoreItem(
                            'Correct',
                            '$_correctAnswers',
                            Colors.green,
                            Icons.check_circle,
                          ),
                          _buildScoreItem(
                            'Incorrect',
                            '${_totalQuestions - _correctAnswers}',
                            Colors.red,
                            Icons.cancel,
                          ),
                          _buildScoreItem(
                            'Percentage',
                            '${percentage.toStringAsFixed(1)}%',
                            Colors.blue,
                            Icons.percent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (passed) ...[
                        AnimatedBuilder(
                          animation: _bounceAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_bounceAnimation.value * 0.1),
                              child: _buildScoreItem(
                                'Moji Points Earned',
                                '$_earnedPoints',
                                Colors.amber,
                                Icons.stars,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.amber[50]!, Colors.amber[100]!],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.amber[300]!, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber[600],
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.calculate,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Points Calculation:',
                                    style: TextStyle(
                                      color: Colors.amber[800],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber[200]!),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Base Points:',
                                            style:
                                                TextStyle(color: Colors.amber[700], fontSize: 12)),
                                        Text('50',
                                            style: TextStyle(
                                                color: Colors.amber[800],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Bonus (${percentage.toStringAsFixed(1)}% × 2):',
                                            style:
                                                TextStyle(color: Colors.amber[700], fontSize: 12)),
                                        Text('${(percentage * 2).round()}',
                                            style: TextStyle(
                                                color: Colors.amber[800],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ],
                                    ),
                                    const Divider(color: Colors.amber, height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Total:',
                                            style: TextStyle(
                                                color: Colors.amber[800],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14)),
                                        Text('$_earnedPoints',
                                            style: TextStyle(
                                                color: Colors.amber[900],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!passed)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Pass quizzes to earn moji points based on your score!',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Quiz details
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiz Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Quiz Title', widget.quiz.title),
                      _buildDetailRow('Category', widget.quiz.category),
                      _buildDetailRow('Level', widget.quiz.level),
                      _buildDetailRow('Time Limit', '${widget.quiz.timeLimit} minutes'),
                      _buildDetailRow('Passing Score', '${widget.quiz.passingScore}%'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Back to Quizzes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 10,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.amber,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Quiz'),
        content: const Text('Are you sure you want to exit? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit quiz
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
