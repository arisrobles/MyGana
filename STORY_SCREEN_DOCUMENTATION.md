# Story Screen Documentation

## Overview

The `StoryScreen` is the core gameplay component of the MyGana Japanese learning app. It presents an interactive story-driven experience where players encounter characters, engage in conversations, and answer Kanji-related questions to progress through the narrative.

## File Location
```
MyGana/lib/screens/story_screen.dart
```

## Dependencies

```dart
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/story_data.dart';
import '../services/firebase_user_sync_service.dart';
import '../services/progress_service.dart';
import 'difficulty_selection_screen.dart';
```

## Core Classes and Enums

### CharacterPosition Enum
```dart
enum CharacterPosition { left, center, right }
```
Defines the positioning of characters on screen during story beats.

### Particle Class
```dart
class Particle {
  double x, y, vx, vy;
  int life;
  Color color;
  // ... methods for particle animation
}
```
Handles visual particle effects for celebrations and feedback.

### HapticFeedbackType Enum
```dart
enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
}
```
Defines different types of haptic feedback for user interactions.

## Main StoryScreen Class

### Constructor
```dart
class StoryScreen extends StatefulWidget {
  final Difficulty difficulty;
  
  const StoryScreen({
    super.key,
    required this.difficulty,
  });
}
```

### Key State Variables

#### Story Progression
- `_currentStoryIndex`: Current position in the story
- `_showingQuestion`: Whether a question is currently displayed
- `_selectedAnswer`: User's selected answer
- `_showingFeedback`: Whether feedback is being shown
- `_isCorrect`: Whether the last answer was correct
- `_showingCompletionScreen`: Whether completion screen is shown
- `_showingFailureScreen`: Whether failure screen is shown

#### Lives System
- `_lives`: Current number of lives (starts at 5.0)
- `_maxLives`: Maximum lives constant (5.0)
- `_livesLostPerWrongAnswer`: Lives lost per incorrect answer (0.5)

#### Hint System
- `_showHint`: Whether hint is currently shown
- `_hintsUsedEasy`: Hints used in easy difficulty
- `_hintsUsedNormal`: Hints used in normal difficulty
- `_hintsUsedHard`: Hints used in hard difficulty

#### Scoring and Progress
- `_correctAnswers`: Number of correct answers
- `_streak`: Current correct answer streak
- `_maxStreak`: Maximum streak achieved
- `_totalScore`: Total game score
- `_experiencePoints`: Player experience points
- `_playerRank`: Current player rank
- `_unlockedTitles`: List of unlocked titles

## Animation Controllers

The screen uses multiple animation controllers for smooth transitions:

```dart
late AnimationController _characterAnimationController;
late AnimationController _dialogAnimationController;
late AnimationController _scoreAnimationController;
late AnimationController _backgroundAnimationController;
late AnimationController _completionAnimationController;
late AnimationController _livesAnimationController;
late AnimationController _floatingMessageController;
```

## Audio System

Multiple audio players handle different sound effects:

```dart
final AudioPlayer _audioPlayer = AudioPlayer();
final AudioPlayer _transitionSoundPlayer = AudioPlayer();
final AudioPlayer _correctSoundPlayer = AudioPlayer();
final AudioPlayer _incorrectSoundPlayer = AudioPlayer();
final AudioPlayer _victoryMusicPlayer = AudioPlayer();
final AudioPlayer _heartLostSoundPlayer = AudioPlayer();
```

## Key Methods

### Lifecycle Methods

#### `initState()`
- Initializes all animation controllers
- Sets up audio players
- Configures system UI for full-screen experience
- Loads story data based on difficulty
- Starts initial animations

#### `dispose()`
- Disposes all animation controllers
- Disposes all audio players
- Restores system UI settings

### Core Gameplay Methods

#### `_nextStoryBeat()`
Main method handling story progression:
- Manages story flow and transitions
- Handles question answering logic
- Manages lives system
- Controls completion/failure conditions

#### `_answerQuestion(String answer)`
Handles user answer selection:
- Validates the answer
- Updates scoring and streak
- Triggers appropriate feedback
- Manages lives loss for incorrect answers

#### `_showHintForQuestion()`
Displays hints for current question:
- Tracks hint usage per difficulty
- Shows custom hints from story data
- Updates hint counter display

### UI Building Methods

#### `_buildHeartsDisplay()`
Creates the lives/hearts display with animations:
- Shows current lives as heart icons
- Handles partial hearts (0.5 lives)
- Includes shake animation for life loss

