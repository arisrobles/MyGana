class Flashcard {
  final String id;
  final String front;
  final String back;
  final String categoryId;
  final DateTime createdAt;
  final DateTime? lastReviewed;
  final int reviewCount;
  final int correctCount;

  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.categoryId,
    required this.createdAt,
    this.lastReviewed,
    this.reviewCount = 0,
    this.correctCount = 0,
  });

  factory Flashcard.fromMap(Map<String, dynamic> map) {
    return Flashcard(
      id: map['id'] as String,
      front: map['front'] as String,
      back: map['back'] as String,
      categoryId: map['category_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastReviewed: map['last_reviewed'] != null
          ? DateTime.parse(map['last_reviewed'] as String)
          : null,
      reviewCount: map['review_count'] as int? ?? 0,
      correctCount: map['correct_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'front': front,
      'back': back,
      'category_id': categoryId,
      'created_at': createdAt.toIso8601String(),
      'last_reviewed': lastReviewed?.toIso8601String(),
      'review_count': reviewCount,
      'correct_count': correctCount,
    };
  }
} 