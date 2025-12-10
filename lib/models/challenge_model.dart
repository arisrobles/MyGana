import 'dart:convert';

class Challenge {
  final String id;
  final String title;
  final String description;
  final String category;
  final String level;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String? nextChallengeId;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.level,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.nextChallengeId,
  });

  factory Challenge.fromMap(Map<String, dynamic> map) {
    // Parse the options JSON string into a List<String>
    List<String> parsedOptions = List<String>.from(
      jsonDecode(map['options'] as String),
    );

    return Challenge(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      level: map['level'] as String,
      question: map['question'] as String,
      options: parsedOptions,
      correctAnswer: map['correct_answer'] as String,
      explanation: map['explanation'] as String,
      nextChallengeId: map['next_challenge_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'level': level,
      'question': question,
      'options': jsonEncode(options),  // Convert List back to JSON string
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'next_challenge_id': nextChallengeId,
    };
  }

  // Check if the given answer is correct
  bool isCorrect(String answer) {
    return answer.toLowerCase().trim() == correctAnswer.toLowerCase().trim();
  }

  // Get feedback based on the answer
  String getFeedback(String answer) {
    if (isCorrect(answer)) {
      return '正解 (Correct)! $explanation';
    } else {
      return 'incorrect. The correct answer is "$correctAnswer". $explanation';
    }
  }

  // Get a hint for the current challenge
  String getHint() {
    switch (category.toLowerCase()) {
      case 'hiragana':
        return 'Listen to the sound and try to match it with the correct character.';
      case 'katakana':
        return 'Katakana is mainly used for foreign words. Think about the sound in the original language.';
      case 'kanji':
        return 'Look at the radicals (components) of the kanji to help remember its meaning.';
      default:
        return 'Take your time and consider each option carefully.';
    }
  }

  // Check if this is the last challenge
  bool get isLastChallenge => nextChallengeId == null;
} 