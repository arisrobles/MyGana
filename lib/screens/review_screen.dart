import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/models/flashcard.dart';
import 'package:nihongo_japanese_app/screens/user_quiz_screen.dart';
import 'package:nihongo_japanese_app/services/challenge_progress_service.dart';
import 'package:nihongo_japanese_app/services/daily_points_service.dart';
import 'package:nihongo_japanese_app/services/database_service.dart';
import 'package:nihongo_japanese_app/services/review_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Define review modes
enum ReviewMode {
  flashcard,
  quiz,
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> with TickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final ReviewProgressService _progressService = ReviewProgressService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Flashcard> _flashcards = [];
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  ReviewMode? _selectedMode;
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isLoading = true;
  String _errorMessage = '';

  // View mode for category selection
  bool _isGridView = true;

  // Animation controllers
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shakeController;

  // Add new animation controllers for enhanced animations
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _bounceController;
  late AnimationController _rotateController;

  // Add new animations
  late Animation<double> _bounceAnimation;
  late Animation<double> _rotateAnimation;

  // Add new variables for enhanced UI
  bool _isTransitioning = false;
  bool _showAchievement = false;
  String _achievementMessage = '';

  // Review stats
  int _correctCount = 0;
  int _incorrectCount = 0;
  int _totalCards = 0;

  // Streak tracking
  int _streak = 0;
  int _maxStreak = 0;

  // Quiz specific variables
  List<String> _quizOptions = [];
  int _selectedOptionIndex = -1;
  bool _isOptionSelected = false;
  Timer? _quizTimer;
  int _remainingSeconds = 30; // 30 seconds per question
  bool _isTimeUp = false;

  // Gamification elements
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _perfectAnswers = 0;
  bool _showFeedback = false;
  String _feedbackMessage = '';
  Color _feedbackColor = Colors.green;
  Timer? _feedbackTimer;
  List<String> _unlockedAchievements = [];

  // Confetti controller for celebrations
  late ConfettiController _confettiController;

  // Map of category icons
  final Map<String, IconData> _categoryIcons = {
    'waving_hand': Icons.waving_hand, // Greetings
    'category': Icons.category, // Basic Nouns
    'directions_run': Icons.directions_run, // Basic Verbs
    'format_color_fill': Icons.format_color_fill, // Basic Adjectives
    'schedule': Icons.schedule, // Time Expressions
    'family_restroom': Icons.family_restroom, // Family Members
    'restaurant': Icons.restaurant, // Food & Drink
    'calculate': Icons.calculate, // Numbers
    'wb_sunny': Icons.wb_sunny, // Weather
    'flight': Icons.flight, // Travel
    'default': Icons.style, // Default icon
  };

  // Add these animation controllers for points animation
  late AnimationController _pointsAnimationController;
  late Animation<double> _pointsSlideAnimation;
  late Animation<double> _pointsOpacityAnimation;
  late Animation<double> _pointsScaleAnimation;
  String _pointsChangeText = '';
  Color _pointsChangeColor = Colors.amber;
  Offset _pointsStartPosition = Offset.zero;
  Offset _pointsEndPosition = Offset.zero;

  // Add new variables for tracking completed reviews
  List<String> _completedReviews = [];
  bool _isReviewCompleted = false;

