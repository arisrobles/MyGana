import 'package:flutter/material.dart';

class JapaneseCharacter {
  final String character;
  final String romanization;
  final String meaning;
  final List<List<Offset>> strokeOrder;
  final String type; // 'hiragana', 'katakana', or 'kanji'
  final int? jlptLevel; // JLPT level (N5-N1), null for kana
  final List<String>? strokeDirections; // Directions for each stroke
  final String? svgFilename; // Store the SVG filename, e.g., '1_a_hira.svg'
  final String? tips; // Character-specific writing tips

  JapaneseCharacter({
    required this.character,
    required this.romanization,
    required this.meaning,
    required this.strokeOrder,
    required this.type,
    this.jlptLevel,
    this.strokeDirections,
    this.svgFilename,
    this.tips,
  });

  bool get isHiragana => type == 'hiragana';

  // Helper method to get the full asset path
  String? get fullSvgPath {
    if (svgFilename == null) return null;
    return 'assets/${isHiragana ? 'HiraganaSVG' : 'KatakanaSVG'}/$svgFilename';
  }
}
