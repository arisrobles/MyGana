class Lesson {
  final String id;
  final String title;
  final String description;
  final String category;
  final String level;

  Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.level,
  });

  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      level: map['level'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'level': level,
    };
  }
} 