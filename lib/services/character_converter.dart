import 'dart:developer' as developer;
import 'package:nihongo_japanese_app/models/japanese_character.dart';

class CharacterConverter {
  /// Converts a list of database maps to JapaneseCharacter objects
  static List<JapaneseCharacter> convertToJapaneseCharacters(List<Map<String, dynamic>> data, String type) {
    developer.log('Converting ${data.length} characters of type: $type');
    return data.map((map) => _convertMapToJapaneseCharacter(map, type)).toList();
  }

  /// Converts a single database map to a JapaneseCharacter object
  static JapaneseCharacter _convertMapToJapaneseCharacter(Map<String, dynamic> map, String type) {
    final svgFilename = map['svg'] as String?;
    developer.log('Converting character: ${map['character']}, SVG filename: $svgFilename');
    
    if (svgFilename == null) {
      developer.log('Warning: No SVG filename for character ${map['character']}');
    }

    return JapaneseCharacter(
      character: map['character'] as String,
      romanization: map['romaji'] as String,
      meaning: '', // Not available in the database
      strokeOrder: [], // Not available in the database
      type: type,
      jlptLevel: null, // Not available in the database
      strokeDirections: null, // Not available in the database
      svgFilename: svgFilename,
    );
  }

  /// Converts a JapaneseCharacter object to a database map
  static Map<String, dynamic> convertToMap(JapaneseCharacter character) {
    return {
      'character': character.character,
      'romaji': character.romanization,
      'svg': character.svgFilename, // Store the filename back to the map
    };
  }
} 