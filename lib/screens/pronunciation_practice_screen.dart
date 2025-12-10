import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:developer' as developer;

class PronunciationPracticeScreen extends StatefulWidget {
  final String japanese;
  final String romaji;
  final String english;

  const PronunciationPracticeScreen({
    super.key,
    required this.japanese,
    required this.romaji,
    required this.english,
  });

  @override
  State<PronunciationPracticeScreen> createState() => _PronunciationPracticeScreenState();
}

class _PronunciationPracticeScreenState extends State<PronunciationPracticeScreen> with SingleTickerProviderStateMixin {
  // Core services
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  late ConfettiController _confettiController;
  
  // State management
  bool _isListening = false;
  String _userSpeech = '';
  bool _isCorrect = false;
  bool _hasSpoken = false;
  double _confidence = 0.0;
  String _errorMessage = '';
  bool _isInitialized = false;
  bool _isSpeaking = false;
  
  // Animation and UI
  late AnimationController _waveController;
  late List<Animation<double>> _waveAnimations;
  final int _waveCount = 7;
  double _currentVolume = 0.0;
  
  // Timers and delays
  Timer? _voiceActivityTimer;
  Timer? _resetTimer;
  Timer? _speechTimeoutTimer;
  
  // Speech recognition state
  String _lastRecognizedWords = '';
  bool _speechRecognitionActive = false;
  
  // User preferences
  bool _useJapaneseMessages = true;
  
  // Progress tracking
  int _streak = 0;
  int _totalAttempts = 0;
  final double _minConfidenceForStreak = 0.7;
  
  // Constants for better timing
  static const Duration _speechTimeout = Duration(seconds: 15);
  static const Duration _voiceActivityDelay = Duration(milliseconds: 800);
  static const Duration _resetDelay = Duration(seconds: 3);
  static const Duration _ttsDelay = Duration(milliseconds: 200);

  // Enhanced message system
  final Map<String, Map<String, String>> _messages = {
    'listening': {
      'en': 'Listening...',
      'ja': '聞いています...',
    },
    'correct': {
      'en': 'Perfect!',
      'ja': '完璧です！',
    },
    'good': {
      'en': 'Good job!',
      'ja': 'よくできました！',
    },
    'fair': {
      'en': 'Keep practicing',
      'ja': 'もう少し練習しましょう',
    },
    'tryAgain': {
      'en': 'Please try again',
      'ja': 'もう一度お願いします',
    },
    'mismatch': {
      'en': 'That\'s not the correct phrase. Please try again with:',
      'ja': '正しいフレーズではありません。もう一度試してください：',
    },
    'wrongLanguage': {
      'en': 'Please speak in Japanese',
      'ja': '日本語で話してください',
    },
    'tryAgainButton': {
      'en': 'Try Again',
      'ja': 'もう一度',
    },
    'listenButton': {
      'en': 'Listen',
      'ja': '聞く',
    },
    'speakButton': {
      'en': 'Speak',
      'ja': '話す',
    },
    'stopButton': {
      'en': 'Stop Listening',
      'ja': '停止',
    },
    'userSpeech': {
      'en': 'Your pronunciation',
      'ja': 'あなたの発音',
    },
    'confidence': {
      'en': 'Confidence',
      'ja': '確信度',
    },
    'hint': {
      'en': 'Tap for pronunciation tips',
      'ja': '発音のヒントをタップ',
    },
    'streak': {
      'en': 'Streak',
      'ja': '連続正解',
    },
    'attempts': {
      'en': 'Attempts',
      'ja': '挑戦回数',
    },
    'tips': {
      'en': 'Tips',
      'ja': 'ヒント',
    },
    'speechRecognitionError': {
      'en': 'Speech recognition error occurred',
      'ja': '音声認識エラーが発生しました',
    },
    'speechRecognitionNotAvailable': {
      'en': 'Speech recognition not available. Please check your device settings and permissions.',
      'ja': '音声認識が利用できません。デバイスの設定と権限を確認してください。',
    },
    'initializationFailed': {
      'en': 'Failed to initialize speech recognition',
      'ja': '音声認識の初期化に失敗しました',
    },
    'networkError': {
      'en': 'Network error. Please check your connection.',
      'ja': 'ネットワークエラー。接続を確認してください。',
    },
    'permissionDenied': {
      'en': 'Microphone permission denied. Please enable it in settings.',
      'ja': 'マイクの権限が拒否されました。設定で有効にしてください。',
    },
    'retry': {
      'en': 'Retry',
      'ja': '再試行',
    },
    'error': {
      'en': 'Error',
      'ja': 'エラー',
    },
    'timeout': {
      'en': 'Listening timeout. Please try again.',
      'ja': '聞き取りタイムアウト。もう一度お試しください。',
    },
  };