  // Helper method to get icon from name
  IconData _getIconFromName(String iconName) {
    return _categoryIcons[iconName] ?? _categoryIcons['default']!;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeAnimations();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // Check if there's a last selected category and load it
    _checkForLastSelectedCategory();

    // Check if we were navigated to with specific arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        final categoryId = args['categoryId'] as String?;
        final isQuizMode = args['isQuizMode'] as bool?;

        if (categoryId != null && isQuizMode != null) {
          print(
              'Direct navigation to ReviewScreen with categoryId: $categoryId, isQuizMode: $isQuizMode');
          navigateToCategory(categoryId, isQuizMode);
        }
      }
    });
  }

  // Update the _checkForLastSelectedCategory method to also check for review mode
  Future<void> _checkForLastSelectedCategory() async {
    // Only load completed reviews for UI indicators
    await _loadCompletedReviews();

    // We're not setting _selectedCategoryId or _selectedMode here anymore
    // This will keep the default state in category selection
  }

  // Add a method to handle direct navigation to a specific category and mode
  void navigateToCategory(String categoryId, bool isQuizMode) {
    print('Navigating to category: $categoryId, isQuizMode: $isQuizMode');

    setState(() {
      _selectedMode = isQuizMode ? ReviewMode.quiz : ReviewMode.flashcard;
      _selectedCategoryId = categoryId;
    });

    // Load saved progress and flashcards for the selected category
    _loadSavedProgress();
    _loadFlashcards();
  }

  // Make sure to extract the animation initialization to a separate method
  void _initializeAnimations() {
    // All your animation controller initialization code here
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(
        parent: _flipController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeIn,
      ),
    );

    // Initialize new animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.elasticOut,
      ),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _rotateController,
        curve: Curves.easeInOut,
      ),
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Initialize points animation
    _pointsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pointsSlideAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pointsAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _pointsOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _pointsAnimationController,
        curve: Curves.easeIn,
      ),
    );

    _pointsScaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(
        parent: _pointsAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final categories = await _databaseService.getFlashcardCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
      _fadeController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load categories: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFlashcards() async {
    if (_selectedCategoryId == null) {
      print('Cannot load flashcards: No category selected');
      return;
    }

    print('Loading flashcards for category: $_selectedCategoryId');

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final flashcards = await _databaseService.getFlashcardsByCategory(_selectedCategoryId!);
      print('Loaded ${flashcards.length} flashcards for category: $_selectedCategoryId');

      // Shuffle the flashcards for random review
      final random = math.Random();
      flashcards.shuffle(random);

      setState(() {
        _flashcards = flashcards;
        _totalCards = flashcards.length;
        _isLoading = false;
      });
      _fadeController.forward();

      // Check if the category is already completed
      if (_selectedMode == ReviewMode.quiz && _completedReviews.contains(_selectedCategoryId!)) {
        // Show completion dialog
        _showCategoryCompletionDialog();
      } else if (_selectedMode == ReviewMode.quiz) {
        // If not completed, prepare the first question
        _prepareQuizQuestion();
      }
    } catch (e) {
      print('Error loading flashcards: $e');
      setState(() {
        _errorMessage = 'Failed to load flashcards: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedProgress() async {
    if (_selectedCategoryId != null) {
      final savedScore = await _progressService.getCategoryScore(_selectedCategoryId!);
      final savedStreak = await _progressService.getCategoryStreak(_selectedCategoryId!);
      final savedMaxStreak = await _progressService.getCategoryMaxStreak(_selectedCategoryId!);
      final savedPerfectAnswers =
          await _progressService.getCategoryPerfectAnswers(_selectedCategoryId!);
      final savedAchievements =
          await _progressService.getCategoryAchievements(_selectedCategoryId!);
      final completedReviews = await _progressService.getCompletedReviews(_selectedCategoryId!);

      setState(() {
        _score = savedScore;
        _streak = savedStreak;
        _maxStreak = savedMaxStreak;
        _perfectAnswers = savedPerfectAnswers;
        _unlockedAchievements = savedAchievements;
        _completedReviews = completedReviews;
        _isReviewCompleted = completedReviews.contains(_selectedCategoryId!);
      });
    }
  }

  Future<void> _loadCompletedReviews() async {
    // Load all completed reviews regardless of category
    final completedReviews = await _progressService.getAllCompletedReviews();
    setState(() {
      _completedReviews = completedReviews;
    });
  }

  void _prepareQuizQuestion() {
    if (_currentIndex >= _flashcards.length) return;

    // Check if quiz is already completed
    if (_isReviewCompleted) {
      _showCategoryCompletionDialog();
      return;
    }

    // Reset quiz state
    setState(() {
      _selectedOptionIndex = -1;
      _isOptionSelected = false;
      _isTimeUp = false;
      _remainingSeconds = 30;
      _showFeedback = false;
    });

    // Generate options for the current question
    _generateQuizOptions();

    // Start the timer
    _startQuizTimer();
  }

  void _generateQuizOptions() {
    if (_currentIndex >= _flashcards.length) return;

    final currentCard = _flashcards[_currentIndex];
    final random = math.Random();

    // Create a list of all possible answers (excluding the current card)
    List<String> allAnswers =
        _flashcards.where((card) => card.id != currentCard.id).map((card) => card.back).toList();

    // Shuffle and take 3 random wrong answers
    allAnswers.shuffle(random);
    List<String> wrongAnswers = allAnswers.take(3).toList();

    // Add the correct answer
    List<String> options = [...wrongAnswers, currentCard.back];

    // Shuffle the options
    options.shuffle(random);

    setState(() {
      _quizOptions = options;
      // Find the index of the correct answer
      _selectedOptionIndex = options.indexOf(currentCard.back);
    });
  }

  void _startQuizTimer() {
    // Don't start timer if quiz is completed
    if (_isReviewCompleted) return;

    _quizTimer?.cancel();
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isReviewCompleted) {
        // Additional check
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _isTimeUp = true;
            timer.cancel();
          }
        });
      }
    });
  }

  void _flipCard() {
    if (_flipController.status == AnimationStatus.completed) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }

    // Play flip sound
    _playSound('flip');

    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  void _handleResponse(bool isCorrect) async {
    if (isCorrect) {
      _correctCount++;
      _streak++;
      if (_streak > _maxStreak) {
        _maxStreak = _streak;
      }

      // Only calculate points in quiz mode
      if (_selectedMode == ReviewMode.quiz) {
        // Calculate points based on streak
        int pointsEarned = 100;
        if (_streak > 1) {
          pointsEarned = (100 * (1 + (_streak * 0.1))).round();
        }

        _score += pointsEarned;

        // Play success sound
        _playSound('success');

        // Show points animation
        _showPointsAnimation(
          '⭐ +$pointsEarned Moji Points',
          Colors.amber,
          Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2),
          Offset(MediaQuery.of(context).size.width / 2, 50),
        );

        // Set feedback message
        _feedbackMessage = '⭐ +$pointsEarned Moji Points';
        if (_streak > 1) {
          _feedbackMessage += ' (${_streak}x)';
        }
        _feedbackColor = Colors.amber;

        // Check for achievements
        _checkAchievements();

        // Save progress
        if (_selectedCategoryId != null) {
          await _progressService.saveCategoryScore(_selectedCategoryId!, _score);
          await _progressService.saveCategoryStreak(_selectedCategoryId!, _streak);
          await _progressService.saveCategoryMaxStreak(_selectedCategoryId!, _maxStreak);
          await _progressService.saveCategoryPerfectAnswers(_selectedCategoryId!, _perfectAnswers);
          await _progressService.saveCategoryAchievements(
              _selectedCategoryId!, _unlockedAchievements);
        }
      } else {
        // In flashcard mode, just play success sound
        _playSound('success');

        // Set feedback message
        _feedbackMessage = 'Correct!';
        _feedbackColor = Colors.green;
      }
    } else {
      _incorrectCount++;
      _streak = 0;

      // Play error sound
      _playSound('error');

      // Set feedback message
      _feedbackMessage = '❌ Incorrect';
      _feedbackColor = Colors.red;

      // Shake animation for incorrect answer
      _shakeController.forward(from: 0);

      // Save progress only in quiz mode
      if (_selectedMode == ReviewMode.quiz && _selectedCategoryId != null) {
        await _progressService.saveCategoryScore(_selectedCategoryId!, _score);
        await _progressService.saveCategoryStreak(_selectedCategoryId!, _streak);
        await _progressService.saveCategoryMaxStreak(_selectedCategoryId!, _maxStreak);
      }
    }

    // Show feedback
    setState(() {
      _showFeedback = true;
    });

    // Hide feedback after 1.5 seconds
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showFeedback = false;
        });
      }
    });

    // Update the flashcard review status in the database
    if (_currentIndex < _flashcards.length) {
      final currentCard = _flashcards[_currentIndex];
      await _databaseService.updateFlashcardReview(currentCard.id, isCorrect);
    }

    // Move to next card
    if (_currentIndex < _flashcards.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
      _flipController.reset();
      _fadeController.reset();
      _fadeController.forward();

      // If in quiz mode, prepare the next question
      if (_selectedMode == ReviewMode.quiz) {
        _prepareQuizQuestion();
      }
    } else {
      // Show review summary
      _showReviewSummary();
    }
  }

  void _handleQuizOptionSelection(int index) async {
    if (_isOptionSelected) return;

    setState(() {
      _isOptionSelected = true;
    });

    // Cancel the timer
    _quizTimer?.cancel();

    // Check if the selected option is correct
    final isCorrect = index == _selectedOptionIndex;

    // Calculate points based on time remaining and combo
    int pointsEarned = 0;
    if (isCorrect) {
      // Base points for correct answer
      pointsEarned = 100;

      // Bonus points for quick answer
      if (_remainingSeconds > 20) {
        pointsEarned += 50; // Speed bonus
        _perfectAnswers++;
      }

      // Combo bonus
      _combo++;
      if (_combo > _maxCombo) {
        _maxCombo = _combo;
      }

      // Combo multiplier
      if (_combo > 1) {
        pointsEarned = (pointsEarned * (1 + (_combo * 0.1))).round();
      }

      _score += pointsEarned;
      _correctCount++;
      _streak++;
      if (_streak > _maxStreak) {
        _maxStreak = _streak;
      }

      // Check for achievements
      _checkAchievements();

      // Play success sound
      _playSound('success');

      // Set feedback message with appropriate icon
      String icon = '⭐'; // Default star icon
      if (_remainingSeconds > 20) {
        icon = '⚡'; // Lightning bolt for perfect timing
      }
      if (_combo > 1) {
        icon = '🔥'; // Fire for combo
      }

      // Save progress
      if (_selectedCategoryId != null) {
        await _progressService.saveCategoryScore(_selectedCategoryId!, _score);
        await _progressService.saveCategoryStreak(_selectedCategoryId!, _streak);
        await _progressService.saveCategoryMaxStreak(_selectedCategoryId!, _maxStreak);
        await _progressService.saveCategoryPerfectAnswers(_selectedCategoryId!, _perfectAnswers);
        await _progressService.saveCategoryAchievements(
            _selectedCategoryId!, _unlockedAchievements);
      }

      // Get the position of the score display in the app bar
      final RenderBox? scoreBox = context.findRenderObject() as RenderBox?;
      if (scoreBox != null) {
        final scorePosition = scoreBox.localToGlobal(Offset.zero);
        final scoreSize = scoreBox.size;

        // Calculate the center of the score display
        final scoreCenter = Offset(
          scorePosition.dx + scoreSize.width / 2,
          scorePosition.dy + scoreSize.height / 2,
        );

        // Get the position of the selected option
        final RenderBox? optionBox = context.findRenderObject() as RenderBox?;
        if (optionBox != null) {
          final optionPosition = optionBox.localToGlobal(Offset.zero);
          final optionSize = optionBox.size;

          // Calculate the center of the selected option
          final optionCenter = Offset(
            optionPosition.dx + optionSize.width / 2,
            optionPosition.dy + optionSize.height / 2,
          );

          // Show points animation
          _showPointsAnimation(
            '$icon +$pointsEarned Moji Points',
            Colors.amber,
            optionCenter,
            scoreCenter,
          );
        }
      }

      // Set feedback message (smaller and more compact)
      _feedbackMessage = '$icon +$pointsEarned Moji Points';
      if (_remainingSeconds > 20) {
        _feedbackMessage += ' (Perfect!)';
      }
      if (_combo > 1) {
        _feedbackMessage += ' (${_combo}x)';
      }
      _feedbackColor = Colors.amber;
    } else {
      _incorrectCount++;
      _streak = 0;
      _combo = 0;

      // Play error sound
      _playSound('error');

      // Set feedback message
      _feedbackMessage = '❌ Incorrect';
      _feedbackColor = Colors.red;

      // Save progress
      if (_selectedCategoryId != null) {
        await _progressService.saveCategoryScore(_selectedCategoryId!, _score);
        await _progressService.saveCategoryStreak(_selectedCategoryId!, _streak);
        await _progressService.saveCategoryMaxStreak(_selectedCategoryId!, _maxStreak);
      }
    }

    // Show feedback
    setState(() {
      _showFeedback = true;
    });

    // Hide feedback after 1.5 seconds
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showFeedback = false;
        });
      }
    });

    // Update the flashcard review status in the database
    if (_currentIndex < _flashcards.length) {
      final currentCard = _flashcards[_currentIndex];
      await _databaseService.updateFlashcardReview(currentCard.id, isCorrect);
    }

    // Show feedback for a short time before moving to the next question
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        // Move to next question
        if (_currentIndex < _flashcards.length - 1) {
          setState(() {
            _currentIndex++;
          });
          _fadeController.reset();
          _fadeController.forward();
          _prepareQuizQuestion();
        } else {
          // Show review summary
          _showReviewSummary();
        }
      }
    });
  }

  void _checkAchievements() {
    if (_selectedCategoryId == null) return;

    // Check for achievements
    if (_correctCount == 10 && !_unlockedAchievements.contains('${_selectedCategoryId}_first_10')) {
      _unlockAchievement('${_selectedCategoryId}_first_10', 'First 10: Correct 10 flashcards');
    }

    if (_correctCount == 50 && !_unlockedAchievements.contains('${_selectedCategoryId}_first_50')) {
      _unlockAchievement('${_selectedCategoryId}_first_50', 'Half Century: Correct 50 flashcards');
    }

    if (_correctCount == 100 &&
        !_unlockedAchievements.contains('${_selectedCategoryId}_first_100')) {
      _unlockAchievement('${_selectedCategoryId}_first_100', 'Century: Correct 100 flashcards');
    }

    if (_streak == 5 && !_unlockedAchievements.contains('${_selectedCategoryId}_streak_5')) {
      _unlockAchievement('${_selectedCategoryId}_streak_5', 'On Fire: Get a 5-card streak');
    }

    if (_streak == 10 && !_unlockedAchievements.contains('${_selectedCategoryId}_streak_10')) {
      _unlockAchievement('${_selectedCategoryId}_streak_10', 'Unstoppable: Get a 10-card streak');
    }

    if (_perfectAnswers == 5 &&
        !_unlockedAchievements.contains('${_selectedCategoryId}_perfect_5')) {
      _unlockAchievement(
          '${_selectedCategoryId}_perfect_5', 'Perfect Timing: Get 5 perfect answers');
    }

    if (_combo == 5 && !_unlockedAchievements.contains('${_selectedCategoryId}_combo_5')) {
      _unlockAchievement('${_selectedCategoryId}_combo_5', 'Combo Master: Get a 5x combo');
    }
  }

  void _unlockAchievement(String id, String message) {
    setState(() {
      _unlockedAchievements.add(id);
      _achievementMessage = message;
      _showAchievement = true;
    });

    // Play achievement sound
    _playSound('achievement');

    // Hide achievement after 3 seconds
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() {
          _showAchievement = false;
        });
      }
    });
  }

  Future<void> _playSound(String soundType) async {
    try {
      switch (soundType) {
        case 'success':
          await _audioPlayer.play(AssetSource('sounds/correct.wav'));
          break;
        case 'error':
          await _audioPlayer.play(AssetSource('sounds/error.wav'));
          break;
        case 'achievement':
          await _audioPlayer.play(AssetSource('sounds/achievement.wav'));
          break;
        case 'flip':
          await _audioPlayer.play(AssetSource('sounds/flip.wav'));
          break;
      }
    } catch (e) {
      // Ignore errors if sound files are not available
      print('Error playing sound: $e');
    }
  }

  void _showReviewSummary() async {
    // Save recent activity
    await _progressService.saveRecentActivity(
      _selectedCategoryId!,
      score: _score,
      correctCount: _correctCount,
      totalCards: _totalCards,
      isQuizMode: _selectedMode == ReviewMode.quiz,
    );

    // Mark the review as completed only in quiz mode
    if (_selectedMode == ReviewMode.quiz && _selectedCategoryId != null) {
      await _progressService.saveCompletedReview(_selectedCategoryId!);
      setState(() {
        _completedReviews.add(_selectedCategoryId!);
        _isReviewCompleted = true;
      });

      // Play achievement sound when quiz is completed
      _playSound('achievement');

      // Start confetti animation for quiz completion
      _confettiController.play();
    }

    final accuracy = _totalCards > 0 ? (_correctCount / _totalCards * 100).toStringAsFixed(1) : '0';
    _categories.firstWhere((cat) => cat['id'] == _selectedCategoryId);

    // Calculate grade based on performance
    String grade = 'F';
    if (accuracy == '100') {
      grade = 'S';
    } else if (double.parse(accuracy) >= 90) {
      grade = 'A';
    } else if (double.parse(accuracy) >= 80) {
      grade = 'B';
    } else if (double.parse(accuracy) >= 70) {
      grade = 'C';
    } else if (double.parse(accuracy) >= 60) {
      grade = 'D';
    }

    // Calculate stars (1-3) based on performance
    int stars = 1;
    if (double.parse(accuracy) >= 90) {
      stars = 3;
    } else if (double.parse(accuracy) >= 70) {
      stars = 2;
    }

    // Determine if we should offer a quiz based on performance
    bool offerQuiz = _selectedMode == ReviewMode.flashcard && double.parse(accuracy) >= 70;

    // Check if quiz is already completed
    bool isQuizCompleted = _completedReviews.contains(_selectedCategoryId!);

    // Add confetti animation for quiz completion
    if (_selectedMode == ReviewMode.quiz) {
      _confettiController.play();

      // Hide confetti after 3 seconds
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) {
          _confettiController.stop();
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stars section with gradient background
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade300, Colors.amber.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (index) => Icon(
                        Icons.star,
                        size: 32,
                        color: index < stars ? Colors.white : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Great Job!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You earned $stars ${stars == 1 ? 'star' : 'stars'}!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Score section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Grade display
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _getGradeColor(grade).withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getGradeColor(grade),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        grade,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _getGradeColor(grade),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats grid
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      if (_selectedMode == ReviewMode.quiz)
                        _buildStatCard('Moji Points', _score.toString(), Icons.stars, Colors.amber),
                      _buildStatCard('Accuracy', '$accuracy%', Icons.analytics, Colors.blue),
                      if (_selectedMode == ReviewMode.quiz)
                        _buildStatCard('Perfect', _perfectAnswers.toString(), Icons.check_circle,
                            Colors.green),
                      _buildStatCard('Streak', _maxStreak.toString(), Icons.local_fire_department,
                          Colors.orange),
                    ],
                  ),

                  // Quiz offer section (only in flashcard mode with good performance)
                  if (offerQuiz)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.quiz,
                                  color: Colors.purple,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isQuizCompleted
                                        ? 'Quiz Already Taken'
                                        : 'Ready for a Challenge?',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isQuizCompleted
                                  ? 'Would you like to retake this quiz? This will reset your previous score.'
                                  : 'You\'ve mastered these flashcards! Take a quiz to earn points and test your knowledge.',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                if (isQuizCompleted) {
                                  // Reset progress before switching to quiz mode
                                  _resetReview();
                                }
                                setState(() {
                                  _selectedMode = ReviewMode.quiz;
                                  if (!isQuizCompleted) {
                                    _resetReview();
                                  }
                                });
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: Text(isQuizCompleted ? 'Retake Quiz' : 'Take Quiz Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Only show reset confirmation in quiz mode
                        if (_selectedMode == ReviewMode.quiz) {
                          _showResetConfirmationDialog();
                        } else {
                          // In flashcard mode, just reset without confirmation
                          _resetReview();
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedCategoryId = null;
                          _resetReview();
                        });
                      },
                      icon: const Icon(Icons.category),
                      label: const Text('Categories'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.amber),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _resetReview() async {
    // Only reset progress and points in quiz mode
    if (_selectedMode == ReviewMode.quiz && _selectedCategoryId != null) {
      await _progressService.resetCategoryProgress(_selectedCategoryId!);
      await _progressService.removeCompletedReview(_selectedCategoryId!);

      setState(() {
        _score = 0;
        _combo = 0;
        _maxCombo = 0;
        _perfectAnswers = 0;
        _unlockedAchievements = [];
        _isReviewCompleted = false;
        _completedReviews.remove(_selectedCategoryId);
        _correctCount = 0;
        _incorrectCount = 0;
        _streak = 0;
        _currentIndex = 0;
        _showAnswer = false;
      });
    } else {
      // For non-quiz mode, just reset the basic counters
      setState(() {
        _currentIndex = 0;
        _showAnswer = false;
        _correctCount = 0;
        _incorrectCount = 0;
        _streak = 0;
      });
    }

    _flipController.reset();
    _fadeController.reset();
    _fadeController.forward();
    _loadFlashcards();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _bounceController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _shakeController.dispose();
    _pointsAnimationController.dispose();
    _quizTimer?.cancel();
    _feedbackTimer?.cancel();
    _audioPlayer.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _showPointsAnimation(String text, Color color, Offset startPosition, Offset endPosition) {
    setState(() {
      _pointsChangeText = text;
      _pointsChangeColor = color;
      _pointsStartPosition = startPosition;
      _pointsEndPosition = endPosition;
    });
    _pointsAnimationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Review',
          style: TextStyle(fontFamily: 'TheLastShuriken', fontSize: 25),
        ),
        leading: _selectedCategoryId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // Show confirmation dialog if in quiz mode and quiz is in progress
                  if (_selectedMode == ReviewMode.quiz && _currentIndex > 0) {
                    _showExitConfirmationDialog();
                  } else {
                    setState(() {
                      _selectedCategoryId = null;
                      _resetReview();
                    });
                  }
                },
                tooltip: 'Back to Categories',
              )
            : _selectedMode != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _selectedMode = null;
                      });
                    },
                    tooltip: 'Back to Mode Selection',
                  )
                : null,
        actions: [
          if (_selectedCategoryId != null &&
              !_isReviewCompleted &&
              _selectedMode == ReviewMode.flashcard)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetReview,
              tooltip: 'Restart Review',
            ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed:
                                _selectedCategoryId == null ? _loadCategories : _loadFlashcards,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  : _selectedMode == null
                      ? _buildModeSelection()
                      : _selectedCategoryId == null
                          ? _buildCategorySelection()
                          : _flashcards.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.sentiment_dissatisfied,
                                          size: 64, color: Colors.grey),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No flashcards available in this category',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _selectedCategoryId = null;
                                          });
                                        },
                                        icon: const Icon(Icons.category),
                                        label: const Text('Choose Different Category'),
                                      ),
                                    ],
                                  ),
                                )
                              : _selectedMode == ReviewMode.flashcard
                                  ? _buildReviewContent()
                                  : _buildQuizContent(),

          // Achievement overlay
          if (_showAchievement)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _achievementMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Confetti overlay for celebrations
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: math.pi / 2, // straight down
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

  Widget _buildModeSelection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Choose Review Mode',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  _buildModeCard(
                    title: 'Flashcard Review',
                    description:
                        'Review flashcards at your own pace. Flip cards to reveal answers and track your progress.',
                    icon: Icons.style,
                    color: Colors.blue,
                    onTap: () {
                      setState(() {
                        _selectedMode = ReviewMode.flashcard;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildModeCard(
                    title: 'Quiz Mode',
                    description:
                        'Test your knowledge with timed quizzes. Challenge yourself with multiple-choice questions.',
                    icon: Icons.quiz,
                    color: Colors.purple,
                    onTap: () {
                      setState(() {
                        _selectedMode = ReviewMode.quiz;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildAdminQuizAdCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminQuizAdCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserQuizScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber[400]!,
                  Colors.orange[500]!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Left side - Icon and main content
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin Quizzes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Want to earn more moji points? Discover more quiz challenges created by admins!',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Right side - CTA button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Explore',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.7),
                color,
              ],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 40,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a Category',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedMode == ReviewMode.flashcard
                      ? 'Choose a category to review with flashcards'
                      : 'Choose a category for your quiz',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // View toggle buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildViewToggleButton(
                        icon: Icons.grid_view,
                        isSelected: _isGridView,
                        onPressed: () => setState(() => _isGridView = true),
                      ),
                      _buildViewToggleButton(
                        icon: Icons.view_list,
                        isSelected: !_isGridView,
                        onPressed: () => setState(() => _isGridView = false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Categories list/grid
          Expanded(
            child: _isGridView
                ? GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) => _buildCategoryCard(_categories[index]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCategoryListItem(_categories[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.purple : Colors.grey,
            size: 24,
          ),
        ),
      ),
    );
  }

  // Update the quiz mode selection to show retake confirmation
  void _handleCategorySelection(Map<String, dynamic> category) async {
    if (_selectedMode == ReviewMode.quiz && _completedReviews.contains(category['id'])) {
      // Show retake confirmation for completed quizzes
      final bool shouldRetake = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Quiz Already Completed'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'You have already taken this quiz. Would you like to retake it?',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Note: This will reset your previous score.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retake Quiz'),
                ),
              ],
            ),
          ) ??
          false;

      if (!shouldRetake) return;
    }

    // Play tap sound
    _playSound('flip');

    // Add bounce animation
    _bounceController.forward(from: 0.0);

    setState(() {
      _selectedCategoryId = category['id'];
      _isTransitioning = true;
    });

    // Delay the actual navigation to allow animation to play
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _isTransitioning = false;
      });
      _loadFlashcards();
    });
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final color = Color(int.parse(category['color'].substring(1, 7), radix: 16) + 0xFF000000);
    final icon = _getIconFromName(category['icon']);
    final isCompleted = _completedReviews.contains(category['id']);

    return Hero(
      tag: 'category_${category['id']}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleCategorySelection(category),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.8),
                  color,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Main content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 40,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        category['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category['description'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Completion badge
                if (isCompleted && _selectedMode == ReviewMode.quiz)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Done',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryListItem(Map<String, dynamic> category) {
    final color = Color(int.parse(category['color'].substring(1, 7), radix: 16) + 0xFF000000);
    final icon = _getIconFromName(category['icon']);
    final isCompleted = _completedReviews.contains(category['id']);

    return Hero(
      tag: 'category_${category['id']}',
      child: Card(
        elevation: 8,
        shadowColor: color.withOpacity(0.5),
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            // Play tap sound
            _playSound('flip');

            // Add bounce animation
            _bounceController.forward(from: 0.0);

            // Set transitioning state
            setState(() {
              _isTransitioning = true;
            });

            // Delay the actual navigation to allow animation to play
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() {
                _selectedCategoryId = category['id'];
                _isTransitioning = false;
              });
              _loadFlashcards();
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedBuilder(
            animation: _bounceController,
            builder: (context, child) {
              return Transform.scale(
                scale: _isTransitioning && _selectedCategoryId == category['id']
                    ? 1.0 + (_bounceAnimation.value * 0.05)
                    : 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        color.withOpacity(0.7),
                        color,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Icon with animation
                        AnimatedBuilder(
                          animation: _rotateController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _isTransitioning && _selectedCategoryId == category['id']
                                  ? _rotateAnimation.value
                                  : 0,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    icon,
                                    size: 32,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        // Category info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                category['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                category['description'],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Completion and points indicators
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isCompleted && _selectedMode == ReviewMode.quiz)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Completed',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_selectedMode == ReviewMode.quiz)
                              FutureBuilder<int>(
                                future: _progressService.getCategoryScore(category['id']),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData || snapshot.data == 0) {
                                    return const SizedBox.shrink();
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.stars,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${snapshot.data} Moji Points',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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
      ),
    );
  }

  Widget _buildReviewContent() {
    final currentCard = _flashcards[_currentIndex];
    final category = _categories.firstWhere((cat) => cat['id'] == currentCard.categoryId);
    final categoryColor =
        Color(int.parse(category['color'].substring(1, 7), radix: 16) + 0xFF000000);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _flashcards.length,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
            minHeight: 8,
          ),

          // Stats bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentIndex + 1}/${_flashcards.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text('$_correctCount'),
                    const SizedBox(width: 16),
                    const Icon(Icons.cancel, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text('$_incorrectCount'),
                    const SizedBox(width: 16),
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text('$_streak'),
                  ],
                ),
              ],
            ),
          ),

          // Category indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(
                  _getIconFromName(category['icon']),
                  color: categoryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  category['name'],
                  style: TextStyle(
                    color: categoryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _selectedMode == ReviewMode.flashcard
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedMode == ReviewMode.flashcard ? Icons.style : Icons.quiz,
                        size: 16,
                        color: _selectedMode == ReviewMode.flashcard ? Colors.blue : Colors.purple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedMode == ReviewMode.flashcard ? 'Flashcard' : 'Quiz',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              _selectedMode == ReviewMode.flashcard ? Colors.blue : Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Flashcard
          Expanded(
            child: GestureDetector(
              onTap: _flipCard,
              child: Center(
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(_flipAnimation.value),
                      alignment: Alignment.center,
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: MediaQuery.of(context).size.height * 0.4,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                categoryColor.withOpacity(0.1),
                                Colors.white,
                              ],
                            ),
                          ),
                          child: Center(
                            child: _flipAnimation.value < math.pi / 2
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        currentCard.front,
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Tap to reveal answer',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  )
                                : Transform(
                                    transform: Matrix4.identity()..rotateY(math.pi),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          currentCard.back,
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          category['name'],
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
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
                ),
              ),
            ),
          ),

          // Response buttons (only show when answer is revealed)
          if (_showAnswer)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _handleResponse(false),
                    icon: const Icon(Icons.close),
                    label: const Text('Incorrect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _handleResponse(true),
                    icon: const Icon(Icons.check),
                    label: const Text('Correct'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Tap card to reveal answer',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuizContent() {
    final currentCard = _flashcards[_currentIndex];
    final category = _categories.firstWhere((cat) => cat['id'] == currentCard.categoryId);
    final categoryColor =
        Color(int.parse(category['color'].substring(1, 7), radix: 16) + 0xFF000000);

    // If the quiz is completed, show a completion message instead of the quiz
    if (_isReviewCompleted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events,
                size: 64,
                color: Colors.amber,
              ),
              const SizedBox(height: 24),
              Text(
                'Quiz Completed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: categoryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You have already completed this quiz. Score: $_score Moji Points',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      _showResetConfirmationDialog();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedCategoryId = null;
                        _resetReview();
                      });
                    },
                    icon: const Icon(Icons.category),
                    label: const Text('Back to Categories'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      side: BorderSide(color: categoryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
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

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          Column(
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _flashcards.length,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                minHeight: 8,
              ),

              // Stats bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_currentIndex + 1}/${_flashcards.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.stars, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text('$_score'),
                        const SizedBox(width: 16),
                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text('$_combo'),
                      ],
                    ),
                  ],
                ),
              ),

              // Timer
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer,
                      color: _remainingSeconds > 10 ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_remainingSeconds seconds',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds > 10 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

              // Question
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'What is the meaning of:',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          currentCard.front,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Choose the correct answer:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(
                        _quizOptions.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildQuizOption(
                            index,
                            _isOptionSelected,
                            _selectedOptionIndex,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Time's up message
              if (_isTimeUp && !_isOptionSelected)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Time\'s up!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          _handleQuizOptionSelection(-1); // -1 indicates time's up
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Continue'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Feedback overlay (smaller and more compact)
          if (_showFeedback)
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _feedbackColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _feedbackMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // Points animation overlay
          AnimatedBuilder(
            animation: _pointsAnimationController,
            builder: (context, child) {
              final currentPosition = Offset.lerp(
                _pointsStartPosition,
                _pointsEndPosition,
                _pointsSlideAnimation.value,
              )!;

              return Positioned(
                left: currentPosition.dx - 50,
                top: currentPosition.dy - 20,
                child: Opacity(
                  opacity: _pointsOpacityAnimation.value,
                  child: Transform.scale(
                    scale: _pointsScaleAnimation.value,
                    child: Text(
                      _pointsChangeText,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _pointsChangeColor,
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: _pointsChangeColor.withOpacity(0.5),
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuizOption(int index, bool isSelected, int correctIndex) {
    Color backgroundColor = Colors.white;
    Color borderColor = Colors.grey.shade300;
    Color textColor = Colors.black87;

    if (isSelected) {
      if (index == correctIndex) {
        // Correct answer
        backgroundColor = Colors.green.withOpacity(0.2);
        borderColor = Colors.green;
        textColor = Colors.green.shade800;
      } else if (index == _selectedOptionIndex && index != correctIndex) {
        // Wrong answer selected
        backgroundColor = Colors.red.withOpacity(0.2);
        borderColor = Colors.red;
        textColor = Colors.red.shade800;
      } else {
        // Other options
        backgroundColor = Colors.grey.withOpacity(0.1);
        borderColor = Colors.grey.shade300;
        textColor = Colors.grey.shade600;
      }
    }

    return InkWell(
      onTap: isSelected ? null : () => _handleQuizOptionSelection(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? (index == correctIndex
                        ? Colors.green.withOpacity(0.2)
                        : index == _selectedOptionIndex
                            ? Colors.red.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2))
                    : Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? (index == correctIndex
                          ? Colors.green
                          : index == _selectedOptionIndex
                              ? Colors.red
                              : Colors.grey)
                      : Colors.purple.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? (index == correctIndex
                            ? Colors.green
                            : index == _selectedOptionIndex
                                ? Colors.red
                                : Colors.grey)
                        : Colors.purple,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _quizOptions[index],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: textColor,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                index == correctIndex ? Icons.check_circle : Icons.cancel,
                color: index == correctIndex ? Colors.green : Colors.red,
              ),
          ],
        ),
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'S':
        return Colors.purple;
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.deepOrange;
      default:
        return Colors.red;
    }
  }

  // Add a new method to show exit confirmation dialog
  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Quiz?'),
        content: const Text(
          'Are you sure you want to exit your quiz? You will lose your current progress and points.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Reset progress before exiting
              if (_selectedCategoryId != null) {
                await _progressService.resetCategoryProgress(_selectedCategoryId!);
                await _progressService.removeCompletedReview(_selectedCategoryId!);
              }
              Navigator.pop(context);
              setState(() {
                _selectedCategoryId = null;
                _resetReview();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  // Add a new method to show reset confirmation dialog
  void _showResetConfirmationDialog() async {
    // Get the current quiz's Moji Points score for this specific category
    final quizPoints = _selectedCategoryId != null
        ? await _progressService.getCategoryScore(_selectedCategoryId!)
        : 0;

    // Get the total Moji Points from all sources
    final totalPoints = await Future.wait([
      // Challenge points from ChallengeProgressService
      ChallengeProgressService().getTotalPoints(),
      // Review points from ReviewProgressService
      ReviewProgressService().getTotalReviewPoints(),
      // Story points from SharedPreferences (if any)
      SharedPreferences.getInstance().then((prefs) => prefs.getInt('story_total_points') ?? 0),
      // Quiz points from SharedPreferences (if any)
      SharedPreferences.getInstance().then((prefs) => prefs.getInt('quiz_total_points') ?? 0),
      // Daily points from DailyPointsService
      DailyPointsService().getLastClaimTime().then((lastClaim) async {
        if (lastClaim == null) return 0;
        final multiplier = await DailyPointsService().getStreakBonusMultiplier();
        return (100 * multiplier).round(); // Daily points amount
      }),
    ]).then((results) => results.fold<int>(0, (sum, points) => sum + points));

    // Check if quiz points are higher than total points
    if (quizPoints > totalPoints) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon with animated background
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 1000),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Colors.red.withOpacity(0.1),
                            Colors.red.withOpacity(0.3),
                            Colors.red.withOpacity(0.1),
                          ],
                          stops: [0, value, 1],
                          transform: GradientRotation(value * 3 * 3.14),
                        ),
                      ),
                      child: child,
                    );
                  },
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Cannot Reset Progress',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),

                // Points comparison
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Quiz Moji Points:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.stars_rounded,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$quizPoints',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Moji Points:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.stars_rounded,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$totalPoints',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Explanation text
                const Text(
                  'Cannot reset quiz at the moment. Please complete more activities to increase your total Moji Points before resetting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // OK button
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Show normal reset confirmation dialog
      _showNormalResetConfirmationDialog();
    }
  }

  // Update the _showCategoryCompletionDialog method
  void _showCategoryCompletionDialog() {
    final category = _categories.firstWhere((cat) => cat['id'] == _selectedCategoryId);
    final categoryColor =
        Color(int.parse(category['color'].substring(1, 7), radix: 16) + 0xFF000000);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon and title
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [categoryColor.withOpacity(0.7), categoryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Quiz Already Completed!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category['name'],
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'You have already completed this quiz. Would you like to retake it?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<int>(
                    future: _progressService.getCategoryScore(_selectedCategoryId!),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.stars,
                              color: Colors.amber,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Score: ${snapshot.data} Moji Points',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showResetConfirmationDialog();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake Quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedCategoryId = null;
                        _resetReview();
                      });
                    },
                    icon: const Icon(Icons.category),
                    label: const Text('Back to Categories'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 0),
                      side: BorderSide(color: categoryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNormalResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
            border: Border.all(
              color: Colors.amber.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Question icon with animated background
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 1000),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.amber.withOpacity(0.1),
                          Colors.amber.withOpacity(0.3),
                          Colors.amber.withOpacity(0.1),
                        ],
                        stops: [0, value, 1],
                        transform: GradientRotation(value * 3 * 3.14),
                      ),
                    ),
                    child: child,
                  );
                },
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: Colors.amber,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Reset Progress?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 16),

              // Warning message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.3),
                  ),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'This will:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Clear your current score',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Reset your streak',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Remove earned Moji Points',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.amber),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resetReview();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
