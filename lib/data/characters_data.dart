import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/models/japanese_character.dart';

class CharactersData {
  static List<JapaneseCharacter> getHiragana() {
    return [
      JapaneseCharacter(
        character: 'あ',
        romanization: 'a',
        meaning: 'Hiragana A',
        type: 'hiragana',
        strokeOrder: [
          // First stroke - top curve
          [
            const Offset(0.3, 0.3),
            const Offset(0.4, 0.2),
            const Offset(0.5, 0.15),
            const Offset(0.6, 0.2),
            const Offset(0.7, 0.3),
          ],
          // Second stroke - middle curve
          [
            const Offset(0.25, 0.5),
            const Offset(0.35, 0.4),
            const Offset(0.5, 0.35),
            const Offset(0.65, 0.4),
            const Offset(0.75, 0.5),
          ],
          // Third stroke - vertical line
          [
            const Offset(0.5, 0.35),
            const Offset(0.5, 0.45),
            const Offset(0.5, 0.55),
            const Offset(0.5, 0.65),
            const Offset(0.5, 0.75),
            const Offset(0.5, 0.85),
          ],
        ],
        strokeDirections: [
          'Start from the left, curve up and then down to the right',
          'Start from the left, curve through the middle',
          'Draw straight down from the middle of the second stroke',
        ],
      ),
      JapaneseCharacter(
        character: 'い',
        romanization: 'i',
        meaning: 'Hiragana I',
        type: 'hiragana',
        strokeOrder: [
          // First stroke - top curve
          [
            const Offset(0.3, 0.3),
            const Offset(0.4, 0.25),
            const Offset(0.5, 0.2),
            const Offset(0.6, 0.25),
            const Offset(0.7, 0.3),
          ],
          // Second stroke - long curve
          [
            const Offset(0.7, 0.3),
            const Offset(0.65, 0.4),
            const Offset(0.6, 0.5),
            const Offset(0.55, 0.6),
            const Offset(0.5, 0.7),
            const Offset(0.4, 0.8),
            const Offset(0.3, 0.9),
          ],
        ],
        strokeDirections: [
          'Start from the left, curve up and then down to the right',
          'Continue from the end of the first stroke, curve down and to the left',
        ],
      ),
      JapaneseCharacter(
        character: 'う',
        romanization: 'u',
        meaning: 'Hiragana U',
        type: 'hiragana',
        strokeOrder: [
          // Single stroke
          [
            const Offset(0.3, 0.3),
            const Offset(0.3, 0.4),
            const Offset(0.3, 0.5),
            const Offset(0.35, 0.6),
            const Offset(0.45, 0.7),
            const Offset(0.55, 0.75),
            const Offset(0.65, 0.7),
            const Offset(0.7, 0.6),
            const Offset(0.7, 0.5),
            const Offset(0.7, 0.4),
            const Offset(0.7, 0.3),
          ],
        ],
        strokeDirections: [
          'Start from the top left, go down, curve to the right and up',
        ],
      ),
      JapaneseCharacter(
        character: 'え',
        romanization: 'e',
        meaning: 'Hiragana E',
        type: 'hiragana',
        strokeOrder: [
          // First stroke - horizontal line
          [
            const Offset(0.3, 0.3),
            const Offset(0.4, 0.3),
            const Offset(0.5, 0.3),
            const Offset(0.6, 0.3),
            const Offset(0.7, 0.3),
          ],
          // Second stroke - vertical line
          [
            const Offset(0.5, 0.3),
            const Offset(0.5, 0.4),
            const Offset(0.5, 0.5),
            const Offset(0.5, 0.6),
            const Offset(0.5, 0.7),
          ],
          // Third stroke - bottom curve
          [
            const Offset(0.3, 0.7),
            const Offset(0.4, 0.75),
            const Offset(0.5, 0.8),
            const Offset(0.6, 0.75),
            const Offset(0.7, 0.7),
          ],
        ],
        strokeDirections: [
          'Draw a horizontal line from left to right',
          'Draw a vertical line down from the middle of the first stroke',
          'Draw a curve from left to right at the bottom',
        ],
      ),
      JapaneseCharacter(
        character: 'お',
        romanization: 'o',
        meaning: 'Hiragana O',
        type: 'hiragana',
        strokeOrder: [
          // First stroke - top curve
          [
            const Offset(0.3, 0.3),
            const Offset(0.4, 0.25),
            const Offset(0.5, 0.2),
            const Offset(0.6, 0.25),
            const Offset(0.7, 0.3),
          ],
          // Second stroke - vertical line with hook
          [
            const Offset(0.5, 0.2),
            const Offset(0.5, 0.3),
            const Offset(0.5, 0.4),
            const Offset(0.5, 0.5),
            const Offset(0.5, 0.6),
            const Offset(0.45, 0.7),
            const Offset(0.4, 0.75),
          ],
          // Third stroke - bottom right curve
          [
            const Offset(0.5, 0.5),
            const Offset(0.55, 0.55),
            const Offset(0.6, 0.6),
            const Offset(0.65, 0.65),
            const Offset(0.7, 0.7),
          ],
        ],
        strokeDirections: [
          'Draw a curve from left to right at the top',
          'Draw down from the top, then curve left at the bottom',
          'From the middle of the vertical line, curve down and to the right',
        ],
      ),
    ];
  }