  String _getMessage(String key) {
    return _messages[key]?[_useJapaneseMessages ? 'ja' : 'en'] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  @override
  void didUpdateWidget(PronunciationPracticeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if the practice item has changed
    if (oldWidget.japanese != widget.japanese ||
        oldWidget.romaji != widget.romaji ||
        oldWidget.english != widget.english) {
      
      _resetState();
    }
  }

  // Comprehensive initialization method
  Future<void> _initializeAll() async {
    try {
      // Initialize all objects fresh
      _initializeObjects();
      _setupWaveAnimation();
      
      // Initialize services in parallel
      await Future.wait([
        _initializeSpeech(),
        _initTts(),
      ]);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = '';
        });
      }
    } catch (e) {
      developer.log('Error during initialization: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '${_getMessage('initializationFailed')}: $e';
          _isInitialized = false;
        });
      }
    }
  }

  // Initialize core objects
  void _initializeObjects() {
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
  }

  // Setup wave animations
  void _setupWaveAnimation() {
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveAnimations = List.generate(_waveCount, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _waveController,
          curve: Interval(
            index * (1.0 / _waveCount),
            (index + 1) * (1.0 / _waveCount),
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
  }

  // Initialize speech recognition with better error handling
  Future<void> _initializeSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          developer.log('Speech recognition status: $status');
          _handleSpeechStatus(status);
        },
        onError: (error) {
          developer.log('Speech recognition error: $error');
          _handleSpeechError(error);
        },
      );
      
      if (!available) {
        throw Exception('Speech recognition not available');
      }

      if (mounted) {
        setState(() {
          _errorMessage = '';
        });
      }
    } catch (e) {
      developer.log('Error initializing speech recognition: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '${_getMessage('initializationFailed')}: $e';
        });
      }
      rethrow;
    }
  }

  // Handle speech recognition status changes
  void _handleSpeechStatus(String status) {
    if (!mounted) return;
    
    switch (status) {
      case 'done':
      case 'notListening':
        setState(() {
          _isListening = false;
          _isSpeaking = false;
          _speechRecognitionActive = false;
        });
        _stopWaveAnimation();
        if (_hasSpoken) {
          _checkPronunciation();
        }
        break;
      case 'error':
        setState(() {
          _errorMessage = _getMessage('speechRecognitionError');
          _isListening = false;
          _isSpeaking = false;
          _speechRecognitionActive = false;
        });
        _stopWaveAnimation();
        break;
      case 'listening':
        setState(() {
          _speechRecognitionActive = true;
        });
        break;
    }
  }

  // Handle speech recognition errors
  void _handleSpeechError(dynamic error) {
    if (!mounted) return;
    
    String errorMessage = '${_getMessage('error')}: $error';
    
    if (error.toString().contains('permission')) {
      errorMessage = _getMessage('permissionDenied');
    } else if (error.toString().contains('network') || error.toString().contains('connection')) {
      errorMessage = _getMessage('networkError');
    }
    
    setState(() {
      _errorMessage = errorMessage;
      _isListening = false;
      _isSpeaking = false;
      _speechRecognitionActive = false;
    });
    _stopWaveAnimation();
  }

  // Initialize TTS with better error handling
  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage(_useJapaneseMessages ? 'ja-JP' : 'en-US');
      await _flutterTts.setSpeechRate(0.4);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVoice({"name": "ja-JP-Standard-A", "locale": "ja-JP"});
      await _flutterTts.setQueueMode(1);
    } catch (e) {
      developer.log('Error initializing TTS: $e');
      // Don't throw here as TTS is not critical for core functionality
    }
  }

  // Update TTS language when user preference changes
  Future<void> _updateTtsLanguage() async {
    try {
      await _flutterTts.setLanguage(_useJapaneseMessages ? 'ja-JP' : 'en-US');
    } catch (e) {
      developer.log('Error updating TTS language: $e');
    }
  }

  // Enhanced voice activity management
  void _updateVoiceActivity(bool isSpeaking) {
    _voiceActivityTimer?.cancel();
    
    setState(() {
      _isSpeaking = isSpeaking;
      if (!isSpeaking) {
        _currentVolume = 0.0;
      }
    });

    if (isSpeaking) {
      _voiceActivityTimer = Timer(_voiceActivityDelay, () {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _currentVolume = 0.0;
          });
        }
      });
    }
  }

  // Enhanced listening method with better state management
  Future<void> _listen() async {
    if (!_isInitialized) {
      setState(() {
        _errorMessage = _getMessage('speechRecognitionNotAvailable');
      });
      return;
    }

    // Ensure clean state before starting
    await _stopListening();
    await Future.delayed(_ttsDelay);
    
    try {
      setState(() {
        _isListening = true;
        _errorMessage = '';
      });
      
      _startWaveAnimation();
      _startSpeechTimeout();
      
      await _speech.listen(
        onResult: (result) {
          _handleSpeechResult(result);
        },
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() {
              _currentVolume = level;
            });
          }
        },
        listenFor: _speechTimeout,
        pauseFor: const Duration(seconds: 3),
        localeId: 'ja_JP',
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (e) {
      developer.log('Error starting speech recognition: $e');
      _handleSpeechError(e);
    }
  }

  // Handle speech recognition results
  void _handleSpeechResult(dynamic result) {
    if (!mounted) return;
    
    developer.log('Speech recognition result: ${result.recognizedWords}');
    
    final isNewSpeech = result.recognizedWords != _lastRecognizedWords;
    _lastRecognizedWords = result.recognizedWords;
  
    if (result.recognizedWords.isNotEmpty) {
      setState(() {
        _userSpeech = result.recognizedWords;
        _hasSpoken = true;
      });
      
      // Validate language
      if (_isValidJapaneseSpeech(result.recognizedWords)) {
        setState(() {
          _confidence = result.confidence;
          _errorMessage = '';
        });
        
        if (isNewSpeech) {
          _updateVoiceActivity(true);
          _currentVolume = result.confidence;
        }
        
        // Stop listening if we have a good result
        if (result.finalResult || _confidence >= 0.8) {
          _stopListening();
          _checkPronunciation();
        }
      } else {
        setState(() {
          _confidence = 0.0;
          _errorMessage = _getMessage('wrongLanguage');
          _isCorrect = false;
        });
        _stopListening();
      }
    }
  }

  // Validate if speech contains Japanese characters
  bool _isValidJapaneseSpeech(String speech) {
    final containsJapanese = RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]').hasMatch(speech);
    final containsEnglish = RegExp(r'[a-zA-Z]').hasMatch(speech);
    
    return containsJapanese && !containsEnglish;
  }

  // Start speech timeout timer
  void _startSpeechTimeout() {
    _speechTimeoutTimer?.cancel();
    _speechTimeoutTimer = Timer(_speechTimeout, () {
      if (_isListening) {
        _stopListening();
        setState(() {
          _errorMessage = _getMessage('timeout');
        });
      }
    });
  }

  // Enhanced pronunciation checking
  void _checkPronunciation() {
    if (_userSpeech.isEmpty) {
      setState(() {
        _hasSpoken = false;
      });
      return;
    }

    // Calculate similarity score
    final similarityScore = _calculateSimilarityScore(_userSpeech, widget.japanese);
    
    // Determine if pronunciation is correct
    final isExactMatch = _userSpeech.trim().replaceAll(RegExp(r'\s+'), '') == 
                         widget.japanese.trim().replaceAll(RegExp(r'\s+'), '');
    final isCloseMatch = similarityScore >= 0.8;
    
    // Update confidence based on similarity
    if (isExactMatch) {
      _confidence = math.max(_confidence, 0.9);
    } else if (isCloseMatch) {
      _confidence = math.max(_confidence * similarityScore, 0.7);
    } else {
      _confidence = _confidence * similarityScore;
    }
    
    setState(() {
      _isCorrect = (isExactMatch || isCloseMatch) && _confidence >= 0.7;
      
      if (!isExactMatch && !isCloseMatch) {
        _errorMessage = '${_getMessage('mismatch')}\n${widget.japanese}';
      } else if (_confidence < 0.5) {
        _errorMessage = _getMessage('tryAgain');
      } else {
        _errorMessage = '';
      }
    });
    
    _updateStreak(_isCorrect);
    _playFeedbackSound();
    
    // Schedule reset after showing result
    _scheduleReset();
  }

  // Calculate similarity score between user speech and target
  double _calculateSimilarityScore(String userSpeech, String target) {
    final cleanUser = userSpeech.trim().replaceAll(RegExp(r'\s+'), '');
    final cleanTarget = target.trim().replaceAll(RegExp(r'\s+'), '');
    
    if (cleanUser.isEmpty || cleanTarget.isEmpty) return 0.0;
    
    List<String> userChars = cleanUser.split('');
    List<String> targetChars = cleanTarget.split('');
    
    int matches = 0;
    int partialMatches = 0;
    int totalChars = math.max(userChars.length, targetChars.length);
    
    for (int i = 0; i < math.min(userChars.length, targetChars.length); i++) {
      if (userChars[i] == targetChars[i]) {
        matches++;
      } else {
        // Check for partial matches (same character type)
        bool isHiragana = RegExp(r'[\u3040-\u309F]').hasMatch(userChars[i]);
        bool isKatakana = RegExp(r'[\u30A0-\u30FF]').hasMatch(userChars[i]);
        bool isKanji = RegExp(r'[\u4E00-\u9FAF]').hasMatch(userChars[i]);
        
        if ((isHiragana && RegExp(r'[\u3040-\u309F]').hasMatch(targetChars[i])) ||
            (isKatakana && RegExp(r'[\u30A0-\u30FF]').hasMatch(targetChars[i])) ||
            (isKanji && RegExp(r'[\u4E00-\u9FAF]').hasMatch(targetChars[i]))) {
          partialMatches++;
        }
      }
    }
    
    return (matches + (partialMatches * 0.5)) / totalChars;
  }

  // Play appropriate feedback sound
  Future<void> _playFeedbackSound() async {
    if (_isCorrect && _confidence >= 0.9) {
      _confettiController.play();
      await _playSuccessSound();
    } else if (_isCorrect && _confidence >= 0.7) {
      await _playSuccessSound();
    } else {
      await _playIncorrectSound();
    }
  }

  // Play success sound
  Future<void> _playSuccessSound() async {
    try {
      await _updateTtsLanguage();
      await _flutterTts.speak(_getMessage('correct'));
    } catch (e) {
      developer.log('Error playing success sound: $e');
    }
  }

  // Play incorrect sound
  Future<void> _playIncorrectSound() async {
    try {
      await _updateTtsLanguage();
      await _flutterTts.speak(_getMessage('tryAgain'));
    } catch (e) {
      developer.log('Error playing incorrect sound: $e');
    }
  }

  // Play correct pronunciation
  Future<void> _playCorrectPronunciation() async {
    try {
      await _flutterTts.stop();
      await Future.delayed(_ttsDelay);
      await _flutterTts.setLanguage('ja-JP');
      await _flutterTts.speak(widget.japanese);
      await _updateTtsLanguage();
    } catch (e) {
      developer.log('Error playing correct pronunciation: $e');
    }
  }

  // Retry pronunciation with fresh state
  Future<void> _retryPronunciation() async {
    _resetState();
    await Future.delayed(_ttsDelay);
    await _listen();
  }

  // Stop listening with proper cleanup
  Future<void> _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _isSpeaking = false;
        _currentVolume = 0.0;
        _speechRecognitionActive = false;
      });
      _stopWaveAnimation();
      _cancelTimers();
    }
  }

  // Start wave animation
  void _startWaveAnimation() {
    _waveController.repeat();
  }

  // Stop wave animation
  void _stopWaveAnimation() {
    _waveController.stop();
  }

  // Cancel all active timers
  void _cancelTimers() {
    _voiceActivityTimer?.cancel();
    _speechTimeoutTimer?.cancel();
    _resetTimer?.cancel();
  }

  // Schedule automatic reset
  void _scheduleReset() {
    _resetTimer?.cancel();
    _resetTimer = Timer(_resetDelay, () {
      if (mounted) {
        _resetState();
      }
    });
  }



  Widget _buildWaveAnimation() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_waveCount, (index) {
          return AnimatedBuilder(
            animation: _waveAnimations[index],
            builder: (context, child) {
              final waveValue = _waveAnimations[index].value;
              const baseHeight = 12.0;
              const maxWaveHeight = 32.0;
              final waveHeight = _isSpeaking 
                ? baseHeight + (waveValue * maxWaveHeight) * (0.3 + _currentVolume)
                : baseHeight;
              
              return Container(
                width: 4,
                height: waveHeight,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _isSpeaking 
                    ? Colors.blue.withAlpha(204) // 0.8 opacity
                    : Colors.blue.withAlpha(77),  // 0.3 opacity
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withAlpha(51), // 0.2 opacity
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildConfidenceIndicator() {
    if (_confidence <= 0) return const SizedBox.shrink();
    
    Color confidenceColor;
    IconData confidenceIcon;
    if (_confidence >= 0.9) {
      confidenceColor = Colors.green;
      confidenceIcon = Icons.check_circle;
    } else if (_confidence >= 0.7) {
      confidenceColor = Colors.blue;
      confidenceIcon = Icons.thumb_up;
    } else if (_confidence >= 0.5) {
      confidenceColor = Colors.orange;
      confidenceIcon = Icons.warning;
    } else {
      confidenceColor = Colors.red;
      confidenceIcon = Icons.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: confidenceColor.withAlpha(26), // 0.1 opacity
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: confidenceColor.withAlpha(77), // 0.3 opacity
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confidenceIcon,
            color: confidenceColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${_getMessage('confidence')}: ${(_confidence * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              color: confidenceColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _getFeedbackMessage() {
    if (_confidence >= 0.9) {
      return _getMessage('correct');
    } else if (_confidence >= 0.7) {
      return _getMessage('good');
    } else if (_confidence >= 0.5) {
      return _getMessage('fair');
    } else {
      return _getMessage('tryAgain');
    }
  }

  Color _getFeedbackColor() {
    if (_confidence >= 0.9) {
      return Colors.green;
    } else if (_confidence >= 0.7) {
      return Colors.blue;
    } else if (_confidence >= 0.5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  IconData _getFeedbackIcon() {
    if (_confidence >= 0.9) {
      return Icons.check_circle;
    } else if (_confidence >= 0.7) {
      return Icons.thumb_up;
    } else if (_confidence >= 0.5) {
      return Icons.warning;
    } else {
      return Icons.close;
    }
  }

  void _updateStreak(bool isCorrect) {
    setState(() {
      _totalAttempts++;
      if (isCorrect && _confidence >= _minConfidenceForStreak) {
        _streak++;
        if (_streak > 0 && _streak % 5 == 0) {
          _confettiController.play();
        }
      } else {
        _streak = 0;
      }
    });
  }

  // Add comprehensive state reset method
  void _resetState() {
    setState(() {
      _isListening = false;
      _userSpeech = '';
      _isCorrect = false;
      _hasSpoken = false;
      _confidence = 0.0;
      _errorMessage = '';
      _currentVolume = 0.0;
      _lastRecognizedWords = '';
      _isSpeaking = false;
      _speechRecognitionActive = false;
    });
    
    // Stop any ongoing processes
    _stopListening();
    _flutterTts.stop();
    
    // Reset animation controller
    _waveController.reset();
    
    // Cancel any active timers
    _cancelTimers();
  }

  // Add method to handle when user wants to start fresh
  void _startFresh() {
    _resetState();
  }

  Widget _buildStreakIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(26), // 0.1 opacity
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withAlpha(77), // 0.3 opacity
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: _streak > 0 ? Colors.orange : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            '$_streak',
            style: TextStyle(
              color: _streak > 0 ? Colors.orange : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final correctAttempts = (_totalAttempts * (_confidence >= _minConfidenceForStreak ? 1 : 0)).toInt();
    return Container(
      width: 120,
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _totalAttempts > 0 ? correctAttempts / _totalAttempts : 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$_totalAttempts',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final contentPadding = screenHeight * 0.02; // 2% of screen height

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pronunciation Practice',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _startFresh,
            tooltip: 'Start Fresh',
          ),
          IconButton(
            icon: Icon(_useJapaneseMessages ? Icons.language : Icons.translate, 
              size: 20,
            ),
            onPressed: () async {
              setState(() {
                _useJapaneseMessages = !_useJapaneseMessages;
              });
              await _updateTtsLanguage();
            },
            tooltip: _useJapaneseMessages ? 'Switch to English' : '日本語に切り替え',
          ),
          if (_isListening)
            IconButton(
              icon: const Icon(Icons.stop, 
                size: 20,
              ),
              onPressed: _stopListening,
              tooltip: _getMessage('stopButton'),
            ),
        ],
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue[700]!.withAlpha(13), // 0.05 opacity
                  Colors.blue[900]!.withAlpha(13), // 0.05 opacity
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: contentPadding),
            child: Column(
              children: [
                // Streak and Progress Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue[700]!.withAlpha(26), // 0.1 opacity
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStreakIndicator(),
                      const SizedBox(width: 12),
                      _buildProgressIndicator(),
                    ],
                  ),
                ),
                SizedBox(height: contentPadding),

                // Japanese Text Card
                Card(
                  elevation: 4,
                  shadowColor: Colors.blue[700]!.withAlpha(51), // 0.2 opacity
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.blue[50]!,
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.japanese,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue[100]!,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.romaji,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blue[800],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.english,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: contentPadding),

                // Listening Animation
                if (_isListening)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue[700]!.withAlpha(26), // 0.1 opacity
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mic, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _getMessage('listening'),
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: _buildWaveAnimation(),
                        ),
                      ],
                    ),
                  ),

                if (_hasSpoken) ...[
                  SizedBox(height: contentPadding),
                  // Feedback Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _getFeedbackColor().withAlpha(51), // 0.2 opacity
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.record_voice_over,
                              color: _getFeedbackColor(),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "${_getMessage('userSpeech')}: $_userSpeech",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildConfidenceIndicator(),
                        if (_errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage,
                            style: TextStyle(
                              color: _getFeedbackColor(),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: contentPadding),
                  
                  // Feedback Message
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _getFeedbackColor(),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _getFeedbackColor().withAlpha(77), // 0.3 opacity
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getFeedbackIcon(),
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getFeedbackMessage(),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (_confidence < 0.7 && !_isListening) ...[
                          const SizedBox(height: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            onPressed: _retryPronunciation,
                            tooltip: _getMessage('tryAgainButton'),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _getFeedbackColor(),
                              padding: const EdgeInsets.all(8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const Spacer(),
                
                // Control Buttons
                if (!_isListening)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.volume_up, size: 20),
                        label: Text(
                          _getMessage('listenButton'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _playCorrectPronunciation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.mic_none, size: 20),
                        label: Text(
                          _getMessage('speakButton'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _isInitialized ? _listen : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: contentPadding),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: -3.14 / 2,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            maxBlastForce: 100,
            minBlastForce: 80,
            gravity: 0.3,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Cancel any ongoing operations
    _speech.stop();
    _flutterTts.stop();
    _confettiController.dispose();
    _waveController.dispose();
    _voiceActivityTimer?.cancel();
    _resetTimer?.cancel();
    _speechTimeoutTimer?.cancel();
    super.dispose();
  }
}
