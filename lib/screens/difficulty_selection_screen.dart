import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'story_screen.dart';

enum Difficulty {
  EASY,
  NORMAL,
  HARD,
}

// Utility class for story completion tracking
class StoryCompletionTracker {
  static Future<void> markStoryCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('story_completed', true);
  }

  static Future<bool> isStoryCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('story_completed') ?? false;
  }
}

class DifficultySelectionScreen extends StatefulWidget {
  const DifficultySelectionScreen({super.key});

  @override
  State<DifficultySelectionScreen> createState() => _DifficultySelectionScreenState();
}

class _DifficultySelectionScreenState extends State<DifficultySelectionScreen> {
  bool _isStoryCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadCompletionStatus();
  }

  // Load completion status from SharedPreferences
  Future<void> _loadCompletionStatus() async {
    final storyCompleted = await StoryCompletionTracker.isStoryCompleted();
    setState(() {
      _isStoryCompleted = storyCompleted;
    });
  }

  void _startStory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StoryScreen(),
      ),
    );
    // Refresh completion status when returning from story screen
    _loadCompletionStatus();
  }

  void _showGameOverview() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final screenSize = MediaQuery.of(context).size;
        final maxWidth = screenSize.width * 0.8;
        final maxHeight = screenSize.height * 0.8;
        
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.8),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'Journey of the Kanji Seeker',
                      style: TextStyle(
                        fontSize: screenSize.width * 0.025,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'TheLastShuriken',
                        color: Colors.amber,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Overview text
                    Text(
                      'You are Haruki, a curious student who discovers a mysterious notebook in the library. The moment you open it, you are transported into a strange world where Kanji comes alive.\n\nIn this journey, you will meet 10 different people—each with their own story and challenge. They will test your knowledge of Kanji through questions, phrases, and sentences. Answer correctly, and you will move forward. Fail, and your path will grow more difficult.\n\nOnly by completing all 10 interactions and proving your understanding of Kanji can you return to the real world. Your adventure begins now—are you ready to walk the path of the Kanji Seeker?',
                      style: TextStyle(
                        fontSize: screenSize.width * 0.015,
                        color: Colors.white,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 20),
                    
                    // Yes button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.withOpacity(0.8),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Yes',
                          style: TextStyle(
                            fontSize: screenSize.width * 0.018,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'TheLastShuriken',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/images/backgrounds/Gate (Intro).png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.image_not_supported,
                      color: Colors.white, size: 48),
                ),
              );
            },
          ),
          
          // Game Overview Button (upper-right corner)
          Positioned(
            top: 20,
            right: 20,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.8),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  onPressed: _showGameOverview,
                  icon: const Icon(
                    Icons.info_outline,
                    color: Colors.amber,
                    size: 24,
                  ),
                  tooltip: 'Game Overview',
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: isLandscape ? 12 : 16,
                        horizontal: isLandscape ? 24 : 28,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Journey of the Kanji Seeker',
                        style: TextStyle(
                          fontSize: isLandscape 
                            ? screenSize.width * 0.03 
                            : screenSize.width * 0.06,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'TheLastShuriken',
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    SizedBox(height: isLandscape ? 16 : 24),
                    
                    // Subtitle
                    Text(
                      'Begin your adventure',
                      style: TextStyle(
                        fontSize: isLandscape 
                          ? screenSize.width * 0.02 
                          : screenSize.width * 0.04,
                        fontWeight: FontWeight.bold,
                        fontFamily: "TheLastShuriken",
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 3.0,
                            color: Colors.black.withOpacity(0.8),
                            offset: const Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: isLandscape ? 32 : 48),
                    
                    // Start button
                    _buildStartButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    return Container(
      width: isLandscape 
        ? screenSize.width * 0.3 
        : screenSize.width * 0.7,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          ElevatedButton(
            onPressed: _startStory,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                vertical: isLandscape ? 20 : 24,
                horizontal: isLandscape ? 16 : 20,
              ),
              backgroundColor: _isStoryCompleted 
                ? Colors.amber.withOpacity(0.6) 
                : Colors.blue.withOpacity(0.8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _isStoryCompleted ? Colors.amber : Colors.blue, 
                  width: _isStoryCompleted ? 3 : 2,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isStoryCompleted ? 'Play Again' : 'Start',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isLandscape ? 18 : 22,
                        fontFamily: "TheLastShuriken"
                      ),
                    ),
                    if (_isStoryCompleted) ...[
                      SizedBox(width: 8),
                      Icon(
                        Icons.replay,
                        color: Colors.white,
                        size: isLandscape ? 20 : 24,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: isLandscape ? 8 : 10),
                Text(
                  _isStoryCompleted ? 'Continue your journey' : 'Begin your adventure',
                  style: TextStyle(
                    fontSize: isLandscape ? 14 : 16,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Completion badge overlay
          if (_isStoryCompleted)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Icon(
                  Icons.star,
                  color: Colors.white,
                  size: isLandscape ? 16 : 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