  static List<JapaneseCharacter> getKatakana() {
    return [
      JapaneseCharacter(
        character: 'ア',
        romanization: 'a',
        meaning: 'Katakana A',
        type: 'katakana',
        strokeOrder: [
          // First stroke - left diagonal
          [
            const Offset(0.3, 0.3),
            const Offset(0.4, 0.4),
            const Offset(0.5, 0.5),
            const Offset(0.6, 0.6),
            const Offset(0.7, 0.7),
          ],
          // Second stroke - right diagonal
          [
            const Offset(0.7, 0.3),
            const Offset(0.6, 0.4),
            const Offset(0.5, 0.5),
            const Offset(0.4, 0.6),
            const Offset(0.3, 0.7),
          ],
          // Third stroke - middle horizontal
          [
            const Offset(0.3, 0.5),
            const Offset(0.4, 0.5),
            const Offset(0.5, 0.5),
            const Offset(0.6, 0.5),
            const Offset(0.7, 0.5),
          ],
        ],
        strokeDirections: [
          'Draw a diagonal line from top left to bottom right',
          'Draw a diagonal line from top right to bottom left',
          'Draw a horizontal line through the middle',
        ],
      ),
      JapaneseCharacter(
        character: 'イ',
        romanization: 'i',
        meaning: 'Katakana I',
        type: 'katakana',
        strokeOrder: [
          // First stroke - vertical line
          [
            const Offset(0.5, 0.2),
            const Offset(0.5, 0.3),
            const Offset(0.5, 0.4),
            const Offset(0.5, 0.5),
            const Offset(0.5, 0.6),
            const Offset(0.5, 0.7),
            const Offset(0.5, 0.8),
          ],
          // Second stroke - horizontal line
          [
            const Offset(0.3, 0.3),
            const Offset(0.4, 0.3),
            const Offset(0.5, 0.3),
            const Offset(0.6, 0.3),
            const Offset(0.7, 0.3),
          ],
        ],
        strokeDirections: [
          'Draw a vertical line from top to bottom',
          'Draw a horizontal line crossing the vertical line near the top',
        ],
      ),
      JapaneseCharacter(
        character: 'ウ',
        romanization: 'u',
        meaning: 'Katakana U',
        type: 'katakana',
        strokeOrder: [
          // First stroke - main curve
          [
            const Offset(0.3, 0.3),
            const Offset(0.35, 0.4),
            const Offset(0.4, 0.5),
            const Offset(0.45, 0.6),
            const Offset(0.5, 0.7),
            const Offset(0.55, 0.6),
            const Offset(0.6, 0.5),
            const Offset(0.65, 0.4),
            const Offset(0.7, 0.3),
          ],
          // Second stroke - bottom right hook
          [
            const Offset(0.7, 0.3),
            const Offset(0.75, 0.4),
            const Offset(0.8, 0.5),
          ],
        ],
        strokeDirections: [
          'Draw a U-shaped curve from top left to top right',
          'From the end of the first stroke, draw a small hook down and to the right',
        ],
      ),
      JapaneseCharacter(
        character: 'エ',
        romanization: 'e',
        meaning: 'Katakana E',
        type: 'katakana',
        strokeOrder: [
          // First stroke - top horizontal
          [
            const Offset(0.3, 0.3),
            const Offset(0.4, 0.3),
            const Offset(0.5, 0.3),
            const Offset(0.6, 0.3),
            const Offset(0.7, 0.3),
          ],
          // Second stroke - middle horizontal
          [
            const Offset(0.3, 0.5),
            const Offset(0.4, 0.5),
            const Offset(0.5, 0.5),
            const Offset(0.6, 0.5),
            const Offset(0.7, 0.5),
          ],
          // Third stroke - bottom horizontal
          [
            const Offset(0.3, 0.7),
            const Offset(0.4, 0.7),
            const Offset(0.5, 0.7),
            const Offset(0.6, 0.7),
            const Offset(0.7, 0.7),
          ],
        ],
        strokeDirections: [
          'Draw a horizontal line at the top',
          'Draw a horizontal line in the middle',
          'Draw a horizontal line at the bottom',
        ],
      ),
      JapaneseCharacter(
        character: 'オ',
        romanization: 'o',
        meaning: 'Katakana O',
        type: 'katakana',
        strokeOrder: [
          // First stroke - outer square
          [
            const Offset(0.3, 0.3),
            const Offset(0.4, 0.3),
            const Offset(0.5, 0.3),
            const Offset(0.6, 0.3),
            const Offset(0.7, 0.3),
            const Offset(0.7, 0.4),
            const Offset(0.7, 0.5),
            const Offset(0.7, 0.6),
            const Offset(0.7, 0.7),
            const Offset(0.6, 0.7),
            const Offset(0.5, 0.7),
            const Offset(0.4, 0.7),
            const Offset(0.3, 0.7),
            const Offset(0.3, 0.6),
            const Offset(0.3, 0.5),
            const Offset(0.3, 0.4),
            const Offset(0.3, 0.3),
          ],
          // Second stroke - inner cross (horizontal)
          [
            const Offset(0.3, 0.5),
            const Offset(0.4, 0.5),
            const Offset(0.5, 0.5),
            const Offset(0.6, 0.5),
            const Offset(0.7, 0.5),
          ],
          // Third stroke - inner cross (vertical)
          [
            const Offset(0.5, 0.3),
            const Offset(0.5, 0.4),
            const Offset(0.5, 0.5),
            const Offset(0.5, 0.6),
            const Offset(0.5, 0.7),
          ],
        ],
        strokeDirections: [
          'Draw a square shape, starting from top left, going clockwise',
          'Draw a horizontal line through the middle',
          'Draw a vertical line through the middle',
        ],
      ),
    ];
  }

