/// Constants for Japanese character counts
class CharacterConstants {
  // Total number of characters available in the app
  static const int totalHiraganaCharacters = 73; // All Hiragana characters from SVG files
  static const int totalKatakanaCharacters = 73; // All Katakana characters from SVG files
  static const int totalKanjiCharacters = 12; // Basic kanji characters
  
  // Total characters per script
  static const int totalCharacters = totalHiraganaCharacters + totalKatakanaCharacters + totalKanjiCharacters;
  
  // Mastery threshold (percentage)
  static const int masteryThreshold = 70; // 70% mastery level considered "completed"
  
  // Get total characters for a specific script
  static int getTotalCharactersForScript(String script) {
    switch (script.toLowerCase()) {
      case 'hiragana':
        return totalHiraganaCharacters;
      case 'katakana':
        return totalKatakanaCharacters;
      case 'kanji':
        return totalKanjiCharacters;
      default:
        return 0;
    }
  }
}
