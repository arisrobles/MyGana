class Story {
  final String id;
  final String title;
  final String level;
  final List<StoryPage> pages;

  Story({
    required this.id,
    required this.title,
    required this.level,
    required this.pages,
  });
}

class StoryPage {
  final String japaneseText;
  final String furigana;
  final String englishText;
  final String? imagePath;
  final List<Vocabulary> vocabulary;

  StoryPage({
    required this.japaneseText,
    required this.furigana,
    required this.englishText,
    this.imagePath,
    this.vocabulary = const [],
  });
}

class Vocabulary {
  final String japanese;
  final String furigana;
  final String english;

  Vocabulary({
    required this.japanese,
    required this.furigana,
    required this.english,
  });
}