#### `_buildHintCounterDisplay()`
Creates the hint counter display:
- Shows remaining hints for current difficulty
- Simple, compact design beside hint button
- Updates based on difficulty-specific hint usage

#### `_buildStreakDisplay()`
Creates the streak counter:
- Shows current correct answer streak
- Only displays when streak > 1
- Includes scaling animation

#### `_buildLoadingScreen()`
Creates the loading screen between interactions:
- Shows progress indicator
- Displays current interaction number
- Handles background transitions

#### `_buildCompletionScreen()`
Creates the victory/completion screen:
- Shows completion statistics
- Displays achievements unlocked
- Includes confetti celebration
- Provides navigation options

#### `_buildFailureScreen()`
Creates the failure screen:
- Shows failure message
- Displays final statistics
- Provides retry options

#### `_buildEnhancedDialogView(StoryBeat beat)`
Creates the main dialog interface:
- Displays character dialogue
- Shows character images
- Handles text animations
- Includes hint button when appropriate

#### `_buildEnhancedQuestionView(Question question)`
Creates the question interface:
- Displays question text
- Shows answer options
- Includes hint counter and button
- Handles answer selection

### Utility Methods

#### `_getHintForCurrentQuestion()`
Returns appropriate hint for current question:
- Uses custom hints from story data
- Falls back to generated hints
- Considers difficulty level

#### `_getHintsUsedForCurrentDifficulty()`
Returns hint count for current difficulty level.

#### `_getRemainingHintsForCurrentDifficulty()`
Returns remaining hints for current difficulty (max 3).

#### `_loseLives()`
Handles life loss:
- Reduces lives by 0.5 per wrong answer
- Triggers shake animation
- Plays heart lost sound
- Handles game over condition

#### `_showFloatingFeedback(String message)`
Displays floating feedback messages:
- Shows temporary messages
- Includes fade animations
- Used for wrong answer feedback

## Game Flow

### 1. Initialization
- Load story data based on difficulty
- Initialize all systems (audio, animations, etc.)
- Show loading screen

### 2. Story Progression
- Display story beats with character dialogue
- Handle user taps to advance dialogue
- Transition between story beats with animations

### 3. Question Handling
- Present questions with multiple choice answers
- Allow hint usage (max 3 per difficulty)
- Track lives and scoring
- Provide immediate feedback

### 4. Completion/Failure
- Check completion criteria (7+ correct answers + lives remaining)
- Show appropriate end screen
- Save progress and achievements

## Difficulty System

The screen adapts based on the selected difficulty:

- **Easy**: Green color scheme, beginner-friendly content
- **Normal**: Blue color scheme, standard difficulty
- **Hard**: Red color scheme, advanced challenges

Each difficulty has:
- Separate hint tracking (3 hints per difficulty)
- Different story beats and questions
- Appropriate visual styling

## Visual Features

### Animations
- Character slide animations
- Dialog fade transitions
- Score scaling effects
- Background transitions
- Heart shake animations
- Confetti celebrations

### Visual Effects
- Particle systems for celebrations
- Floating feedback messages
- Smooth transitions between states
- Responsive UI elements

### Audio Feedback
- Correct answer sounds
- Incorrect answer sounds
- Heart lost sounds
- Victory music
- Transition sounds

## State Management

The screen manages complex state including:
- Story progression
- Question answering
- Lives system
- Hint usage
- Scoring and achievements
- Audio playback
- Animation states

## Integration Points

### External Services
- `FirebaseUserSyncService`: Syncs user progress
- `ProgressService`: Manages learning progress
- `SharedPreferences`: Stores local data

### Data Sources
- `story_data.dart`: Contains all story beats and questions
- `difficulty_selection_screen.dart`: Receives difficulty parameter

## Performance Considerations

- Efficient animation controllers with proper disposal
- Audio player management to prevent memory leaks
- Optimized UI rebuilding with proper state management
- Responsive design for different screen sizes

## Error Handling

- Graceful handling of missing background images
- Audio loading error management
- Story data validation
- Safe navigation and state transitions

## Accessibility Features

- Haptic feedback for interactions
- Visual feedback for all actions
- Clear visual hierarchy
- Responsive touch targets
- Audio cues for important events

## Future Enhancements

The architecture supports easy addition of:
- New difficulty levels
- Additional story content
- More complex scoring systems
- Enhanced visual effects
- Additional accessibility features

---

*This documentation covers the main functionality and structure of the StoryScreen component. For specific implementation details, refer to the source code and inline comments.*
