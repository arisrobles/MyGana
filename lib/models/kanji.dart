class Kanji {
  final String character;
  final List<String> onYomi;
  final List<String> kunYomi;
  final String meaning;
  final List<Map<String, String>> examples;

  Kanji({
    required this.character,
    required this.onYomi,
    required this.kunYomi,
    required this.meaning,
    required this.examples,
  });

  Map<String, dynamic> toJson() => {
        'character': character,
        'onYomi': onYomi,
        'kunYomi': kunYomi,
        'meaning': meaning,
        'examples': examples,
      };

  factory Kanji.fromJson(Map<String, dynamic> json) => Kanji(
        character: json['character'],
        onYomi: List<String>.from(json['onYomi']),
        kunYomi: List<String>.from(json['kunYomi']),
        meaning: json['meaning'],
        examples: List<Map<String, String>>.from(json['examples'].map((x) => Map<String, String>.from(x))),
      );
}

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'vocabulary': vocabulary,
        'grammar': grammar,
      };

  factory LessonPack.fromJson(Map<String, dynamic> json) => LessonPack(
        id: json['id'],
        name: json['name'],
        vocabulary: List<Map<String, String>>.from(json['vocabulary'].map((x) => Map<String, String>.from(x))),
        grammar: List<String>.from(json['grammar']),
      );
}