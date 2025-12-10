import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nihongo_japanese_app/models/japanese_character.dart';
import 'package:nihongo_japanese_app/models/user_progress.dart';
import 'package:nihongo_japanese_app/services/challenge_progress_service.dart';
import 'package:nihongo_japanese_app/services/coin_service.dart';
import 'package:nihongo_japanese_app/services/database_service.dart';
import 'package:nihongo_japanese_app/services/firebase_user_sync_service.dart';
import 'package:nihongo_japanese_app/services/profile_image_service.dart';
import 'package:nihongo_japanese_app/services/progress_service.dart';
import 'package:nihongo_japanese_app/widgets/character_drawing_board.dart';
import 'package:nihongo_japanese_app/widgets/character_stroke_animation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PracticeWritingScreen extends StatefulWidget {
  const PracticeWritingScreen({super.key});

  @override
  State<PracticeWritingScreen> createState() => _PracticeWritingScreenState();
}

class _PracticeWritingScreenState extends State<PracticeWritingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<JapaneseCharacter> _hiraganaList;
  late List<JapaneseCharacter> _katakanaList;
  JapaneseCharacter? _selectedCharacter;
  bool _showAnimation = true;
  bool _showDrawingBoard = false;
  bool _expandedDrawingMode = false;
  bool _isLoading = true;

  // Remember user preference for expanded mode
  bool _userPrefersExpandedMode = true;

  // Progress tracking
  final ProgressService _progressService = ProgressService();
  Map<String, CharacterProgress> _characterProgress = {};

  // Confetti controller for celebrations
  late ConfettiController _confettiController;

  // Practice settings
  bool _showStrokeOrder = true;
  bool _showHints = true;
  bool _enableRecognition = true;
  bool _enableRealTimeRecognition = true;
  // Marks per character (Goods/Excellent)
  final Map<String, String> _characterMarks = {};
  StreamSubscription<Map<String, dynamic>>? _marksSubscription;
  StreamSubscription<User?>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _hiraganaList = [];
    _katakanaList = [];
    _loadCharacters();

    // Initialize confetti controller
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    // Listen for tab changes
    _tabController.addListener(_updateSelectedCharacter);

    // Load progress data
    _loadProgressData();

    // Load user preferences
    _loadUserPreferences();

    // Initial fetch of persisted marks from Firebase
    _refreshMarksFromFirebase();
    // Subscribe to real-time updates of marks
    _marksSubscription = FirebaseUserSyncService().watchCharacterMarks().listen((marks) {
      if (!mounted) return;
      setState(() {
        _characterMarks.clear();
        marks.forEach((key, value) {
          final map = Map<String, dynamic>.from(value as Map);
          final mark = (map['mark'] ?? '').toString();
          if (mark == 'goods' || mark == 'excellent') {
            _characterMarks[key] = mark == 'excellent' ? 'Excellent' : 'Goods';
          }
        });
      });
    });

    // Listen for auth state changes
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        // Reset ALL services for new user
        _progressService.reset();
        ChallengeProgressService().reset();
        CoinService().reset();
        ProfileImageService().reset();
        // Refresh Firebase listeners for the new user
        FirebaseUserSyncService().refreshListeners();
        // Refresh marks when auth state changes
        _refreshMarksFromFirebase();
        // Reload progress data
        _loadProgressData();
      }
    });
  }

  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userPrefersExpandedMode = prefs.getBool('expandedDrawingMode') ?? true;
      });
    } catch (e) {
      developer.log('Error loading preferences: $e');
      // Default to true if there's an error
      _userPrefersExpandedMode = true;
    }
  }

  Future<void> _saveUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('expandedDrawingMode', _userPrefersExpandedMode);
    } catch (e) {
      developer.log('Error saving preferences: $e');
    }
  }

  Future<void> _loadCharacters() async {
    setState(() {
      _isLoading = true;
    });

    final databaseService = DatabaseService();

    try {
      final hiragana = await databaseService.getHiragana();
      final katakana = await databaseService.getKatakana();

      developer.log('Loaded ${hiragana.length} hiragana characters');
      developer.log('Loaded ${katakana.length} katakana characters');

      if (hiragana.isNotEmpty) {
        developer.log(
            'First hiragana character: ${hiragana.first.character}, has SVG file: ${hiragana.first.svgFilename != null}');
        if (hiragana.first.svgFilename != null) {
          developer.log('SVG filename: ${hiragana.first.svgFilename}');
        }
      }

      setState(() {
        _hiraganaList = hiragana;
        _katakanaList = katakana;

        // Select the first character if available
        if (_hiraganaList.isNotEmpty) {
          _selectedCharacter = _hiraganaList.first;
          developer.log(
              'Selected first character: ${_selectedCharacter!.character}, has SVG file: ${_selectedCharacter!.svgFilename != null}');
        }

        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error loading characters: $e', error: e, stackTrace: StackTrace.current);
      setState(() {
        _isLoading = false;
      });

      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load characters: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadProgressData() async {
    await _progressService.initialize();

    setState(() {
      // Get character progress
      _characterProgress = _progressService.getUserProgress().characterProgress;
    });
  }

  void _updateSelectedCharacter() {
    if (!mounted) return;

    // When tab changes, select the first character of that type
    setState(() {
      switch (_tabController.index) {
        case 0:
          _selectedCharacter = _hiraganaList.first;
          break;
        case 1:
          _selectedCharacter = _katakanaList.first;
          break;
      }

      _showAnimation = true;
      _showDrawingBoard = false;
      // Keep the user's preference for expanded mode
      // _expandedDrawingMode will be set when toggling to drawing board
    });
  }

  @override
  void dispose() {
    _marksSubscription?.cancel();
    _authStateSubscription?.cancel();
    _tabController.removeListener(_updateSelectedCharacter);
    _tabController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _selectCharacter(JapaneseCharacter character) {
    developer.log(
        'Selecting character: "${character.character}" (length: ${character.character.length})');
    developer.log('Character code units: ${character.character.codeUnits}');
    setState(() {
      _selectedCharacter = character;
      _showAnimation = true;
      _showDrawingBoard = false;
      // Don't change _expandedDrawingMode here
    });
  }

  void _toggleDrawingBoard() {
    setState(() {
      _showDrawingBoard = !_showDrawingBoard;
      _showAnimation = !_showDrawingBoard;

      // When showing drawing board, use the user's preference for expanded mode
      if (_showDrawingBoard) {
        _expandedDrawingMode = _userPrefersExpandedMode;
      }
      // When hiding drawing board, don't change _expandedDrawingMode
    });
  }

  Future<void> _refreshMarksFromFirebase() async {
    try {
      final marks = await FirebaseUserSyncService().fetchCharacterMarks();
      setState(() {
        _characterMarks.clear();
        marks.forEach((key, value) {
          final map = Map<String, dynamic>.from(value as Map);
          final mark = (map['mark'] ?? '').toString();
          if (mark == 'goods' || mark == 'excellent') {
            _characterMarks[key] = mark == 'excellent' ? 'Excellent' : 'Goods';
          }
        });
      });
    } catch (_) {}
  }

  // This method is called when the user clicks the minimize/expand button
  void _toggleExpandedMode() {
    setState(() {
      _expandedDrawingMode = !_expandedDrawingMode;
      // Save the user's preference
      _userPrefersExpandedMode = _expandedDrawingMode;
      _saveUserPreferences();
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Practice Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Show Stroke Order'),
              subtitle: const Text('Display stroke order numbers'),
              value: _showStrokeOrder,
              onChanged: (value) {
                setState(() {
                  _showStrokeOrder = value;
                });
                Navigator.of(context).pop();
              },
            ),
            SwitchListTile(
              title: const Text('Show Hints'),
              subtitle: const Text('Enable stroke hints'),
              value: _showHints,
              onChanged: (value) {
                setState(() {
                  _showHints = value;
                });
                Navigator.of(context).pop();
              },
            ),
            SwitchListTile(
              title: const Text('Character Recognition'),
              subtitle: const Text('Check if your character is correct'),
              value: _enableRecognition,
              onChanged: (value) {
                setState(() {
                  _enableRecognition = value;
                });
                Navigator.of(context).pop();
              },
            ),
            SwitchListTile(
              title: const Text('Real-time Recognition'),
              subtitle: const Text('Check character as you draw'),
              value: _enableRealTimeRecognition,
              onChanged: _enableRecognition
                  ? (value) {
                      setState(() {
                        _enableRealTimeRecognition = value;
                      });
                      Navigator.of(context).pop();
                    }
                  : null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Writing'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading characters...',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Background gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.primary.withOpacity(0.1),
                        colorScheme.surface,
                      ],
                    ),
                  ),
                ),

                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      // Custom app bar with tabs
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Top bar with title and actions
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Kana Practice',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (_showDrawingBoard)
                                        IconButton(
                                          icon: Icon(_expandedDrawingMode
                                              ? Icons.fullscreen_exit
                                              : Icons.fullscreen),
                                          onPressed: _toggleExpandedMode,
                                          tooltip: _expandedDrawingMode
                                              ? 'Exit Fullscreen'
                                              : 'Fullscreen Mode',
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.settings),
                                        onPressed: _showSettingsDialog,
                                        tooltip: 'Settings',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Tab bar
                            TabBar(
                              controller: _tabController,
                              tabs: const [
                                Tab(text: 'Hiragana'),
                                Tab(text: 'Katakana'),
                              ],
                              indicatorColor: colorScheme.primary,
                              indicatorWeight: 3,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                              labelColor: colorScheme.primary,
                              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ],
                        ),
                      ),

                      // Character display and practice area
                      Expanded(
                        flex: _expandedDrawingMode ? 5 : 3,
                        child: _selectedCharacter != null
                            ? Container(
                                margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Animation or drawing board - now takes full space
                                    Expanded(
                                      child: _showAnimation
                                          ? CharacterStrokeAnimation(
                                              character: _selectedCharacter!,
                                            )
                                          : CharacterDrawingBoard(
                                              character: _selectedCharacter!,
                                              showStrokeOrder: _showStrokeOrder,
                                              showHints: _showHints,
                                              initialExpandedState: _userPrefersExpandedMode,
                                              enableRecognition: _enableRecognition,
                                              enableRealTimeRecognition: _enableRealTimeRecognition,
                                              onExpandStateChanged: (expanded) {
                                                setState(() {
                                                  _expandedDrawingMode = expanded;
                                                  _userPrefersExpandedMode = expanded;
                                                  _saveUserPreferences();
                                                });
                                              },
                                              onRecognitionComplete: (result) {
                                                // Compute simple mark from accuracy
                                                final accuracy = (result.accuracyScore ?? 0.0);
                                                String mark;
                                                if (accuracy >= 90.0) {
                                                  mark = 'Excellent';
                                                } else if (accuracy >= 70.0) {
                                                  mark = 'Goods';
                                                } else {
                                                  mark = 'Failed';
                                                }
                                                if (mark == 'Excellent' || mark == 'Goods') {
                                                  _characterMarks[_selectedCharacter!.character] = mark;
                                                  _confettiController.play();
                                                }
                                              },
                                              onExitToSelection: () {
                                                // Return to selection view and show animation
                                                _refreshMarksFromFirebase().then((_) {
                                                  if (!mounted) return;
                                                  setState(() {
                                                    _showDrawingBoard = false;
                                                    _showAnimation = true;
                                                    _expandedDrawingMode = false;
                                                  });
                                                });
                                              },
                                            ),
                                    ),

                                    // Toggle button - hide in expanded mode
                                    if (!_expandedDrawingMode)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surface,
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(20),
                                            bottomRight: Radius.circular(20),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 5,
                                              offset: const Offset(0, -2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: _toggleDrawingBoard,
                                              icon: Icon(
                                                _showDrawingBoard ? Icons.play_arrow : Icons.edit,
                                                color: Colors.white,
                                              ),
                                              label: Text(_showDrawingBoard
                                                  ? 'Show Animation'
                                                  : 'Practice Writing'),
                                              style: ElevatedButton.styleFrom(
                                                minimumSize: const Size(160, 36),
                                                backgroundColor: colorScheme.primary,
                                                foregroundColor: colorScheme.onPrimary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(18),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      size: 48,
                                      color: colorScheme.primary.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Select a character to begin',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),

                      // Character selection grid - hide in expanded mode
                      if (!_expandedDrawingMode)
                        Flexible(
                          flex: 2,
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Select Character',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _tabController.index == 0 ? "Hiragana" : "Katakana",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _buildCharacterGrid(_hiraganaList),
                                      _buildCharacterGrid(_katakanaList),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Confetti overlay
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirection: math.pi / 2, // straight up
                    emissionFrequency: 0.05,
                    numberOfParticles: 20,
                    maxBlastForce: 20,
                    minBlastForce: 10,
                    gravity: 0.1,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCharacterGrid(List<JapaneseCharacter> characters) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 1,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final character = characters[index];
        final isSelected = _selectedCharacter?.character == character.character;
        final progress = _characterProgress[character.character];
        final masteryLevel = progress?.masteryLevel ?? 0;
        final isMastered = masteryLevel >= 70;

        return Stack(
          children: [
            InkWell(
              onTap: () => _selectCharacter(character),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                      : isMastered
                          ? Colors.green.withOpacity(0.1)
                          : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                      : isMastered
                          ? Border.all(color: Colors.green, width: 1)
                          : null,
                  boxShadow: [
                    if (!isSelected)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: Center(
                  child: character.fullSvgPath != null
                      ? SvgPicture.asset(
                          character.fullSvgPath!,
                          height: 24,
                          width: 24,
                        )
                      : Text(
                          character.character,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight:
                                isSelected || isMastered ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : isMastered
                                    ? Colors.green
                                    : null,
                          ),
                        ),
                ),
              ),
            ),
            // Mark badge overlay (Goods/Excellent)
            if (_characterMarks[character.character] != null)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _characterMarks[character.character] == 'Excellent'
                        ? Colors.green
                        : Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _characterMarks[character.character]!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
