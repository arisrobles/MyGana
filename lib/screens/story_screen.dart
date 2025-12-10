import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/story_data.dart';
import '../data/dynamic_questions.dart';
import '../services/firebase_user_sync_service.dart';
import '../services/progress_service.dart';
import 'difficulty_selection_screen.dart';

enum CharacterPosition { left, center, right }

// NEW: Particle class for visual effects
class Particle {
  double x, y, vx, vy;
  int life;
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.color,
  });

  void update() {
    x += vx;
    y += vy;
    life--;
  }

  bool isDead() => life <= 0;
}

// NEW: Haptic feedback types
enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
}

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> with TickerProviderStateMixin {
  // Story progression state
  int _currentStoryIndex = 0;
  bool _showingQuestion = false;
  String? _selectedAnswer;
  bool _answerConfirmed = false; // NEW: Track if answer is confirmed for checking
  bool _showingFeedback = false;
  bool _isCorrect = false;
  bool _showingCompletionScreen = false;
  bool _showingFailureScreen = false;

  // Track incorrect attempts for current question
  // Remove `int _incorrectAttempts = 0;`
  // Remove `bool _showSkipOption = false;`

  // NEW: Lives system
  double _lives = 5.0; // Start with 5 full hearts
  static const double _maxLives = 5.0;
  static const double _livesLostPerWrongAnswer = 1.0; // Deduct 1 full life per wrong answer

  // Hint system for dynamic difficulty
  int _hintsUsedTotal = 0;

  // Dynamic difficulty system
  Difficulty _currentDifficulty = Difficulty.EASY;
  int _consecutiveCorrectAnswers = 0;
  int _currentInteractionIndex = 0;
  bool _isHoldingInteraction = false;

  // Dynamic question system methods
  void _updateQuestionForCurrentBeat() {
    if (_currentStoryIndex < _currentStoryBeats.length) {
      final currentBeat = _currentStoryBeats[_currentStoryIndex];
      if (currentBeat.question != null) {
        // Replace the question with a random one from the appropriate difficulty pool
        final newQuestion = getRandomQuestionForDifficulty(_currentDifficulty);
        
        // Create a new StoryBeat with the updated question
        final updatedBeat = StoryBeat(
          text: currentBeat.text,
          speaker: currentBeat.speaker,
          background: currentBeat.background,
          character: currentBeat.character,
          characterPosition: currentBeat.characterPosition,
          question: Question(
            text: newQuestion.text,
            options: newQuestion.options,
            correctAnswer: newQuestion.correctAnswer,
            customHint: newQuestion.customHint,
          ),
          harukiExpression: currentBeat.harukiExpression,
          soundFile: currentBeat.soundFile,
          bgmFile: currentBeat.bgmFile,
        );
        
        // Replace the current beat
        _currentStoryBeats[_currentStoryIndex] = updatedBeat;
      }
    }
  }

  // Scan forward to find the next question and randomize it
  void _scanAndRandomizeNextQuestion() {
    // Look ahead from current position to find the next question
    for (int i = _currentStoryIndex; i < _currentStoryBeats.length; i++) {
      final beat = _currentStoryBeats[i];
      if (beat.question != null) {
        // Found a question, randomize it
        final newQuestion = getRandomQuestionForDifficulty(_currentDifficulty);
        
        final updatedBeat = StoryBeat(
          text: beat.text,
          speaker: beat.speaker,
          background: beat.background,
          character: beat.character,
          characterPosition: beat.characterPosition,
          question: Question(
            text: newQuestion.text,
            options: newQuestion.options,
            correctAnswer: newQuestion.correctAnswer,
            customHint: newQuestion.customHint,
          ),
          harukiExpression: beat.harukiExpression,
          soundFile: beat.soundFile,
          bgmFile: beat.bgmFile,
        );
        
        _currentStoryBeats[i] = updatedBeat;
        break; // Only randomize the next question, then stop
      }
    }
  }

  void _handleCorrectAnswer() {
    _consecutiveCorrectAnswers++;
    
    // Progress difficulty based on consecutive correct answers
    if (_consecutiveCorrectAnswers == 1) {
      _currentDifficulty = Difficulty.NORMAL;
    } else if (_consecutiveCorrectAnswers >= 2) {
      _currentDifficulty = Difficulty.HARD;
    }
    
    // Move to next interaction
    _isHoldingInteraction = false;
    _currentInteractionIndex++;
  }

  void _handleIncorrectAnswer() {
    _consecutiveCorrectAnswers = 0;
    
    // Regress difficulty based on wrong answer
    if (_currentDifficulty == Difficulty.HARD) {
      _currentDifficulty = Difficulty.NORMAL;
    } else if (_currentDifficulty == Difficulty.NORMAL) {
      _currentDifficulty = Difficulty.EASY;
    }
    // If already at EASY, stay at EASY
    
    // Hold current interaction and change question
    _isHoldingInteraction = true;
    _updateQuestionForCurrentBeat();
  }

  // Animation controllers
  late AnimationController _characterAnimationController;
  late AnimationController _dialogAnimationController;
  late AnimationController _scoreAnimationController;
  late AnimationController _backgroundAnimationController;
  late AnimationController _completionAnimationController;
  late AnimationController _livesAnimationController; // NEW: For heart animations

  // Animations
  late Animation<double> _characterSlideAnimation;
  late Animation<double> _dialogFadeAnimation;
  late Animation<double> _scoreScaleAnimation;
  late Animation<double> _backgroundFadeAnimation;
  late Animation<double> _completionFadeAnimation;
  late Animation<double> _livesShakeAnimation; // NEW: For heart shake effect

  // Confetti controller for celebrations
  late ConfettiController _confettiController;
  late ConfettiController _completionConfettiController;

  // Controller for page transitions
  final PageController _pageController = PageController();

  // Story data based on difficulty
  late List<StoryBeat> _currentStoryBeats;

  // Audio players
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer(); // NEW: BGM player for interactions
  final AudioPlayer _transitionSoundPlayer = AudioPlayer();
  final AudioPlayer _correctSoundPlayer = AudioPlayer();
  final AudioPlayer _incorrectSoundPlayer = AudioPlayer();
  final AudioPlayer _victoryMusicPlayer = AudioPlayer();
  final AudioPlayer _heartLostSoundPlayer = AudioPlayer(); // NEW: Heart lost sound
  final AudioPlayer _characterSoundPlayer = AudioPlayer(); // NEW: Character voice sounds

  // Loading screen state
  bool _isLoading = true;
  int _currentInteraction = 1;
  bool _completedInteraction = false;

  // Player score tracking and achievements
  int _correctAnswers = 0;
  int _streak = 0;
  int _maxStreak = 0;
  bool _hasStartedQuestions = false;
  final List<String> _achievements = [];
  bool _showAchievement = false;
  String _currentAchievement = '';

  // UI enhancements
  bool _showHint = false;
  int _hintsUsedEasy = 0;
  int _hintsUsedNormal = 0;
  int _hintsUsedHard = 0;
  double _confidence = 0.0;

  // Game-like features
  int _totalScore = 0;
  int _experiencePoints = 0;
  String _playerRank = 'Novice';
  final List<String> _unlockedTitles = ['Kanji Seeker'];

  // New state for handling final question flow
  bool _hasAnsweredFinalQuestion = false;
  bool _finalQuestionProcessed = false;
  bool _showingFailureDialogue = false;

  // Add this with other state variables
  bool _showFloatingMessage = false;
  String _floatingMessage = '';
  late AnimationController _floatingMessageController;
  late Animation<double> _floatingMessageAnimation;
  
  // Track if this is a repeat playthrough (no rewards)
  bool _isRepeatPlaythrough = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _characterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _dialogAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scoreAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _backgroundAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _completionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // NEW: Lives animation controller
    _livesAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Add this in initState() with other animation controllers
    _floatingMessageController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _floatingMessageAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingMessageController,
      curve: Curves.elasticOut,
    ));

    // Initialize animations
    _characterSlideAnimation = Tween<double>(
      begin: -200.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _characterAnimationController,
      curve: Curves.elasticOut,
    ));

    _dialogFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dialogAnimationController,
      curve: Curves.easeInOut,
    ));

    _scoreScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _scoreAnimationController,
      curve: Curves.elasticOut,
    ));

    _backgroundFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundAnimationController,
      curve: Curves.easeInOut,
    ));

    _completionFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _completionAnimationController,
      curve: Curves.easeInOut,
    ));

    // NEW: Lives shake animation
    _livesShakeAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _livesAnimationController,
      curve: Curves.elasticOut,
    ));

    // Initialize confetti controllers
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _completionConfettiController = ConfettiController(duration: const Duration(seconds: 5));

    // Force landscape orientation and full-screen mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Hide system UI for full-screen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Check if this is a repeat playthrough (no rewards)
    _checkIfRepeatPlaythrough();
    
    // Set story beats based on difficulty
    _setStoryBeats();
    
    // Initialize first question with easy difficulty
    _scanAndRandomizeNextQuestion();

    // Initialize audio
    _initBackgroundMusic();
    _initSoundEffects();

    // Show initial loading screen
    _showLoadingScreen();

    // Start animations
    _backgroundAnimationController.forward();
  }

  @override
  void dispose() {
    // Restore system UI and orientations
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _characterAnimationController.dispose();
    _dialogAnimationController.dispose();
    _scoreAnimationController.dispose();
    _backgroundAnimationController.dispose();
    _completionAnimationController.dispose();
    _livesAnimationController.dispose(); // NEW
    _confettiController.dispose();
    _completionConfettiController.dispose();
    _pageController.dispose();
    _audioPlayer.dispose();
    _transitionSoundPlayer.dispose();
    _correctSoundPlayer.dispose();
    _incorrectSoundPlayer.dispose();
    _victoryMusicPlayer.dispose();
    _heartLostSoundPlayer.dispose();
    _characterSoundPlayer.dispose(); // NEW
    _bgmPlayer.dispose(); // NEW: BGM player
    // Add this in dispose()
    _floatingMessageController.dispose();
    super.dispose();
  }

  Future<void> _initSoundEffects() async {
    try {
      await _transitionSoundPlayer.setAsset('assets/sounds/bkpage.mp3');
      await _correctSoundPlayer.setAsset('assets/sounds/correct.mp3');
      await _incorrectSoundPlayer.setAsset('assets/sounds/incorrect.mp3');
      await _victoryMusicPlayer.setAsset('assets/sounds/victory.mp3');
      await _heartLostSoundPlayer.setAsset('assets/sounds/heart_lost.mp3'); // NEW

      await _transitionSoundPlayer.setVolume(0.7);
      await _correctSoundPlayer.setVolume(0.8);
      await _incorrectSoundPlayer.setVolume(0.6);
      await _victoryMusicPlayer.setVolume(0.9);
      await _heartLostSoundPlayer.setVolume(0.7); // NEW
      await _characterSoundPlayer.setVolume(0.8); // Character voice volume
    } catch (e) {
      print('Error initializing sound effects: $e');
    }
  }

  Future<void> _playCorrectSound() async {
    try {
      await _correctSoundPlayer.seek(Duration.zero);
      await _correctSoundPlayer.play();
    } catch (e) {
      print('Error playing correct sound: $e');
    }
  }

  Future<void> _playIncorrectSound() async {
    try {
      await _incorrectSoundPlayer.seek(Duration.zero);
      await _incorrectSoundPlayer.play();
    } catch (e) {
      print('Error playing incorrect sound: $e');
    }
  }

  // NEW: Play heart lost sound
  Future<void> _playHeartLostSound() async {
    try {
      await _heartLostSoundPlayer.seek(Duration.zero);
      await _heartLostSoundPlayer.play();
    } catch (e) {
      print('Error playing heart lost sound: $e');
    }
  }

  // NEW: Play character voice sound
  Future<void> _playCharacterSound(String soundFile) async {
    try {
      print('DEBUG: ===== CHARACTER SOUND DEBUG =====');
      print('DEBUG: Attempting to play: $soundFile');
      print('DEBUG: Character sound player state: ${_characterSoundPlayer.processingState}');
      
      // Stop any currently playing sound on this player
      await _characterSoundPlayer.stop();
      print('DEBUG: Stopped any existing character sound');
      
      // Set the asset
      await _characterSoundPlayer.setAsset(soundFile);
      print('DEBUG: Asset set successfully');
      
      // Set volume (lower so it doesn't overpower background music)
      await _characterSoundPlayer.setVolume(0.6);
      print('DEBUG: Volume set to 0.6 (layered with background music)');
      
      // Seek to start
      await _characterSoundPlayer.seek(Duration.zero);
      print('DEBUG: Seeked to start');
      
      // Play the sound
      await _characterSoundPlayer.play();
      print('DEBUG: Play command executed');
      
      // Listen to state changes
      _characterSoundPlayer.processingStateStream.listen((state) {
        print('DEBUG: Character sound state changed to: $state');
      });
      
      print('DEBUG: ===== END CHARACTER SOUND DEBUG =====');
    } catch (e) {
      print('ERROR: ===== CHARACTER SOUND ERROR =====');
      print('ERROR: Failed to play character sound: $e');
      print('ERROR: Sound file: $soundFile');
      print('ERROR: ===== END CHARACTER SOUND ERROR =====');
    }
  }

  // NEW: Stop character voice sound
  Future<void> _stopCharacterSound() async {
    try {
      print('DEBUG: Stopping character sound');
      await _characterSoundPlayer.stop();
      print('DEBUG: Character sound stopped');
    } catch (e) {
      print('ERROR: Error stopping character sound: $e');
    }
  }

  // NEW: Play BGM for interactions
  Future<void> _playBGM(String bgmFile) async {
    try {
      print('DEBUG: ===== BGM DEBUG =====');
      print('DEBUG: Attempting to play BGM: $bgmFile');
      print('DEBUG: BGM player state: ${_bgmPlayer.processingState}');
      
      // Stop any currently playing BGM on this player
      await _bgmPlayer.stop();
      print('DEBUG: Stopped any existing BGM');
      
      // Set the asset
      await _bgmPlayer.setAsset(bgmFile);
      print('DEBUG: BGM asset set successfully');
      
      // Set volume (lower so it doesn't overpower other sounds)
      await _bgmPlayer.setVolume(0.4);
      print('DEBUG: BGM volume set to 0.4');
      
      // Set loop mode for continuous playback
      await _bgmPlayer.setLoopMode(LoopMode.all);
      print('DEBUG: BGM loop mode set to all');
      
      // Play the BGM
      await _bgmPlayer.play();
      print('DEBUG: BGM playing successfully');
      print('DEBUG: ===== END BGM DEBUG =====');
    } catch (e) {
      print('ERROR: ===== BGM ERROR =====');
      print('ERROR: Failed to play BGM: $e');
      print('ERROR: BGM file: $bgmFile');
      print('ERROR: ===== END BGM ERROR =====');
    }
  }

  // NEW: Stop BGM
  Future<void> _stopBGM() async {
    try {
      print('DEBUG: Stopping BGM');
      await _bgmPlayer.stop();
      print('DEBUG: BGM stopped');
    } catch (e) {
      print('ERROR: Error stopping BGM: $e');
    }
  }

  Future<void> _playVictoryMusic() async {
    try {
      await _audioPlayer.stop();
      await _victoryMusicPlayer.seek(Duration.zero);
      await _victoryMusicPlayer.play();
    } catch (e) {
      print('Error playing victory music: $e');
    }
  }

  Future<void> _initBackgroundMusic() async {
    try {
      await _audioPlayer.setVolume(0.2);
      await _audioPlayer.setAsset('assets/sounds/bgmNew.mp3');
      await _audioPlayer.setLoopMode(LoopMode.all);
      await _audioPlayer.play();
    } catch (e) {
      print('Error initializing background music: $e');
    }
  }

  Future<void> _playTransitionSound() async {
    try {
      await _transitionSoundPlayer.seek(Duration.zero);
      await _transitionSoundPlayer.play();
    } catch (e) {
      print('Error playing transition sound: $e');
    }
  }

  // NEW: Lose lives and check for game over
  void _loseLives() {
    setState(() {
      _lives = (_lives - _livesLostPerWrongAnswer).clamp(0.0, _maxLives);
    });

    _playHeartLostSound();
    _livesAnimationController.forward().then((_) {
      _livesAnimationController.reverse();
    });

    // Check if player has run out of lives
    if (_lives <= 0) {
      _insertFailureDialogue();
      setState(() {
        _showingFeedback = false;
        _showingQuestion = false;
        _selectedAnswer = null;
        _answerConfirmed = false;
        _showHint = false;
        // Remove `_incorrectAttempts = 0;`
        // Remove `_showSkipOption = false;`
        _showingFailureDialogue = true;
        _currentStoryIndex++;
      });
      _dialogAnimationController.reset();
      _dialogAnimationController.forward();
    }
  }

  // NEW: Enhanced hearts display with better animations
  Widget _buildHeartsDisplay() {
    return AnimatedBuilder(
      animation: _livesShakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_livesShakeAnimation.value * (1 - (_livesAnimationController.value)), 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.black.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.red.withOpacity(0.8),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(5, (index) {
                  double heartValue = _lives - index;
                  if (heartValue >= 1.0) {
                    // Full heart with glow effect
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: Stack(
                        children: [
                          // Glow effect
                          Icon(
                            Icons.favorite,
                            color: Colors.red.withOpacity(0.3),
                            size: 24,
                          ),
                          // Main heart
                          const Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 20,
                          ),
                        ],
                      ),
                    );
                  } else if (heartValue >= 0.5) {
                    // Half heart
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: Stack(
                        children: [
                          const Icon(
                            Icons.favorite_border,
                            color: Colors.red,
                            size: 20,
                          ),
                          ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: 0.5,
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.red,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Empty heart
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: const Icon(
                        Icons.favorite_border,
                        color: Colors.grey,
                        size: 20,
                      ),
                    );
                  }
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // NEW: Simple hint counter display
  Widget _buildHintCounterDisplay() {
    final remainingHints = _getRemainingHintsForCurrentDifficulty();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.yellow.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.yellow.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lightbulb,
            color: remainingHints > 0 ? Colors.yellow : Colors.grey,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '$remainingHints',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: remainingHints > 0 ? Colors.white : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Enhanced streak display
  Widget _buildStreakDisplay() {
    if (_streak <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.9),
            Colors.red.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '$_streak',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _setStoryBeats() {
    // Use a single story flow - we'll use the normal story beats as the base
    _currentStoryBeats = List.from(normalStoryBeats);
  }

  // Check if this is a repeat playthrough (no rewards)
  Future<void> _checkIfRepeatPlaythrough() async {
    final isCompleted = await StoryCompletionTracker.isStoryCompleted();
    setState(() {
      _isRepeatPlaythrough = isCompleted;
    });
  }

  Future<void> _showLoadingScreen() async {
    setState(() {
      _isLoading = true;
    });

    _playTransitionSound();
    await Future.delayed(const Duration(seconds: 2));

    // Randomize the upcoming question after loading completes
    _scanAndRandomizeNextQuestion();

    setState(() {
      _isLoading = false;
    });

    // Start character animation when loading is complete
    _characterAnimationController.forward();
    _dialogAnimationController.forward();
  }

  void _calculateFinalScore() {
    // Base score calculation
    _totalScore = _correctAnswers * 100;

    // Dynamic difficulty multiplier based on highest difficulty reached
    // Calculate based on the difficulty progression achieved
    double difficultyMultiplier = 1.0;
    if (_consecutiveCorrectAnswers >= 2) {
      difficultyMultiplier = 2.0; // Reached HARD difficulty
    } else if (_consecutiveCorrectAnswers >= 1) {
      difficultyMultiplier = 1.5; // Reached NORMAL difficulty
    } else {
      difficultyMultiplier = 1.0; // Stayed at EASY difficulty
    }
    
    _totalScore = (_totalScore * difficultyMultiplier).round();

    // Bonus for streaks
    _totalScore += _maxStreak * 50;

    // Bonus for not using hints
    if (_getHintsUsedForCurrentDifficulty() == 0) {
      _totalScore += 500;
    }

    // NEW: Bonus for remaining lives
    _totalScore += (_lives * 100).round();

    // Calculate experience points
    _experiencePoints = _totalScore ~/ 10;

    // Determine rank based on performance
    if (_correctAnswers == 10 && _getHintsUsedForCurrentDifficulty() == 0 && _lives == _maxLives) {
      _playerRank = 'Kanji Master';
      _unlockedTitles.add('Perfect Scholar');
    } else if (_correctAnswers >= 8) {
      _playerRank = 'Kanji Expert';
      _unlockedTitles.add('Skilled Learner');
    } else if (_correctAnswers >= 6) {
      _playerRank = 'Kanji Apprentice';
    } else {
      _playerRank = 'Kanji Novice';
    }
  }

  // Save story score to local storage
  Future<void> _saveStoryScore() async {
    // Skip saving scores for repeat playthroughs
    if (_isRepeatPlaythrough) {
      print('Repeat playthrough detected - no rewards will be given');
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get current story total points
      final currentStoryPoints = prefs.getInt('story_total_points') ?? 0;

      // Add the current story score
      final newStoryPoints = currentStoryPoints + _totalScore;

      // Save back to SharedPreferences
      await prefs.setInt('story_total_points', newStoryPoints);

      // Also update total_points for Firebase sync
      final currentTotalPoints = prefs.getInt('total_points') ?? 0;
      final newTotalPoints = currentTotalPoints + _totalScore;
      await prefs.setInt('total_points', newTotalPoints);

      // Sync to Firebase
      final firebaseSync = FirebaseUserSyncService();
      await firebaseSync.syncMojiPoints(newTotalPoints);

      // Also save individual story session data for detailed tracking
      final storySessionKey = 'story_session_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(
          storySessionKey,
          {
            'difficulty': 'Dynamic',
            'score': _totalScore,
            'correctAnswers': _correctAnswers,
            'maxStreak': _maxStreak,
            'hintsUsed': _getHintsUsedForCurrentDifficulty(),
            'livesRemaining': _lives,
            'experiencePoints': _experiencePoints,
            'playerRank': _playerRank,
            'completedAt': DateTime.now().toIso8601String(),
          }.toString());

      // Update progress service for comprehensive tracking
      final progressService = ProgressService();
      await progressService.initialize();
      await progressService.updateStoryModeScore(
        score: _totalScore,
        correctAnswers: _correctAnswers,
        maxStreak: _maxStreak,
        hintsUsed: _getHintsUsedForCurrentDifficulty(),
        livesRemaining: _lives,
        difficulty: 'Dynamic',
        playerRank: _playerRank,
      );

      print('Story score saved: $_totalScore points (Total story points: $newStoryPoints)');
    } catch (e) {
      print('Error saving story score: $e');
    }
  }

  void _checkAchievements() {
    // Skip achievements for repeat playthroughs
    if (_isRepeatPlaythrough) {
      return;
    }
    
    List<String> newAchievements = [];

    if (_correctAnswers == 1 && !_achievements.contains('First Success')) {
      newAchievements.add('First Success');
    }

    if (_correctAnswers == 5 && !_achievements.contains('Halfway Hero')) {
      newAchievements.add('Halfway Hero');
    }

    if (_correctAnswers == 10 && !_achievements.contains('Perfect Score')) {
      newAchievements.add('Perfect Score');
    }

    if (_streak >= 3 && !_achievements.contains('Triple Threat')) {
      newAchievements.add('Triple Threat');
    }

    if (_streak >= 5 && !_achievements.contains('Unstoppable')) {
      newAchievements.add('Unstoppable');
    }

    if (_getHintsUsedForCurrentDifficulty() == 0 && _correctAnswers >= 5 && !_achievements.contains('No Help Needed')) {
      newAchievements.add('No Help Needed');
    }

    if (_correctAnswers >= 8 && !_achievements.contains('Speed Demon')) {
      newAchievements.add('Speed Demon');
    }

    // NEW: Lives-based achievements
    if (_lives == _maxLives &&
        _correctAnswers >= 7 &&
        !_achievements.contains('Flawless Victory')) {
      newAchievements.add('Flawless Victory');
    }

    if (_lives >= 4.0 && _correctAnswers >= 5 && !_achievements.contains('Heart Guardian')) {
      newAchievements.add('Heart Guardian');
    }

    for (String achievement in newAchievements) {
      _achievements.add(achievement);
      _showAchievementPopup(achievement);
    }
  }

  void _showAchievementPopup(String achievement) {
    setState(() {
      _showAchievement = true;
      _currentAchievement = achievement;
    });

    _confettiController.play();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showAchievement = false;
        });
      }
    });
  }


  bool _isEndOfInteraction() {
    if (_currentStoryIndex >= _currentStoryBeats.length - 1) return true;

    final StoryBeat currentBeat = _currentStoryBeats[_currentStoryIndex];
    final StoryBeat nextBeat = _currentStoryBeats[_currentStoryIndex + 1];

    if (currentBeat.question != null && _showingFeedback && _isCorrect) {
      return true;
    }

    if (currentBeat.background != nextBeat.background) {
      return true;
    }

    return false;
  }

  bool _isAtFinalStoryBeat() {
    return _currentStoryIndex == _currentStoryBeats.length - 1;
  }

  bool _isFinalQuestion() {
    final StoryBeat currentBeat = _currentStoryBeats[_currentStoryIndex];

    // Check if this is the Professor Hoshino question (the 10th question)
    if (currentBeat.question != null &&
        currentBeat.character != null &&
        currentBeat.character!.contains('Prof Hoshino')) {
      return true;
    }

    return false;
  }

  bool _isFailureDialogue() {
    final StoryBeat currentBeat = _currentStoryBeats[_currentStoryIndex];

    return currentBeat.speaker == 'Professor Hoshino' &&
        (currentBeat.text.contains('I\'m sorry, Haruki. You have run out of lives') ||
            currentBeat.text.contains('You haven\'t mastered enough Kanji')) &&
        currentBeat.character != null &&
        currentBeat.character!.contains('Prof Hoshino (Sad)');
  }

  void _insertFailureDialogue() {
    // Insert failure dialogue after the current position
    final failureDialogue = StoryBeat(
      speaker: 'Professor Hoshino',
      text:
          'I\'m sorry, Haruki. You have run out of lives and cannot continue your journey. Your heart was not strong enough to withstand the trials. You must start again to prove your determination.',
      background: 'Principal\'s Office (Inter10).png',
      character: 'Prof Hoshino (Sad).png',
      characterPosition: CharacterPosition.center,
      harukiExpression: 'Haruki (Sad).png',
      soundFile: 'assets/sounds/ProfHoshinoFail.mp3',
    );

    // Insert the failure dialogue right after the current position
    _currentStoryBeats.insert(_currentStoryIndex + 1, failureDialogue);
  }

  void _showCompletionScreen() {
    _calculateFinalScore();
    _saveStoryScore(); // Save the score to local storage
    _playVictoryMusic();
    // Only mark story as completed on first completion
    if (!_isRepeatPlaythrough) {
      StoryCompletionTracker.markStoryCompleted();
    }
    setState(() {
      _showingCompletionScreen = true;
    });
    _completionAnimationController.forward();
    _completionConfettiController.play();
  }

  void _showFailureScreen() {
    _calculateFinalScore();
    _saveStoryScore(); // Save the score to local storage even on failure
    setState(() {
      _showingFailureScreen = true;
    });
    _completionAnimationController.forward();
  }

  // Remove the `_skipQuestion()` method entirely.
  // void _skipQuestion() {
  //   setState(() {
  //     _showingFeedback = false;
  //     _showingQuestion = false;
  //     _selectedAnswer = null;
  //     _showSkipOption = false;
  //     _incorrectAttempts = 0;
  //     _streak = 0;
  //     _showHint = false;

  //     if (_currentStoryIndex < _currentStoryBeats.length - 1) {
  //       _currentStoryIndex++;
  //     }
  //   });

  //   bool endOfInteraction = _isEndOfInteraction();
  //   if (endOfInteraction) {
  //     _currentInteraction++;
  //     _showLoadingScreen();
  //     _characterAnimationController.reset();
  //     _dialogAnimationController.reset();
  //   } else {
  //     _dialogAnimationController.reset();
  //     _dialogAnimationController.forward();
  //   }
  // }

  void _nextStoryBeat() {
    if (_currentStoryIndex >= _currentStoryBeats.length) {
      return;
    }

    // Stop character sound when user taps to continue
    _stopCharacterSound();

    // Check if we're currently showing the failure dialogue
    if (_isFailureDialogue()) {
      // User tapped - now show failure screen
      _showFailureScreen();
      return;
    }

    if (_isAtFinalStoryBeat()) {
      // Check if player passed (7 or more correct answers) AND has lives remaining
      if (_correctAnswers >= 7 && _lives > 0) {
        _showCompletionScreen();
      } else {
        _showFailureScreen();
      }
      return;
    }

    final StoryBeat currentBeat = _currentStoryBeats[_currentStoryIndex];

    if (_showingFeedback) {
      if (!_isCorrect) {
        // Show floating message for wrong answer
        // _showFloatingFeedback('Not quite right. Try again!');

        // If lives are depleted, _loseLives already handled the failure flow
        if (_lives <= 0) {
          return;
        }

        // Reset for another attempt with new question
        setState(() {
          _showingFeedback = false;
          _selectedAnswer = null;
          _answerConfirmed = false;
          _streak = 0;
        });
        _dialogAnimationController.reset();
        _dialogAnimationController.forward();
        return;
      }

      // Handle final question logic
      if (_isFinalQuestion() && !_finalQuestionProcessed) {
        setState(() {
          _hasAnsweredFinalQuestion = true;
          _finalQuestionProcessed = true;
        });

        // Check if player passed (7 or more correct answers AND has lives)
        if (_correctAnswers >= 7 && _lives > 0) {
          // Player passed - proceed to success dialogue
          setState(() {
            _correctAnswers++;
            _streak++;
            _maxStreak = _maxStreak > _streak ? _maxStreak : _streak;
            _confidence = (_correctAnswers / 10.0).clamp(0.0, 1.0);
            _showingFeedback = false;
            _showingQuestion = false;
            _selectedAnswer = null;
            _answerConfirmed = false;
            _showHint = false;
            // Remove `_incorrectAttempts = 0;`
            // Remove `_showSkipOption = false;`
            _currentStoryIndex++;
          });
        } else {
          // Player failed - insert failure dialogue and proceed to it
          _insertFailureDialogue();
          setState(() {
            _showingFeedback = false;
            _showingQuestion = false;
            _selectedAnswer = null;
            _answerConfirmed = false;
            _showHint = false;
            // Remove `_incorrectAttempts = 0;`
            // Remove `_showSkipOption = false;`
            _showingFailureDialogue = true;
            _currentStoryIndex++;
          });
        }

        _scoreAnimationController.forward().then((_) {
          _scoreAnimationController.reverse();
        });

        _checkAchievements();
        _dialogAnimationController.reset();
        _dialogAnimationController.forward();
        return;
      }

      // Regular question handling (not final question)
      bool endOfInteraction = _isEndOfInteraction();

      setState(() {
        _correctAnswers++;
        _streak++;
        _maxStreak = _maxStreak > _streak ? _maxStreak : _streak;
        _confidence = (_correctAnswers / 10.0).clamp(0.0, 1.0);
        _showingFeedback = false;
        _showingQuestion = false;
        _selectedAnswer = null;
        _answerConfirmed = false;
        _completedInteraction = endOfInteraction;
        _showHint = false;
        // Remove `_incorrectAttempts = 0;`
        // Remove `_showSkipOption = false;`

        // Only progress if not holding interaction
        if (!_isHoldingInteraction && _currentStoryIndex < _currentStoryBeats.length - 1) {
          _currentStoryIndex++;
        }
      });

      _scoreAnimationController.forward().then((_) {
        _scoreAnimationController.reverse();
      });

      _checkAchievements();

      if (_completedInteraction) {
        _currentInteraction++;
        _showLoadingScreen();
        _characterAnimationController.reset();
        _dialogAnimationController.reset();
      } else {
        _dialogAnimationController.reset();
        _dialogAnimationController.forward();
      }

      return;
    }

    if (_showingQuestion) {
      // Answer checking is now handled in _checkAnswer() method
      // This prevents double-tap requirement
      return;
    }

    if (currentBeat.question != null) {
      setState(() {
        _showingQuestion = true;
        _hasStartedQuestions = true;
      });
      return;
    }

    // Handle dialogue progression
    bool endOfInteraction = _isEndOfInteraction();

    if (_currentStoryIndex < _currentStoryBeats.length - 1) {
      setState(() {
        _currentStoryIndex++;
        _completedInteraction = endOfInteraction;
      });


      if (_completedInteraction) {
        _currentInteraction++;
        _showLoadingScreen();
        _characterAnimationController.reset();
        _dialogAnimationController.reset();
      } else {
        _dialogAnimationController.reset();
        _dialogAnimationController.forward();
      }
    }
  }

  void _checkAnswer() {
    if (_selectedAnswer == null || !_answerConfirmed) return;
    
    final StoryBeat currentBeat = _currentStoryBeats[_currentStoryIndex];
    if (currentBeat.question == null) return;
    
    setState(() {
      _isCorrect = _selectedAnswer == currentBeat.question!.correctAnswer;
      _showingFeedback = true;
    });

    if (_isCorrect) {
      _playCorrectSound();
      _handleCorrectAnswer();
    } else {
      _playIncorrectSound();
      // Deduct lives immediately when answer is wrong
      _loseLives();
      _handleIncorrectAnswer();
    }
  }

  void _selectAnswer(String answer) {
    // Stop character sound when user selects an answer
    _stopCharacterSound();
    
    setState(() {
      _selectedAnswer = answer;
    });
  }

  void _showHintForQuestion() {
    setState(() {
      _showHint = true;
      _hintsUsedTotal++;
    });
  }

  String _getHintForCurrentQuestion() {
    final StoryBeat currentBeat = _currentStoryBeats[_currentStoryIndex];
    if (currentBeat.question == null) return '';
    
    // Use custom hint if available, otherwise fall back to generated hint
    if (currentBeat.question!.customHint != null && currentBeat.question!.customHint!.isNotEmpty) {
      return currentBeat.question!.customHint!;
    }
    
    // Fallback to generated hint (keeping the old logic as backup)
    final correctAnswer = currentBeat.question!.correctAnswer;
    final questionText = currentBeat.question!.text.toLowerCase();

    if (questionText.contains('mountain') || questionText.contains('山')) {
      return 'Think about the shape of a mountain peak...';
    }
    if (questionText.contains('water') || questionText.contains('水')) {
      return 'Imagine flowing water...';
    }
    if (questionText.contains('fire') || questionText.contains('火')) {
      return 'Picture flames dancing upward...';
    }
    if (questionText.contains('time') || questionText.contains('時')) {
      return 'Consider what measures the passage of moments...';
    }

    if (correctAnswer.contains('A.')) return 'The answer starts with the first option...';
    if (correctAnswer.contains('B.')) return 'Look at the second choice carefully...';
    if (correctAnswer.contains('C.')) return 'The third option might be correct...';
    if (correctAnswer.contains('D.')) return 'Consider the last option...';

    return 'Think about the context of the conversation...';
  }

  int _getHintsUsedForCurrentDifficulty() {
    // For dynamic difficulty, we'll use a single hint counter
    return _hintsUsedTotal;
  }

  int _getRemainingHintsForCurrentDifficulty() {
    return 3 - _getHintsUsedForCurrentDifficulty();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade900.withOpacity(0.3),
                  Colors.purple.shade900.withOpacity(0.3),
                  Colors.black,
                ],
              ),
            ),
          ),

          // Floating particles effect
          ...List.generate(20, (index) {
            return Positioned(
              left: (index * 37) % MediaQuery.of(context).size.width,
              top: (index * 73) % MediaQuery.of(context).size.height,
              child: AnimatedBuilder(
                animation: _backgroundAnimationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -_backgroundAnimationController.value * 100),
                    child: Container(
                      width: 2,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            );
          }),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Enhanced loading container
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Enhanced loading animation
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Rotating border
                            AnimatedBuilder(
                              animation: _backgroundAnimationController,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _backgroundAnimationController.value * 2 * 3.14159,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _getDifficultyColor(),
                                        width: 3,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Center content
                            Center(
                              child: Image.asset(
                                'assets/images/three_dots.gif',
                                height: 50,
                                errorBuilder: (context, error, stackTrace) {
                                  return CircularProgressIndicator(
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(_getDifficultyColor()),
                                    strokeWidth: 3,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Enhanced loading text
                      AnimatedTextKit(
                        animatedTexts: [
                          TypewriterAnimatedText(
                            'Loading Chapter $_currentInteraction...',
                            textStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontFamily: 'TheLastShuriken',
                              fontWeight: FontWeight.bold,
                            ),
                            speed: const Duration(milliseconds: 80),
                          ),
                        ],
                        isRepeatingAnimation: false,
                      ),

                      const SizedBox(height: 16),

                      // Difficulty indicator
                      // Container(
                      //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      //   decoration: BoxDecoration(
                      //     color: _getDifficultyColor().withOpacity(0.8),
                      //     borderRadius: BorderRadius.circular(20),
                      //     border: Border.all(
                      //       color: _getDifficultyColor(),
                      //       width: 2,
                      //     ),
                      //   ),
                      //   child: Text(
                      //     'Difficulty: ${widget.difficulty.toString().split('.').last}',
                      //     style: const TextStyle(
                      //       color: Colors.white,
                      //       fontSize: 14,
                      //       fontWeight: FontWeight.bold,
                      //     ),
                      //   ),
                      // ),

                      const SizedBox(height: 20),

                      // Progress dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          return AnimatedBuilder(
                            animation: _backgroundAnimationController,
                            builder: (context, child) {
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _backgroundAnimationController.value > (index + 1) / 3
                                      ? _getDifficultyColor()
                                      : Colors.white.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen() {
    return Scaffold(
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Background image - same as main game
                Image.asset(
                  'assets/images/backgrounds/Gate (Intro).png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(Icons.image_not_supported, color: Colors.white, size: 48),
                      ),
                    );
                  },
                ),
                
                // Content overlay with full background shadow
                FadeTransition(
                  opacity: _completionFadeAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = constraints.maxWidth;

                        return Column(
                          children: [
                            // BOTTOM SECTION - Content and Actions
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Journey Complete Title and Description - Centered
                                    Column(
                                      children: [
                                        Text(
                                          'Journey Complete',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.04,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontFamily: 'TheLastShuriken',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Congratulations! You have successfully completed your Kanji mastery journey.',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.025,
                                            color: Colors.white70,
                                            height: 1.4,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 24),
                                      ],
                                    ),
                                    
                                    // Action Buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Try Again Button
                                        // Container(
                                        //   margin: const EdgeInsets.only(right: 16),
                                        //   child: ElevatedButton(
                                        //     onPressed: () {
                                        //       // Set landscape orientation immediately
                                        //       SystemChrome.setPreferredOrientations([
                                        //         DeviceOrientation.landscapeLeft,
                                        //         DeviceOrientation.landscapeRight,
                                        //       ]);
                                              
                                        //       // Navigate to new story screen
                                        //       Navigator.of(context).pushReplacement(
                                        //         MaterialPageRoute(
                                        //           builder: (context) => const StoryScreen(),
                                        //         ),
                                        //       );
                                        //     },
                                        //     style: ElevatedButton.styleFrom(
                                        //       backgroundColor: Colors.green.shade600,
                                        //       foregroundColor: Colors.white,
                                        //       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        //       shape: RoundedRectangleBorder(
                                        //         borderRadius: BorderRadius.circular(8),
                                        //       ),
                                        //       elevation: 4,
                                        //     ),
                                        //     child: Text(
                                        //       'Try Again',
                                        //       style: TextStyle(
                                        //         fontSize: screenWidth * 0.025,
                                        //         fontWeight: FontWeight.bold,
                                        //         fontFamily: 'TheLastShuriken',
                                        //       ),
                                        //     ),
                                        //   ),
                                        // ),
                                        // Home Button
                                        ElevatedButton(
                                          onPressed: () {
                                            SystemChrome.setPreferredOrientations([
                                              DeviceOrientation.portraitUp,
                                              DeviceOrientation.portraitDown,
                                              DeviceOrientation.landscapeLeft,
                                              DeviceOrientation.landscapeRight,
                                            ]).then((_) {
                                              if (mounted) {
                                                Navigator.of(context).pop();
                                              }
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            elevation: 4,
                                          ),
                                          child: Text(
                                            'Home',
                                            style: TextStyle(
                                              fontSize: screenWidth * 0.025,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'TheLastShuriken',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

// Helper method for compact stat display

  Widget _buildFailureScreen() {
    return Scaffold(
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Background image - same as main game
                Image.asset(
                  'assets/images/backgrounds/Gate (Intro).png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(Icons.image_not_supported, color: Colors.white, size: 48),
                      ),
                    );
                  },
                ),
                
                // Content overlay with full background shadow
                FadeTransition(
                  opacity: _completionFadeAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = constraints.maxWidth;

                        return Column(
                          children: [
                            // BOTTOM SECTION - Content and Actions
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Journey Failed Title and Description - Centered
                                    Column(
                                      children: [
                                        Text(
                                          'Journey Failed',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.04,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontFamily: 'TheLastShuriken',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Your Kanji mastery wasn\'t strong enough to complete the trials.',
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.025,
                                            color: Colors.white70,
                                            height: 1.4,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 24),
                                      ],
                                    ),
                                  // Journey Progress
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(6),
                                    // decoration: BoxDecoration(
                                    //   color: Colors.red.withOpacity(0.2),
                                    //   borderRadius: BorderRadius.circular(15),
                                    //   border: Border.all(
                                    //     color: Colors.red.withOpacity(0.5),
                                    //     width: 2,
                                    //   ),
                                    // ),
                                    // child: Column(
                                    //   children: [
                                    //     Row(
                                    //       mainAxisAlignment: MainAxisAlignment.center,
                                    //       children: [
                                    //         Icon(
                                    //           Icons.flag,
                                    //           color: Colors.red.shade300,
                                    //           size: screenWidth * 0.04,
                                    //         ),
                                    //         const SizedBox(width: 8),
                                    //         Text(
                                    //           'Journey Failed',
                                    //           style: TextStyle(
                                    //             fontSize: screenWidth * 0.035,
                                    //             fontWeight: FontWeight.bold,
                                    //             color: Colors.white,
                                    //           ),
                                    //         ),
                                    //       ],
                                    //     ),
                                    //     const SizedBox(height: 2),
                                    //     Text(
                                    //       'Your Kanji mastery wasn\'t strong enough to complete the trials.',
                                    //       style: TextStyle(
                                    //         fontSize: screenWidth * 0.025,
                                    //         color: Colors.white70,
                                    //         height: 1.4,
                                    //       ),
                                    //       textAlign: TextAlign.center,
                                    //     ),
                                    //   ],
                                    // ),
                                  ),
                                  

                                  
                                    // Action Buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Try Again Button
                                        // Container(
                                        //   margin: const EdgeInsets.only(right: 16),
                                        //   child: ElevatedButton(
                                        //     onPressed: () {
                                        //       // Set landscape orientation immediately
                                        //       SystemChrome.setPreferredOrientations([
                                        //         DeviceOrientation.landscapeLeft,
                                        //         DeviceOrientation.landscapeRight,
                                        //       ]);
                                              
                                        //       // Navigate to new story screen
                                        //       Navigator.of(context).pushReplacement(
                                        //         MaterialPageRoute(
                                        //           builder: (context) => const StoryScreen(),
                                        //         ),
                                        //       );
                                        //     },
                                        //     style: ElevatedButton.styleFrom(
                                        //       backgroundColor: Colors.red.shade600,
                                        //       foregroundColor: Colors.white,
                                        //       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        //       shape: RoundedRectangleBorder(
                                        //         borderRadius: BorderRadius.circular(8),
                                        //       ),
                                        //       elevation: 4,
                                        //     ),
                                        //     child: Text(
                                        //       'Try Again',
                                        //       style: TextStyle(
                                        //         fontSize: screenWidth * 0.025,
                                        //         fontWeight: FontWeight.bold,
                                        //         fontFamily: 'TheLastShuriken',
                                        //       ),
                                        //     ),
                                        //   ),
                                        // ),
                                        // Home Button
                                        ElevatedButton(
                                          onPressed: () {
                                            SystemChrome.setPreferredOrientations([
                                              DeviceOrientation.portraitUp,
                                              DeviceOrientation.portraitDown,
                                              DeviceOrientation.landscapeLeft,
                                              DeviceOrientation.landscapeRight,
                                            ]).then((_) {
                                              if (mounted) {
                                                Navigator.of(context).pop();
                                              }
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            elevation: 4,
                                          ),
                                          child: Text(
                                            'Home',
                                            style: TextStyle(
                                              fontSize: screenWidth * 0.025,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'TheLastShuriken',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              ],
            );
          },
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_showingCompletionScreen) {
      return _buildCompletionScreen();
    }

    if (_showingFailureScreen) {
      return _buildFailureScreen();
    }

    if (_currentStoryIndex >= _currentStoryBeats.length) {
      _currentStoryIndex = _currentStoryBeats.length - 1;
    }

    if (_isLoading) {
      return _buildLoadingScreen();
    }

    final StoryBeat currentBeat = _currentStoryBeats[_currentStoryIndex];

    return Scaffold(
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return GestureDetector(
              onTap: _showingQuestion && (_selectedAnswer == null || !_answerConfirmed) ? null : _nextStoryBeat,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Animated background
                  FadeTransition(
                    opacity: _backgroundFadeAnimation,
                    child: Image.asset(
                      'assets/images/backgrounds/${currentBeat.background}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(Icons.image_not_supported, color: Colors.white, size: 48),
                          ),
                        );
                      },
                    ),
                  ),

                  // TOP SECTION - UI Controls
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          // Story title and difficulty
                          if (_currentStoryIndex == 0)
                            Column(
                              children: [
                                AnimatedTextKit(
                                  animatedTexts: [
                                    TypewriterAnimatedText(
                                      'Journey of the Kanji Seeker',
                                      textStyle: TextStyle(
                                        fontSize: MediaQuery.of(context).size.width * 0.04,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'TheLastShuriken',
                                      ),
                                      speed: const Duration(milliseconds: 100),
                                    ),
                                  ],
                                  isRepeatingAnimation: false,
                                ),
                                const SizedBox(height: 8),
                                // Container(
                                //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                //   decoration: BoxDecoration(
                                //     color: _getDifficultyColor().withOpacity(0.8),
                                //     borderRadius: BorderRadius.circular(20),
                                //     border: Border.all(
                                //       color: _getDifficultyColor(),
                                //       width: 2,
                                //     ),
                                //   ),
                                //   // child: Text(
                                //   //   'Difficulty: ${_currentDifficulty.toString().split('.').last}',
                                //   //   style: TextStyle(
                                //   //     fontSize: MediaQuery.of(context).size.width * 0.015,
                                //   //     color: Colors.white,
                                //   //     fontWeight: FontWeight.bold,
                                //   //   ),
                                //   // ),
                                // ),
                                const SizedBox(height: 16),
                              ],
                            ),

                          // Enhanced lives and scoring display - Moved higher and simplified
                          if (_hasStartedQuestions)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Lives display
                                  _buildHeartsDisplay(),

                                  // Score display
                                  AnimatedBuilder(
                                    animation: _scoreScaleAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _scoreScaleAnimation.value,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                _getDifficultyColor().withOpacity(0.9),
                                                _getDifficultyColor().withOpacity(0.7),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(15),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.7),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.4),
                                                blurRadius: 10,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    color: Colors.yellow,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$_correctAnswers/10',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // Enhanced streak display
                                              if (_streak > 1) ...[
                                                const SizedBox(height: 4),
                                                _buildStreakDisplay(),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 12),

                          // Action prompts
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showingQuestion
                                        ? (_showingFeedback
                                            ? (_isCorrect
                                                ? Icons.check_circle_outline
                                                : Icons.cancel)
                                            : _selectedAnswer == null
                                                ? Icons.help_outline
                                                : Icons.check_circle_outline)
                                        : (_isAtFinalStoryBeat() || _isFailureDialogue()
                                            ? Icons.flag
                                            : Icons.touch_app),
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _showingQuestion
                                        ? (_showingFeedback
                                            ? (_isCorrect ? 'Tap to continue' : 'Try again')
                                            : _selectedAnswer == null
                                                ? 'Select an answer'
                                                : 'Tap to check your answer')
                                        : (_isAtFinalStoryBeat() || _isFailureDialogue()
                                            ? 'Complete Journey'
                                            : 'Tap to continue'),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
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

                  // Animated Haruki character
                  AnimatedBuilder(
                    animation: _characterSlideAnimation,
                    builder: (context, child) {
                      return Positioned(
                        bottom: 0,
                        left: _characterSlideAnimation.value,
                        child: Image.asset(
                          'assets/images/characters/${currentBeat.harukiExpression}',
                          height: MediaQuery.of(context).size.height * 0.9,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 350,
                              width: 175,
                              color: Colors.transparent,
                            );
                          },
                        ),
                      );
                    },
                  ),

                  // Other character
                  if (currentBeat.character != null)
                    AnimatedBuilder(
                      animation: _characterAnimationController,
                      builder: (context, child) {
                        return Positioned(
                          bottom: 0,
                          right: _characterSlideAnimation.value.abs(),
                          child: Transform.scale(
                            scale: _characterAnimationController.value,
                            child: Image.asset(
                              'assets/images/characters/${currentBeat.character}',
                              height: MediaQuery.of(context).size.height * 0.9,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 350,
                                  width: 175,
                                  color: Colors.transparent,
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),

                  // BOTTOM SECTION - Dialog content
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: FadeTransition(
                      opacity: _dialogFadeAnimation,
                      child: Container(
                        margin: EdgeInsets.only(
                          top: MediaQuery.of(context).size.height * 0.25,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                        child: _showingQuestion
                            ? _buildEnhancedQuestionView(currentBeat.question!)
                            : _buildEnhancedDialogView(currentBeat),
                      ),
                    ),
                  ),

                  // Achievement popup
                  if (_showAchievement)
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.3,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 50),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.yellow.withOpacity(0.9),
                                Colors.orange.withOpacity(0.9),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.emoji_events,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Achievement Unlocked!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _currentAchievement,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Add this as a new Positioned widget in the Stack (after the achievement popup):
                  if (_showFloatingMessage)
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _floatingMessageAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _floatingMessageAnimation.value,
                              child: Transform.translate(
                                offset: Offset(0, -20 * _floatingMessageAnimation.value),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 50),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.red.withOpacity(0.9),
                                        Colors.orange.withOpacity(0.9),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.favorite_border,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _floatingMessage,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
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

                  // Confetti animations
                  Positioned(
                    top: 0,
                    left: MediaQuery.of(context).size.width / 2,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirection: 1.5708,
                      emissionFrequency: 0.05,
                      numberOfParticles: 20,
                      gravity: 0.1,
                    ),
                  ),

                  // Completion confetti
                  Positioned(
                    top: 0,
                    left: MediaQuery.of(context).size.width / 4,
                    child: ConfettiWidget(
                      confettiController: _completionConfettiController,
                      blastDirection: 1.5708,
                      emissionFrequency: 0.02,
                      numberOfParticles: 50,
                      gravity: 0.05,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: MediaQuery.of(context).size.width / 4,
                    child: ConfettiWidget(
                      confettiController: _completionConfettiController,
                      blastDirection: 1.5708,
                      emissionFrequency: 0.02,
                      numberOfParticles: 50,
                      gravity: 0.05,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getDifficultyColor() {
    switch (_currentDifficulty) {
      case Difficulty.EASY:
        return Colors.amber.shade300; // Light, warm yellow
      case Difficulty.NORMAL:
        return Colors.lightBlue.shade300; // Soft, pleasant blue
      case Difficulty.HARD:
        return Colors.pink.shade300; // Gentle pink instead of harsh red
    }
  }

  Widget _buildEnhancedDialogView(StoryBeat beat) {
    // Play character sound immediately when dialog appears (text animation starts)
    if (beat.soundFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playCharacterSound(beat.soundFile!);
      });
    }
    
    // Play BGM immediately when dialog appears (text animation starts)
    if (beat.bgmFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playBGM(beat.bgmFile!);
      });
    } else {
      // Stop BGM if this beat doesn't have bgmFile
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _stopBGM();
      });
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (beat.speaker != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getDifficultyColor().withOpacity(0.8),
                  _getDifficultyColor().withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
            child: Text(
              beat.speaker!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: "TheLastShuriken",
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: AnimatedTextKit(
            key: ValueKey(_currentStoryIndex),
            animatedTexts: [
              TypewriterAnimatedText(
                beat.text,
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
                speed: const Duration(milliseconds: 50),
              ),
            ],
            isRepeatingAnimation: false,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedQuestionView(Question question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Enhanced question header with better styling
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getDifficultyColor().withOpacity(0.9),
                _getDifficultyColor().withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
            boxShadow: [
              BoxShadow(
                color: _getDifficultyColor().withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.quiz,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
              // Enhanced hint button with counter
              if (!_showHint && _getRemainingHintsForCurrentDifficulty() > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHintCounterDisplay(),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.yellow.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.yellow.withOpacity(0.6), width: 2),
                      ),
                      child: IconButton(
                        onPressed: () {
                          _showHintForQuestion();
                          // Add haptic feedback
                          HapticFeedback.lightImpact();
                        },
                        icon: const Icon(
                          Icons.lightbulb,
                          color: Colors.yellow,
                          size: 18,
                        ),
                        tooltip: 'Get a hint (${_getRemainingHintsForCurrentDifficulty()} remaining)',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Enhanced hint display
        if (_showHint)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.yellow.withOpacity(0.3),
                  Colors.orange.withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.yellow.withOpacity(0.7), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lightbulb,
                    color: Colors.yellow.shade800,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getHintForCurrentQuestion(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Enhanced feedback display
        if (_showingFeedback && _isCorrect)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.9),
                  Colors.green.shade600.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.green, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Excellent! You got it right! 🎉',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          // Enhanced answer options with original Wrap layout
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: question.options.map((option) {
              final bool isSelected = _selectedAnswer == option;
              return InkWell(
                onTap: () {
                  _selectAnswer(option);
                  // Add haptic feedback
                  HapticFeedback.selectionClick();
                  
                  // Reset confirmation state when selecting new answer
                  setState(() {
                    _answerConfirmed = false;
                  });
                },
                borderRadius: BorderRadius.circular(15),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              _getDifficultyColor(),
                              _getDifficultyColor().withOpacity(0.7),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.1),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _getDifficultyColor().withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Enhanced radio button
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.white : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.black,
                                size: 12,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        option,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

        // Confirm button - only show when answer is selected but not confirmed
        if (_selectedAnswer != null && !_answerConfirmed)
          Container(
            margin: const EdgeInsets.only(top: 16),
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _answerConfirmed = true;
                  });
                  _checkAnswer();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getDifficultyColor(),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Confirm Answer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

