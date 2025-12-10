class LessonPack {
  final String id;
  final String name;
  final List<Map<String, String>> vocabulary;
  final List<String> grammar;

  LessonPack({
    required this.id,
    required this.name,
    required this.vocabulary,
    required this.grammar,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'vocabulary': vocabulary,
      'grammar': grammar,
    };
  }

  factory LessonPack.fromMap(Map<String, dynamic> map) {
    return LessonPack(
      id: map['id'] as String,
      name: map['name'] as String,
      vocabulary: List<Map<String, String>>.from(map['vocabulary'] as List),
      grammar: List<String>.from(map['grammar'] as List),
    );
  }
} 