  static List<JapaneseCharacter> getBasicKanji() {
    return [
      JapaneseCharacter(
        character: '一',
        romanization: 'ichi',
        meaning: 'one',
        type: 'kanji',
        jlptLevel: 5,
        strokeOrder: [
          // Single horizontal stroke
          [
            const Offset(0.2, 0.5),
            const Offset(0.3, 0.5),
            const Offset(0.4, 0.5),
            const Offset(0.5, 0.5),
            const Offset(0.6, 0.5),
            const Offset(0.7, 0.5),
            const Offset(0.8, 0.5),
          ],
        ],
        strokeDirections: [
          'Draw a single horizontal line from left to right',
        ],
      ),
      JapaneseCharacter(
        character: '二',
        romanization: 'ni',
        meaning: 'two',
        type: 'kanji',
        jlptLevel: 5,
        strokeOrder: [
          // Top horizontal stroke
          [
            const Offset(0.2, 0.4),
            const Offset(0.3, 0.4),
            const Offset(0.4, 0.4),
            const Offset(0.5, 0.4),
            const Offset(0.6, 0.4),
            const Offset(0.7, 0.4),
            const Offset(0.8, 0.4),
          ],
          // Bottom horizontal stroke
          [
            const Offset(0.2, 0.6),
            const Offset(0.3, 0.6),
            const Offset(0.4, 0.6),
            const Offset(0.5, 0.6),
            const Offset(0.6, 0.6),
            const Offset(0.7, 0.6),
            const Offset(0.8, 0.6),
          ],
        ],
        strokeDirections: [
          'Draw a horizontal line from left to right at the top',
          'Draw a horizontal line from left to right at the bottom',
        ],
      ),
      JapaneseCharacter(
        character: '三',
        romanization: 'san',
        meaning: 'three',
        type: 'kanji',
        jlptLevel: 5,
        strokeOrder: [
          // Top horizontal stroke
          [
            const Offset(0.2, 0.3),
            const Offset(0.3, 0.3),
            const Offset(0.4, 0.3),
            const Offset(0.5, 0.3),
            const Offset(0.6, 0.3),
            const Offset(0.7, 0.3),
            const Offset(0.8, 0.3),
          ],
          // Middle horizontal stroke
          [
            const Offset(0.2, 0.5),
            const Offset(0.3, 0.5),
            const Offset(0.4, 0.5),
            const Offset(0.5, 0.5),
            const Offset(0.6, 0.5),
            const Offset(0.7, 0.5),
            const Offset(0.8, 0.5),
          ],
          // Bottom horizontal stroke
          [
            const Offset(0.2, 0.7),
            const Offset(0.3, 0.7),
            const Offset(0.4, 0.7),
            const Offset(0.5, 0.7),
            const Offset(0.6, 0.7),
            const Offset(0.7, 0.7),
            const Offset(0.8, 0.7),
          ],
        ],
        strokeDirections: [
          'Draw a horizontal line from left to right at the top',
          'Draw a horizontal line from left to right in the middle',
          'Draw a horizontal line from left to right at the bottom',
        ],
      ),
      JapaneseCharacter(
        character: '四',
        romanization: 'shi/yon',
        meaning: 'four',
        type: 'kanji',
        jlptLevel: 5,
        strokeOrder: [
          // Left vertical stroke
          [
            const Offset(0.3, 0.2),
            const Offset(0.3, 0.3),
            const Offset(0.3, 0.4),
            const Offset(0.3, 0.5),
            const Offset(0.3, 0.6),
            const Offset(0.3, 0.7),
            const Offset(0.3, 0.8),
          ],
          // Top horizontal stroke
          [
            const Offset(0.3, 0.2),
            const Offset(0.4, 0.2),
            const Offset(0.5, 0.2),
            const Offset(0.6, 0.2),
            const Offset(0.7, 0.2),
          ],
          // Right vertical stroke
          [
            const Offset(0.7, 0.2),
            const Offset(0.7, 0.3),
            const Offset(0.7, 0.4),
            const Offset(0.7, 0.5),
            const Offset(0.7, 0.6),
            const Offset(0.7, 0.7),
            const Offset(0.7, 0.8),
          ],
          // Bottom horizontal stroke
          [
            const Offset(0.3, 0.8),
            const Offset(0.4, 0.8),
            const Offset(0.5, 0.8),
            const Offset(0.6, 0.8),
            const Offset(0.7, 0.8),
          ],
          // Middle horizontal stroke
          [
            const Offset(0.3, 0.5),
            const Offset(0.4, 0.5),
            const Offset(0.5, 0.5),
            const Offset(0.6, 0.5),
            const Offset(0.7, 0.5),
          ],
        ],
        strokeDirections: [
          'Draw a vertical line on the left from top to bottom',
          'Draw a horizontal line at the top from left to right',
          'Draw a vertical line on the right from top to bottom',
          'Draw a horizontal line at the bottom from left to right',
          'Draw a horizontal line through the middle from left to right',
        ],
      ),
      JapaneseCharacter(
        character: '五',
        romanization: 'go',
        meaning: 'five',
        type: 'kanji',
        jlptLevel: 5,
        strokeOrder: [
          // Top horizontal stroke
          [
            const Offset(0.2, 0.3),
            const Offset(0.3, 0.3),
            const Offset(0.4, 0.3),
            const Offset(0.5, 0.3),
            const Offset(0.6, 0.3),
            const Offset(0.7, 0.3),
            const Offset(0.8, 0.3),
          ],
          // Left vertical stroke
          [
            const Offset(0.3, 0.3),
            const Offset(0.3, 0.4),
            const Offset(0.3, 0.5),
            const Offset(0.3, 0.6),
            const Offset(0.3, 0.7),
          ],
          // Middle horizontal stroke
          [
            const Offset(0.2, 0.5),
            const Offset(0.3, 0.5),
            const Offset(0.4, 0.5),
            const Offset(0.5, 0.5),
            const Offset(0.6, 0.5),
            const Offset(0.7, 0.5),
            const Offset(0.8, 0.5),
          ],
          // Right vertical stroke
          [
            const Offset(0.7, 0.3),
            const Offset(0.7, 0.4),
            const Offset(0.7, 0.5),
            const Offset(0.7, 0.6),
            const Offset(0.7, 0.7),
          ],
          // Bottom horizontal stroke
          [
            const Offset(0.2, 0.7),
            const Offset(0.3, 0.7),
            const Offset(0.4, 0.7),
            const Offset(0.5, 0.7),
            const Offset(0.6, 0.7),
            const Offset(0.7, 0.7),
            const Offset(0.8, 0.7),
          ],
        ],
        strokeDirections: [
          'Draw a horizontal line at the top from left to right',
          'Draw a vertical line on the left from top to middle',
          'Draw a horizontal line in the middle from left to right',
          'Draw a vertical line on the right from top to middle',
          'Draw a horizontal line at the bottom from left to right',
        ],
      ),
      JapaneseCharacter(
        character: '六',
        romanization: 'roku',
        meaning: 'six',
        type: 'kanji',
        jlptLevel: 5,
        strokeOrder: [
          // Top horizontal stroke
          [
            const Offset(0.2, 0.3),
            const Offset(0.3, 0.3),
            const Offset(0.4, 0.3),
            const Offset(0.5, 0.3),
            const Offset(0.6, 0.3),
            const Offset(0.7, 0.3),
            const Offset(0.8, 0.3),
          ],
          // Vertical stroke
          [
            const Offset(0.5, 0.3),
            const Offset(0.5, 0.4),
            const Offset(0.5, 0.5),
            const Offset(0.5, 0.6),
            const Offset(0.5, 0.7),
            const Offset(0.5, 0.8),
          ],
          // Bottom left diagonal
          [
            const Offset(0.3, 0.5),
            const Offset(0.35, 0.6),
            const Offset(0.4, 0.7),
            const Offset(0.45, 0.8),
          ],
          // Bottom right diagonal
          [
            const Offset(0.7, 0.5),
            const Offset(0.65, 0.6),
            const Offset(0.6, 0.7),
            const Offset(0.55, 0.8),
          ],
        ],
        strokeDirections: [
          'Draw a horizontal line at the top from left to right',
          'Draw a vertical line down from the middle of the top line',
          'Draw a diagonal line from middle left to bottom center',
          'Draw a diagonal line from middle right to bottom center',
        ],
      ),
      JapaneseCharacter(
        character: '七',
        romanization: 'shichi/nana',
        meaning: 'seven',
        type: 'kanji',
        jlptLevel: 5,
        strokeOrder: [
          // Top horizontal stroke
          [
            const Offset(0.2, 0.3),
            const Offset(0.3, 0.3),
            const Offset(0.4, 0.3),
            const Offset(0.5, 0.3),
            const Offset(0.6, 0.3),
            const Offset(0.7, 0.3),
            const Offset(0.8, 0.3),
          ],
          // Middle horizontal stroke
          [
            const Offset(0.4, 0.5),
            const Offset(0.5, 0.5),
            const Offset(0.6, 0.5),
            const Offset(0.7, 0.5),
            const Offset(0.8, 0.5),
          ],
          // Vertical stroke
          [
            const Offset(0.5, 0.3),
            const Offset(0.5, 0.4),
            const Offset(0.5, 0.5),
            const Offset(0.5, 0.6),
            const Offset(0.5, 0.7),
            const Offset(0.5, 0.8),
          ],
        ],
        strokeDirections: [
          'Draw a horizontal line at the top from left to right',
          'Draw a shorter horizontal line in the middle from center to right',
          'Draw a vertical line down from the middle of the top line',
        ],
      ),
      JapaneseCharacter(
        character: '八',
        romanization: 'hachi',
        meaning: 'eight',
        type: 'kanji',
        jlptLevel: 5,
        strokeOrder: [
          // Left diagonal stroke
          [
            const Offset(0.3, 0.3),
            const Offset(0.35, 0.4),
            const Offset(0.4, 0.5),
            const Offset(0.45, 0.6),
            const Offset(0.5, 0.7),
            const Offset(0.55, 0.8),
          ],
          // Right diagonal stroke
          [
            const Offset(0.7, 0.3),
            const Offset(0.65, 0.4),
            const Offset(0.6, 0.5),
            const Offset(0.55, 0.6),
            const Offset(0.5, 0.7),
            const Offset(0.45, 0.8),
          ],
        ],
        strokeDirections: [
          'Draw a diagonal line from top left to bottom right',
          'Draw a diagonal line from top right to bottom left',
        ],
      ),
      JapaneseCharacter(
        character: '九',
        romanization: 'kyuu/ku',
        meaning: 'nine',
        type: 'kanji',
        jlptLevel: 5,
        strokeOrder: [
          // Top right curve
          [
            const Offset(0.5, 0.2),
            const Offset(0.6, 0.25),
            const Offset(0.7, 0.3),
            const Offset(0.75, 0.4),
            const Offset(0.7, 0.5),
            const Offset(0.6, 0.55),
            const Offset(0.5, 0.6),
          ],
          // Bottom left diagonal
          [
            const Offset(0.5, 0.6),
            const Offset(0.45, 0.65),
            const Offset(0.4, 0.7),
            const Offset(0.35, 0.75),
            const Offset(0.3, 0.8),
          ],
        ],
        strokeDirections: [
          'Start from the top middle, curve to the right and then down and left',
          'Continue from the end of the first stroke, draw diagonally down to the left',
        ],
      ),
      JapaneseCharacter(
        character: '十',
        romanization: 'juu',
        meaning: 'ten',
        type: 'kanji',
        jlptLevel: 5,
        strokeOrder: [
          // Horizontal stroke
          [
            const Offset(0.2, 0.5),
            const Offset(0.3, 0.5),
            const Offset(0.4, 0.5),
            const Offset(0.5, 0.5),
            const Offset(0.6, 0.5),
            const Offset(0.7, 0.5),
            const Offset(0.8, 0.5),
          ],
          // Vertical stroke
          [
            const Offset(0.5, 0.2),
            const Offset(0.5, 0.3),
            const Offset(0.5, 0.4),
            const Offset(0.5, 0.5),
            const Offset(0.5, 0.6),
            const Offset(0.5, 0.7),
            const Offset(0.5, 0.8),
          ],
        ],
        strokeDirections: [
          'Draw a horizontal line from left to right through the middle',
          'Draw a vertical line from top to bottom through the middle',
        ],
      ),
      JapaneseCharacter(
        character: '日',
        romanization: 'hi/nichi',
        meaning: 'sun, day',
        type: 'kanji',
        jlptLevel: 5,
        strokeOrder: [
          // Top horizontal stroke
          [
            const Offset(0.2, 0.2),
            const Offset(0.3, 0.2),
            const Offset(0.4, 0.2),
            const Offset(0.5, 0.2),
            const Offset(0.6, 0.2),
            const Offset(0.7, 0.2),
            const Offset(0.8, 0.2),
          ],
          // Left vertical stroke
          [
            const Offset(0.2, 0.2),
            const Offset(0.2, 0.3),
            const Offset(0.2, 0.4),
            const Offset(0.2, 0.5),
            const Offset(0.2, 0.6),
            const Offset(0.2, 0.7),
            const Offset(0.2, 0.8),
          ],
          // Bottom horizontal stroke
          [
            const Offset(0.2, 0.8),
            const Offset(0.3, 0.8),
            const Offset(0.4, 0.8),
            const Offset(0.5, 0.8),
            const Offset(0.6, 0.8),
            const Offset(0.7, 0.8),
            const Offset(0.8, 0.8),
          ],
          // Right vertical stroke
          [
            const Offset(0.8, 0.2),
            const Offset(0.8, 0.3),
            const Offset(0.8, 0.4),
            const Offset(0.8, 0.5),
            const Offset(0.8, 0.6),
            const Offset(0.8, 0.7),
            const Offset(0.8, 0.8),
          ],
          // Middle horizontal stroke
          [
            const Offset(0.3, 0.5),
            const Offset(0.4, 0.5),
            const Offset(0.5, 0.5),
            const Offset(0.6, 0.5),
            const Offset(0.7, 0.5),
          ],
        ],
        strokeDirections: [
          'Draw a horizontal line at the top from left to right',
          'Draw a vertical line on the left from top to bottom',
          'Draw a horizontal line at the bottom from left to right',
          'Draw a vertical line on the right from top to bottom',
          'Draw a horizontal line through the middle from left to right',
        ],
      ),
      JapaneseCharacter(
        character: '月',
        romanization: 'tsuki/getsu',
        meaning: 'moon, month',
        type: 'kanji',
        jlptLevel: 5,
        strokeOrder: [
          // Top horizontal stroke
          [
            const Offset(0.2, 0.2),
            const Offset(0.3, 0.2),
            const Offset(0.4, 0.2),
            const Offset(0.5, 0.2),
            const Offset(0.6, 0.2),
            const Offset(0.7, 0.2),
            const Offset(0.8, 0.2),
          ],
          // Left vertical stroke
          [
            const Offset(0.2, 0.2),
            const Offset(0.2, 0.3),
            const Offset(0.2, 0.4),
            const Offset(0.2, 0.5),
            const Offset(0.2, 0.6),
            const Offset(0.2, 0.7),
            const Offset(0.2, 0.8),
          ],
          // Bottom horizontal stroke
          [
            const Offset(0.2, 0.8),
            const Offset(0.3, 0.8),
            const Offset(0.4, 0.8),
            const Offset(0.5, 0.8),
            const Offset(0.6, 0.8),
            const Offset(0.7, 0.8),
            const Offset(0.8, 0.8),
          ],
          // Right vertical stroke
          [
            const Offset(0.8, 0.2),
            const Offset(0.8, 0.3),
            const Offset(0.8, 0.4),
            const Offset(0.8, 0.5),
            const Offset(0.8, 0.6),
            const Offset(0.8, 0.7),
            const Offset(0.8, 0.8),
          ],
          // Middle horizontal stroke
          [
            const Offset(0.3, 0.5),
            const Offset(0.4, 0.5),
            const Offset(0.5, 0.5),
            const Offset(0.6, 0.5),
            const Offset(0.7, 0.5),
          ],
        ],
        strokeDirections: [
          'Draw a horizontal line at the top from left to right',
          'Draw a vertical line on the left from top to bottom',
          'Draw a horizontal line at the bottom from left to right',
          'Draw a vertical line on the right from top to bottom',
          'Draw a horizontal line through the middle from left to right',
        ],
      ),
    ];
  }

  static List<JapaneseCharacter> getAllCharacters() {
    List<JapaneseCharacter> allCharacters = [];
    allCharacters.addAll(getHiragana());
    allCharacters.addAll(getKatakana());
    allCharacters.addAll(getBasicKanji());
    return allCharacters;
  }

  static JapaneseCharacter getCharacterByValue(String character) {
    return getAllCharacters().firstWhere(
      (element) => element.character == character,
      orElse: () => getAllCharacters().first,
    );
  }
}

