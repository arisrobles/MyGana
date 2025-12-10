import 'package:flutter/material.dart';
import '../models/challenge_model.dart';
import '../services/database_service.dart';
import '../services/challenge_progress_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';

class ChallengeScreen extends StatefulWidget {
  final String? initialChallengeId;
  final String? topicId;
  final Color? topicColor;

  const ChallengeScreen({
    super.key,
    this.initialChallengeId,
    this.topicId,
    this.topicColor,
  });

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> with TickerProviderStateMixin {
  final ChallengeProgressService _progressService = ChallengeProgressService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Future<Challenge?> _challengeFuture = Future.value(null);
  String? _selectedAnswer;
  bool _hasSubmitted = false;
  int _attempts = 0;
  bool _showHint = false;
  bool _isCorrect = false;
  bool _showContinueButton = false;
  double _progressValue = 0.0;
  Timer? _progressTimer;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _scoreAnimationController;
  late Animation<double> _scoreScaleAnimation;
  late Animation<double> _scoreSlideAnimation;
  late Animation<double> _scoreOpacityAnimation;
  String _scoreChangeText = '';
  Color _scoreChangeColor = Colors.green;
  int _totalQuestions = 0;
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _streak = 0;
  final int _pointsPerQuestion = 100;
  final int _streakBonus = 50;
  final int _wrongAnswerPenalty = 25; // Penalty for each wrong attempt
  final int _skipPenalty = 75; // Penalty for skipping a question
  bool _isInitialized = false;
  List<Map<String, dynamic>> _topicChallenges = [];
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _bounceAnimation = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    );

