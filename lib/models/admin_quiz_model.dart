class AdminQuiz {
  final String id;
  final String title;
  final String description;
  final String category;
  final String level;
  final List<QuizQuestion> questions;
  final int timeLimit; // Total time limit in minutes
  final int passingScore; // Minimum score to pass (percentage)
  final bool isActive; // Whether the quiz is available to students
  final DateTime createdAt;
  final DateTime? updatedAt;

  AdminQuiz({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.level,
    required this.questions,
    this.timeLimit = 30, // Default 30 minutes
    this.passingScore = 70, // Default 70%
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory AdminQuiz.fromMap(Map<String, dynamic> map) {
    print('🔍 Parsing AdminQuiz from map: $map');
    
    // Handle questions field safely - it might be null or not a list
    List<QuizQuestion> questions = [];
    if (map['questions'] != null && map['questions'] is List) {
      try {
        print('📝 Processing questions list: ${map['questions']}');
        questions = (map['questions'] as List)
            .map((q) {
              print('📝 Processing question: $q');
              if (q is Map<String, dynamic>) {
                return QuizQuestion.fromMap(q);
              } else if (q is Map<dynamic, dynamic>) {
                return QuizQuestion.fromMap(Map<String, dynamic>.from(q));
              } else {
                print('❌ Question is not a map: ${q.runtimeType}');
                throw Exception('Question is not a map: ${q.runtimeType}');
              }
            })
            .toList();
        print('✅ Successfully parsed ${questions.length} questions');
      } catch (e) {
        print('❌ Error parsing questions: $e');
        questions = []; // Fallback to empty list
      }
    } else {
      print('⚠️ Questions field is null or not a list: ${map['questions']?.runtimeType}');
    }

    try {
      return AdminQuiz(
        id: map['id'] as String? ?? 'unknown_id',
        title: map['title'] as String? ?? 'Untitled Quiz',
        description: map['description'] as String? ?? 'No description',
        category: map['category'] as String? ?? 'General',
        level: map['level'] as String? ?? 'Beginner',
        questions: questions,
        timeLimit: map['timeLimit'] as int? ?? 30,
        passingScore: map['passingScore'] as int? ?? 70,
        isActive: map['isActive'] as bool? ?? true,
        createdAt: map['createdAt'] != null 
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.now(),
        updatedAt: map['updatedAt'] != null 
            ? DateTime.parse(map['updatedAt'] as String) 
            : null,
      );
    } catch (e) {
      print('❌ Error creating AdminQuiz: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'level': level,
      'questions': questions.map((q) => q.toMap()).toList(),
      'timeLimit': timeLimit,
      'passingScore': passingScore,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  AdminQuiz copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? level,
    List<QuizQuestion>? questions,
    int? timeLimit,
    int? passingScore,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminQuiz(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      level: level ?? this.level,
      questions: questions ?? this.questions,
      timeLimit: timeLimit ?? this.timeLimit,
      passingScore: passingScore ?? this.passingScore,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final int points; // Points for correct answer
  final String? imageUrl; // Optional image for the question

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    this.points = 10,
    this.imageUrl,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    print('🔍 Parsing QuizQuestion from map: $map');
    
    // Handle missing question field - use first option as fallback
    String questionText = map['question'] as String? ?? 'Question';
    if (questionText.isEmpty && map['options'] is List && (map['options'] as List).isNotEmpty) {
      questionText = (map['options'] as List).first.toString();
    }
    
    // Ensure options is a list
    List<String> optionsList = [];
    if (map['options'] is List) {
      optionsList = (map['options'] as List).map((e) => e.toString()).toList();
    }
    
    // Ensure we have at least 4 options
    while (optionsList.length < 4) {
      optionsList.add('Option ${optionsList.length + 1}');
    }
    
    print('📝 Parsed question: $questionText');
    print('📝 Parsed options: $optionsList');
    print('📝 Parsed correctAnswerIndex: ${map['correctAnswerIndex']}');
    
    return QuizQuestion(
      id: map['id'] as String? ?? 'q_${DateTime.now().millisecondsSinceEpoch}',
      question: questionText,
      options: optionsList,
      correctAnswerIndex: map['correctAnswerIndex'] as int? ?? 0,
      explanation: map['explanation'] as String? ?? 'No explanation provided',
      points: map['points'] as int? ?? 10,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'points': points,
      'imageUrl': imageUrl,
    };
  }

  QuizQuestion copyWith({
    String? id,
    String? question,
    List<String>? options,
    int? correctAnswerIndex,
    String? explanation,
    int? points,
    String? imageUrl,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      explanation: explanation ?? this.explanation,
      points: points ?? this.points,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