    // Initialize score animation controller
    _scoreAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scoreScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20.0,
      ),
    ]).animate(_scoreAnimationController);

    _scoreSlideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 50.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.0),
        weight: 60.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -50.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20.0,
      ),
    ]).animate(_scoreAnimationController);

    _scoreOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 60.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 20.0,
      ),
    ]).animate(_scoreAnimationController);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _initializeScreen();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _bounceController.dispose();
    _scoreAnimationController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    print('Initializing screen for topic: ${widget.topicId}');
    print('Initial challenge ID: ${widget.initialChallengeId}');

    if (widget.topicId != null) {
      try {
        // Get challenges for the specific topic
        final challenges = await DatabaseService().getChallengesByTopic(widget.topicId!);
        print('Fetched ${challenges.length} challenges for ${widget.topicId}');
        
        if (challenges.isEmpty) {
          print('WARNING: No challenges found for topic ${widget.topicId}');
          // Get the topic details to verify it exists
          final topics = await DatabaseService().getChallengeTopics();
          final topic = topics.firstWhere(
            (t) => t['id'] == widget.topicId,
            orElse: () => {},
          );
          print('Topic details: $topic');
        } else {
          print('Challenge IDs: ${challenges.map((c) => c['id']).toList()}');
        }

        if (mounted) {
          setState(() {
            _topicChallenges = challenges;
            // Shuffle the challenges for random order
            _topicChallenges.shuffle();
            _totalQuestions = challenges.length;
          });
        }

        // Load saved progress
        final completedChallenges = await _progressService.getCompletedChallengesForTopic(widget.topicId!);
        final savedScore = await _progressService.getTopicScore(widget.topicId!);
        final savedStreak = await _progressService.getTopicStreak(widget.topicId!);

        if (mounted) {
          setState(() {
            _isInitialized = true;
            _score = savedScore;
            _streak = savedStreak;
            
            // Set current question index based on completed challenges
            _currentQuestionIndex = completedChallenges.length;
            
            // Check if all challenges are completed
            if (completedChallenges.length >= _totalQuestions) {
              // All challenges are completed, show completion message
              _showTopicCompletionDialog();
              return;
            }
            
            // Find the next uncompleted challenge
            String nextChallengeId;
            if (completedChallenges.isNotEmpty) {
              // Filter out completed challenges
              final uncompletedChallenges = _topicChallenges
                  .where((c) => !completedChallenges.contains(c['id']))
                  .toList();
              
              if (uncompletedChallenges.isNotEmpty) {
                nextChallengeId = uncompletedChallenges.first['id'] as String;
              } else {
                // All challenges are completed
                nextChallengeId = _topicChallenges.first['id'] as String;
              }
            } else {
              nextChallengeId = _topicChallenges.first['id'] as String;
            }
            
            _challengeFuture = _loadChallenge(nextChallengeId);
          });
        }
      } catch (e) {
        print('Error loading challenges for topic ${widget.topicId}:');
        print(e);
      }
    }
  }

  Future<Challenge?> _loadChallenge(String challengeId) async {
    print('Loading challenge with ID: $challengeId');
    print('Available challenges: ${_topicChallenges.map((c) => c['id']).toList()}');
    
    // First try to find the challenge in the already loaded topic challenges
    final localChallenge = _topicChallenges.firstWhere(
      (c) => c['id'] == challengeId,
      orElse: () => {},
    );

    if (localChallenge.isNotEmpty) {
      print('Found challenge in local data: $localChallenge');
      // Create a copy of the challenge map to avoid modifying the original
      final challengeMap = Map<String, dynamic>.from(localChallenge);
      // Parse and shuffle the options
      List<String> options = List<String>.from(jsonDecode(challengeMap['options'] as String));
      options.shuffle();
      challengeMap['options'] = jsonEncode(options);
      return Challenge.fromMap(challengeMap);
    }

    // If not found locally, try to find a challenge with a similar ID in the topic
    final similarChallenge = _topicChallenges.firstWhere(
      (c) => c['id'].toString().contains(challengeId.replaceAll(RegExp(r'[^0-9]'), '')),
      orElse: () => {},
    );

    if (similarChallenge.isNotEmpty) {
      print('Found similar challenge in topic: $similarChallenge');
      // Create a copy of the challenge map to avoid modifying the original
      final challengeMap = Map<String, dynamic>.from(similarChallenge);
      // Parse and shuffle the options
      List<String> options = List<String>.from(jsonDecode(challengeMap['options'] as String));
      options.shuffle();
      challengeMap['options'] = jsonEncode(options);
      return Challenge.fromMap(challengeMap);
    }

    // If still not found, use the first challenge of the topic
    if (_topicChallenges.isNotEmpty) {
      print('Using first challenge of topic: ${_topicChallenges.first}');
      // Create a copy of the challenge map to avoid modifying the original
      final challengeMap = Map<String, dynamic>.from(_topicChallenges.first);
      // Parse and shuffle the options
      List<String> options = List<String>.from(jsonDecode(challengeMap['options'] as String));
      options.shuffle();
      challengeMap['options'] = jsonEncode(options);
      return Challenge.fromMap(challengeMap);
    }

    // Last resort: try database (this should rarely happen now)
    print('Attempting database lookup for challenge: $challengeId');
    final map = await DatabaseService().getChallengeById(challengeId);
    if (map == null) {
      print('Failed to load challenge with ID: $challengeId');
      return null;
    }
    // Create a copy of the map to avoid modifying the original
    final challengeMap = Map<String, dynamic>.from(map);
    // Parse and shuffle the options
    List<String> options = List<String>.from(jsonDecode(challengeMap['options'] as String));
    options.shuffle();
    challengeMap['options'] = jsonEncode(options);
    return Challenge.fromMap(challengeMap);
  }

  void _handleChallengeLoad(String challengeId) {
    _fadeController.reverse().then((_) {
      setState(() {
        _challengeFuture = _loadChallenge(challengeId);
        _selectedAnswer = null;
        _hasSubmitted = false;
        _attempts = 0;
        _showHint = false;
        _isCorrect = false;
        _showContinueButton = false;
      });
      _fadeController.forward();
      _slideController.forward(from: 0);
    });
  }

  String _getFeedbackEmoji() {
    if (!_isCorrect) return '🤔';
    if (_attempts == 1) return '🌟'; // Excellent - first try
    if (_attempts == 2) return '👍'; // Very good - second try
    return '👌'; // Good - more attempts
  }

String _getFeedbackText() {
  if (!_isCorrect) return 'Try again or skip to the next question.';
  if (_attempts == 1) return 'Excellent! You got it right!';
  if (_attempts == 2) return 'Great work! You figured it out!';
  return 'Good job! Keep practicing!';
}

  void _showScoreChange(String text, Color color) {
    setState(() {
      _scoreChangeText = text;
      _scoreChangeColor = color;
    });
    _scoreAnimationController.forward(from: 0.0);
  }

  Future<void> _handleSubmit(Challenge challenge) async {
    if (_selectedAnswer == null) return;

    setState(() {
      _hasSubmitted = true;
      _attempts++;
      _isCorrect = challenge.isCorrect(_selectedAnswer!);

      if (_isCorrect) {
        // Play correct sound
        _playSound('correct');
        
        // Calculate score based on attempts and streak
        int questionScore = _pointsPerQuestion;
        
        // Apply penalties for previous wrong attempts
        int penalties = (_attempts - 1) * _wrongAnswerPenalty;
        questionScore = questionScore - penalties;

        // Add streak bonus only if answered correctly on first try
        if (_attempts == 1) {
          _streak++;
          questionScore += _streakBonus * _streak;
          _showScoreChange(
            '+$questionScore\n${_streak}x 🔥',
            Colors.green,
          );
        } else {
          _streak = 0;
          _showScoreChange('+$questionScore', Colors.green);
        }

        // Ensure minimum score of 10 points for correct answer
        questionScore = questionScore.clamp(10, _pointsPerQuestion + (_streakBonus * _streak));
        _score += questionScore;
        
        _bounceController.forward(from: 0.0);
        _startProgressAnimation();
      } else {
        // Play incorrect sound
        _playSound('incorrect');
        
        // Apply penalty for wrong answer
        _score = (_score - _wrongAnswerPenalty).clamp(0, double.infinity).toInt();
        _streak = 0;
        _showScoreChange('-$_wrongAnswerPenalty', Colors.red);
        
        if (_attempts >= 2) {
          _showHint = true;
        }
      }
    });

    // Save progress after state update
    if (_isCorrect) {
      await _progressService.saveCompletedChallenge(widget.topicId!, challenge.id);
      await _progressService.saveTopicScore(widget.topicId!, _score);
      await _progressService.saveTopicStreak(widget.topicId!, _streak);
      await _progressService.saveTopicStreakBonus(widget.topicId!, _streakBonus * _streak);
      await _progressService.saveLastCompletedChallenge(widget.topicId!, challenge.id);
      
      // Update overall progress
      final overallProgress = await _progressService.getOverallProgress();
      await _progressService.saveOverallProgress(
        totalScore: overallProgress['total_score']! + _pointsPerQuestion,
        totalChallengesCompleted: overallProgress['total_challenges_completed']! + 1,
        totalTopicsCompleted: overallProgress['total_topics_completed']!,
      );
      
      // Check if this was the last question and show completion dialog
      if (_currentQuestionIndex >= _totalQuestions - 1) {
        // Use a short delay to allow the UI to update first
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showTopicCompletionDialog();
          }
        });
      }
    } else {
      // Save updated score for wrong answer
      await _progressService.saveTopicScore(widget.topicId!, _score);
      await _progressService.saveTopicStreak(widget.topicId!, _streak);
      await _progressService.saveTopicStreakBonus(widget.topicId!, 0);
    }
  }

  void _startProgressAnimation() {
    final double targetProgress = (_currentQuestionIndex + 1) / _totalQuestions;
    const totalDuration = Duration(seconds: 1);
    const interval = Duration(milliseconds: 50);
    final steps = totalDuration.inMilliseconds ~/ interval.inMilliseconds;
    final stepValue = (targetProgress - _progressValue) / steps;
    int currentStep = 0;

    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(interval, (timer) {
      currentStep++;
      setState(() {
        _progressValue = _progressValue + stepValue;
      });

      if (currentStep >= steps) {
        timer.cancel();
        setState(() {
          _progressValue = targetProgress; // Ensure we hit exactly the target
          _showContinueButton = true;
        });
      }
    });
  }

  void _tryAgain() {
    setState(() {
      _hasSubmitted = false;
      _selectedAnswer = null;
      _isCorrect = false;
      _showHint = false;
    });
  }

  void _skipChallenge(Challenge challenge) {
    if (_currentQuestionIndex < _totalQuestions - 1) {
      // Play skip sound
      _playSound('skip');
      
      setState(() {
        _score = (_score - _skipPenalty).clamp(0, double.infinity).toInt();
        _streak = 0;
        _selectedAnswer = null;
        _hasSubmitted = false;
        _attempts = 0;
        _showHint = false;
        _isCorrect = false;
        _showContinueButton = false;
      });

      _showScoreChange('-$_skipPenalty', Colors.orange);

      _currentQuestionIndex++;
      // Get the next challenge from _topicChallenges
      final nextChallenge = _topicChallenges[_currentQuestionIndex];
      _challengeFuture = _loadChallenge(nextChallenge['id'] as String);
    }
  }

  void _continueToNext(Challenge challenge) async {
    if (_currentQuestionIndex < _totalQuestions - 1) {
      // Get completed challenges
      final completedChallenges = await _progressService.getCompletedChallengesForTopic(widget.topicId!);
      
      // Find the next uncompleted challenge
      final uncompletedChallenges = _topicChallenges
          .where((c) => !completedChallenges.contains(c['id']))
          .toList();
      
      if (uncompletedChallenges.isNotEmpty) {
        // Get the next uncompleted challenge
        final nextChallenge = uncompletedChallenges.first;
        // Update current question index to reflect completed questions
        _currentQuestionIndex = completedChallenges.length;
      _handleChallengeLoad(nextChallenge['id'] as String);
      } else {
        // All challenges are completed
        _showTopicCompletionDialog();
      }
    } else {
      // This was the last question, show completion dialog
      _showTopicCompletionDialog();
    }
  }

  Future<void> _navigateToNextTopic() async {
    // Get all topics
    final topics = await DatabaseService().getChallengeTopics();
    
    // Find current topic index
    final currentTopicIndex = topics.indexWhere((topic) => topic['id'] == widget.topicId);
    
    // If there's a next topic, navigate to it
    if (currentTopicIndex >= 0 && currentTopicIndex < topics.length - 1) {
      final nextTopic = topics[currentTopicIndex + 1];
      final nextTopicId = nextTopic['id'] as String;
      final nextTopicColor = _getColorFromString(nextTopic['color'] as String);
      
      // Get challenges for the next topic to ensure they exist
      final nextTopicChallenges = await DatabaseService().getChallengesByTopic(nextTopicId);
      
      if (mounted) {
        if (nextTopicChallenges.isNotEmpty) {
          // Find challenge-1 or use the first available challenge
          final firstChallenge = nextTopicChallenges.firstWhere(
            (c) => c['id'] == 'challenge-1',
            orElse: () => nextTopicChallenges.first,
          );
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChallengeScreen(
                initialChallengeId: firstChallenge['id'] as String,
                topicId: nextTopicId,
                topicColor: nextTopicColor,
              ),
            ),
          );
        } else {
          // Show error if no challenges found for the next topic
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No challenges found for topic: $nextTopicId'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // If this was the last topic, show completion dialog
      if (mounted) {
        _showTopicCompletionDialog();
      }
    }
  }

  void _showTopicCompletionDialog() {
    // Play completion sound
    _playSound('complete');
    
        showDialog(
          context: context,
          barrierDismissible: false,
      barrierColor: Colors.black54,
          builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.white,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Trophy Section with Purple Background
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: const BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 800),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: const Icon(
                                Icons.emoji_events,
                                color: Colors.amber,
                                size: 48,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Topic Completed!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Score Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Your Score',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TweenAnimationBuilder<int>(
                            duration: const Duration(seconds: 1),
                            tween: IntTween(begin: 0, end: _score),
                            builder: (context, value, child) {
                              return Text(
                                '$value',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Questions: $_currentQuestionIndex/$_totalQuestions',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Streak Section
                  if (_streak > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 600),
                                  tween: Tween(begin: 0.5, end: 1.2),
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: const Text(
                                        '🔥',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Hot Streak!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_streak}x Combo',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            Text(
                              '+${_streakBonus * _streak} Bonus Points',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // What's Next Section
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'What\'s Next?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () => _showResetConfirmationDialog(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Try Again',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _navigateToNextTopic();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Next Topic',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Topic List',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
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
          ),
        );
      },
    );
  }

  void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.width < 400;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Container(
              width: screenSize.width * 0.9,
              constraints: BoxConstraints(
                maxWidth: 400,
                maxHeight: screenSize.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Warning Header with Animation
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.red.shade400,
                          Colors.red.shade700,
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: const Icon(
                                Icons.warning_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            );
                          },
                  ),
                  const SizedBox(height: 16),
                  Text(
                          'Reset Progress?',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                            color: Colors.white,
                    ),
                  ),
                ],
              ),
                  ),

                  // Warning Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Are you sure you want to start over?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You will lose:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildResetWarningItem(
                                icon: Icons.stars,
                                text: 'Current score: $_score points',
                                delay: 0,
                              ),
                              _buildResetWarningItem(
                                icon: Icons.local_fire_department,
                                text: 'Streak progress: ${_streak}x',
                                delay: 200,
                              ),
                              _buildResetWarningItem(
                                icon: Icons.check_circle,
                                text: 'All completed questions',
                                delay: 400,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                  onPressed: () {
                              Navigator.of(context).pop();
                              _showTopicCompletionDialog();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _progressService.resetTopicProgress(widget.topicId!);
                              setState(() {
                                _score = 0;
                                _streak = 0;
                                _currentQuestionIndex = 0;
                                _progressValue = 0;
                              });
                              if (mounted) {
                                Navigator.of(context).pop();
                                _initializeScreen();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 4,
                            ),
                            child: const Text('Reset Progress'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
            );
          },
        );
      }

  Widget _buildResetWarningItem({
    required IconData icon,
    required String text,
    required int delay,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      opacity: 1.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        offset: Offset.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playSound(String soundType) async {
    try {
      switch (soundType) {
        case 'select':
          await _audioPlayer.play(AssetSource('sounds/select.wav'));
          break;
        case 'correct':
          await _audioPlayer.play(AssetSource('sounds/correct.wav'));
          break;
        case 'incorrect':
          await _audioPlayer.play(AssetSource('sounds/error.wav'));
          break;
        case 'level_up':
          await _audioPlayer.play(AssetSource('sounds/level_up.wav'));
          break;
        case 'achievement':
          await _audioPlayer.play(AssetSource('sounds/achievement.wav'));
          break;
        case 'complete':
          await _audioPlayer.play(AssetSource('sounds/complete.wav'));
          break;
        case 'skip':
          await _audioPlayer.play(AssetSource('sounds/skip.wav'));
          break;
      }
    } catch (e) {
      // Ignore errors if sound files are not available
      print('Error playing sound: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Japanese Learning'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, size: 20, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '$_score',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _streak > 0 ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _streak > 0 ? Colors.orange.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_streak}x',
                        style: TextStyle(
                          color: _streak > 0 ? Colors.orange : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '🔥',
                        style: TextStyle(
                          fontSize: 14,
                          color: _streak > 0 ? null : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<Challenge?>(
                  future: _challengeFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Error loading challenge: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Topic ID: ${widget.topicId}\n'
                              'Challenge ID: ${widget.initialChallengeId ?? "Not specified"}\n'
                              'Available Challenges: ${_topicChallenges.map((c) => c['id']).toList()}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  if (_topicChallenges.isNotEmpty) {
                                    print('Retrying with first challenge: ${_topicChallenges[0]['id']}');
                                    _challengeFuture = _loadChallenge(_topicChallenges[0]['id'] as String);
                                  } else if (widget.initialChallengeId != null) {
                                    print('Retrying with initial challenge: ${widget.initialChallengeId}');
                                    _challengeFuture = _loadChallenge(widget.initialChallengeId!);
                                  }
                                });
                              },
                              child: const Text('Retry'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Go Back'),
                            ),
                          ],
                        ),
                      );
                    }

                    final challenge = snapshot.data;
                    if (challenge == null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'No challenges found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Topic ID: ${widget.topicId}\n'
                              'Total challenges available: ${_topicChallenges.length}\n'
                              'Available Challenge IDs: ${_topicChallenges.map((c) => c['id']).toList()}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Go Back'),
                            ),
                          ],
                        ),
                      );
                    }

                    // Start animations when challenge loads
                    _fadeController.forward();
                    _slideController.forward();

                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        widget.topicId?.split('-').map((word) => 
                                          word[0].toUpperCase() + word.substring(1)).join(' ') ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Theme.of(context).primaryColor.withOpacity(0.2),
                                          ),
                                        ),
                                        child: Text(
                                          'Question ${_currentQuestionIndex + 1} of $_totalQuestions',
                                          style: TextStyle(
                                            color: Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: _currentQuestionIndex / _totalQuestions,
                                      minHeight: 8,
                                      backgroundColor: Colors.grey.withOpacity(0.2),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.topicId?.split('-').map((word) => 
                                        word[0].toUpperCase() + word.substring(1)).join(' ') ?? '',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Practice your ${widget.topicId?.split('-').first ?? ''} skills',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: (widget.topicColor ?? Colors.blue).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: (widget.topicColor ?? Colors.blue).withOpacity(0.3),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (widget.topicColor ?? Colors.blue).withOpacity(0.1),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: (widget.topicColor ?? Colors.blue).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.quiz,
                                                  color: widget.topicColor ?? Colors.blue,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Question:',
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: widget.topicColor ?? Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          TweenAnimationBuilder<double>(
                                            duration: const Duration(milliseconds: 800),
                                            tween: Tween(begin: 0.8, end: 1.0),
                                            curve: Curves.elasticOut,
                                            builder: (context, value, child) {
                                              return Transform.scale(
                                                scale: value,
                                                child: child,
                                              );
                                            },
                                            child: Text(
                                              challenge.question,
                                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_showHint) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.amber.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.lightbulb_outline, color: Colors.amber[700]),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                challenge.getHint(),
                                                style: TextStyle(color: Colors.amber[900]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),
                                    ...challenge.options.map((option) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        decoration: BoxDecoration(
                                          color: _getOptionColor(option, challenge).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _getOptionColor(option, challenge).withOpacity(0.3),
                                          ),
                                          boxShadow: [
                                            if (_hasSubmitted && ((option == _selectedAnswer && _isCorrect) || 
                                                (option == challenge.correctAnswer && _isCorrect)))
                                              BoxShadow(
                                                color: Colors.green.withOpacity(0.2),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            if (_hasSubmitted && option == _selectedAnswer && !_isCorrect)
                                              BoxShadow(
                                                color: Colors.red.withOpacity(0.2),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                          ],
                                        ),
                                        child: RadioListTile<String>(
                                          value: option,
                                          groupValue: _selectedAnswer,
                                          onChanged: _hasSubmitted ? null : (value) {
                                            setState(() {
                                              _selectedAnswer = value;
                                            });
                                            // Play select sound
                                            _playSound('select');
                                          },
                                          title: Text(
                                            option,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: _selectedAnswer == option ? 
                                                FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    )),
                                    const SizedBox(height: 24),
                                    if (_hasSubmitted) ...[
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: _isCorrect
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _isCorrect
                                                ? Colors.green.withOpacity(0.3)
                                                : Colors.red.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                ScaleTransition(
                                                  scale: _bounceAnimation,
                                                  child: Text(
                                                    _getFeedbackEmoji(),
                                                    style: const TextStyle(
                                                      fontSize: 28,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _getFeedbackText(),
                                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                      color: _isCorrect
                                                          ? Colors.green
                                                          : Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (_isCorrect && _currentQuestionIndex < _totalQuestions - 1) ...[
                                              const SizedBox(height: 16),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: LinearProgressIndicator(
                                                            value: _progressValue,
                                                            minHeight: 10,
                                                            backgroundColor: Colors.green.withOpacity(0.1),
                                                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Text(
                                                        '${(_progressValue * 100).toInt()}%',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (_showContinueButton) ...[
                                                    const SizedBox(height: 16),
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        onPressed: () => _continueToNext(challenge),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.green,
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.all(16),
                                                          elevation: 4,
                                                        ),
                                                        child: const Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Text('Continue to Next Challenge'),
                                                            SizedBox(width: 8),
                                                            Icon(Icons.arrow_forward),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                            if (!_isCorrect) ...[
                                              const SizedBox(height: 16),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      onPressed: _tryAgain,
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.red,
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.all(16),
                                                      ),
                                                      child: const Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(Icons.refresh),
                                                          SizedBox(width: 8),
                                                          Text('Try Again'),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      onPressed: () => _skipChallenge(challenge),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.grey,
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.all(16),
                                                      ),
                                                      child: const Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(Icons.skip_next),
                                                          SizedBox(width: 8),
                                                          Text('Skip'),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            if (_currentQuestionIndex >= _totalQuestions - 1 && _isCorrect) ...[
                                              const SizedBox(height: 16),
                                              Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.purple.withOpacity(0.3),
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.purple.withOpacity(0.2),
                                                      blurRadius: 10,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  children: [
                                                    const Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          '🎉 Topic Complete! 🎉',
                                                          style: TextStyle(
                                                            fontSize: 24,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.purple,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Total Score: $_score points',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.purple,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    const Text(
                                                      'Great job completing this topic! Keep practicing to master Japanese!',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.purple,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                      children: [
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            Navigator.pop(context);
                                                          },
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.blue,
                                                            foregroundColor: Colors.white,
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 24,
                                                              vertical: 12,
                                                            ),
                                                          ),
                                                          child: const Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(Icons.list),
                                                              SizedBox(width: 8),
                                                              Text('Topic List'),
                                                            ],
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            _showTopicCompletionDialog();
                                                          },
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.green,
                                                            foregroundColor: Colors.white,
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 24,
                                                              vertical: 12,
                                                            ),
                                                          ),
                                                          child: const Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text('View Summary'),
                                                              SizedBox(width: 8),
                                                              Icon(Icons.emoji_events),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _selectedAnswer == null
                                              ? null
                                              : () => _handleSubmit(challenge),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.all(16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text('Check Answer'),
                                              SizedBox(width: 8),
                                              Icon(Icons.check),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          // Animated score change overlay
          AnimatedBuilder(
            animation: _scoreAnimationController,
            builder: (context, child) {
              return Positioned(
                top: MediaQuery.of(context).size.height * 0.3 + _scoreSlideAnimation.value,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: _scoreOpacityAnimation.value,
                    child: Transform.scale(
                      scale: _scoreScaleAnimation.value,
                      child: Text(
                        _scoreChangeText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _scoreChangeColor,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: _scoreChangeColor.withOpacity(0.5),
                              offset: const Offset(0, 2),
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
        ],
      ),
    );
  }

  Color _getOptionColor(String option, Challenge challenge) {
    if (!_hasSubmitted) return Colors.grey;
    if (_selectedAnswer == option) {
      return _isCorrect ? Colors.green : Colors.red;
    }
    if (_hasSubmitted && _isCorrect && option == challenge.correctAnswer) return Colors.green;
    return Colors.grey;
  }

  // Helper method to get color from string
  static Color _getColorFromString(String colorString) {
    switch (colorString) {
      case 'blue':
        return Colors.blue;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'green':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
} 

