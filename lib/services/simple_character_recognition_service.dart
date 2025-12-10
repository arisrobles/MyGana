import 'package:flutter/material.dart';
import 'package:nihongo_japanese_app/models/japanese_character.dart';
import 'package:nihongo_japanese_app/services/openai_vision_service.dart';
import 'package:nihongo_japanese_app/utils/image_combiner.dart';
import 'package:nihongo_japanese_app/utils/reference_character_generator.dart';
import 'package:nihongo_japanese_app/utils/stroke_to_image_converter.dart';

/// Result containing both recognition result and the images used
class RecognitionResultWithImages {
  final RecognitionResult recognitionResult;
  final String handwrittenImageBase64;
  final String? referenceImageBase64;

  RecognitionResultWithImages({
    required this.recognitionResult,
    required this.handwrittenImageBase64,
    this.referenceImageBase64,
  });
}

/// Simplified character recognition service using OpenAI Vision API
class CharacterRecognitionService {
  /// Recognize character using OpenAI Vision API
  static Future<RecognitionResult> recognizeCharacter(
    List<List<Offset>> userStrokes,
    JapaneseCharacter expectedCharacter,
  ) async {
    final result = await recognizeCharacterWithImages(userStrokes, expectedCharacter);
    return result.recognitionResult;
  }

  /// Recognize character and return both result and images
  static Future<RecognitionResultWithImages> recognizeCharacterWithImages(
    List<List<Offset>> userStrokes,
    JapaneseCharacter expectedCharacter,
  ) async {
    try {
      debugPrint('🤖 OpenAI Vision Recognition starting...');
      debugPrint('   Expected character: ${expectedCharacter.character}');
      debugPrint('   User strokes count: ${userStrokes.length}');

      // Test API key first
      final apiWorking = await OpenAIVisionService.testApiKey();
      if (!apiWorking) {
        debugPrint('❌ OpenAI API is not working! Using fallback.');
        return RecognitionResultWithImages(
          recognitionResult:
              _createFallbackResult(expectedCharacter, 'Recognition service not available'),
          handwrittenImageBase64: '',
          referenceImageBase64: null,
        );
      }

      if (userStrokes.isEmpty) {
        return RecognitionResultWithImages(
          recognitionResult: RecognitionResult(
            recognizedCharacter: expectedCharacter.character,
            confidence: 0.0,
            alternativeMatches: [],
            isCorrect: false,
            englishTranslation: _getEnglishTranslation(expectedCharacter.character),
            feedback: 'Please draw the character first! 📝',
            accuracyScore: 0.0,
            shapeScore: 0.0,
            strokeScore: 0.0,
            proportionScore: 0.0,
            qualityScore: 0.0,
          ),
          handwrittenImageBase64: '',
          referenceImageBase64: null,
        );
      }

      // Convert strokes to high-quality base64 image
      final base64Image = await StrokeToImageConverter.createHighQualityImage(
        normalizedStrokes: userStrokes,
        imageSize: const Size(512, 512),
        backgroundColor: Colors.white,
        strokeColor: Colors.black,
        strokeWidth: 12.0,
      );

      debugPrint('   Image created: ${base64Image.length} characters');

      // Generate reference character image for comparison
      String? referenceImageBase64;
      try {
        final svgPath = ReferenceCharacterGenerator.getSvgPath(
            expectedCharacter.character, expectedCharacter.type);
        referenceImageBase64 = await ReferenceCharacterGenerator.generateReferenceImage(
          character: expectedCharacter.character,
          svgPath: svgPath,
        );
        debugPrint('   Reference image generated: ${referenceImageBase64?.length ?? 0} characters');
      } catch (e) {
        debugPrint('   Warning: Could not generate reference image: $e');
      }

      // Create combined comparison image
      String? combinedImageBase64;
      if (referenceImageBase64 != null) {
        try {
          combinedImageBase64 = await ImageCombiner.createComparisonImage(
            handwrittenImageBase64: base64Image,
            referenceImageBase64: referenceImageBase64,
          );
          debugPrint('   Combined image created: ${combinedImageBase64.length} characters');
        } catch (e) {
          debugPrint('   Warning: Could not create combined image: $e');
        }
      }

      // Use OpenAI Vision API to analyze the character
      final result = await OpenAIVisionService.compareCharacter(
        base64Image: combinedImageBase64 ?? base64Image,
        targetCharacter: expectedCharacter.character,
        characterType: expectedCharacter.type,
        referenceImageBase64: null, // No longer needed since we have combined image
      );

      debugPrint('   OpenAI confidence: ${((result.confidence ?? 0.0) * 100).toStringAsFixed(1)}%');
      debugPrint('   Is correct: ${result.isCorrect}');

      return RecognitionResultWithImages(
        recognitionResult: result,
        handwrittenImageBase64: base64Image,
        referenceImageBase64: referenceImageBase64,
      );
    } catch (e) {
      debugPrint('❌ Character recognition error: $e');

      return RecognitionResultWithImages(
        recognitionResult: RecognitionResult(
          recognizedCharacter: expectedCharacter.character,
          confidence: 0.0,
          alternativeMatches: [],
          isCorrect: false,
          englishTranslation: _getEnglishTranslation(expectedCharacter.character),
          feedback: 'Recognition error: $e',
          accuracyScore: 0.0,
          shapeScore: 0.0,
          strokeScore: 0.0,
          proportionScore: 0.0,
          qualityScore: 0.0,
        ),
        handwrittenImageBase64: '',
        referenceImageBase64: null,
      );
    }
  }

  /// Get English translation for character
  static String _getEnglishTranslation(String character) {
    const translations = {
      // Hiragana
      'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
      'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
      'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so',
      'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
      'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
      'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho',
      'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
      'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
      'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
      'わ': 'wa', 'を': 'wo', 'ん': 'n',
      // Katakana
      'ア': 'a', 'イ': 'i', 'ウ': 'u', 'エ': 'e', 'オ': 'o',
      'カ': 'ka', 'キ': 'ki', 'ク': 'ku', 'ケ': 'ke', 'コ': 'ko',
      'サ': 'sa', 'シ': 'shi', 'ス': 'su', 'セ': 'se', 'ソ': 'so',
      'タ': 'ta', 'チ': 'chi', 'ツ': 'tsu', 'テ': 'te', 'ト': 'to',
      'ナ': 'na', 'ニ': 'ni', 'ヌ': 'nu', 'ネ': 'ne', 'ノ': 'no',
      'ハ': 'ha', 'ヒ': 'hi', 'フ': 'fu', 'ヘ': 'he', 'ホ': 'ho',
      'マ': 'ma', 'ミ': 'mi', 'ム': 'mu', 'メ': 'me', 'モ': 'mo',
      'ヤ': 'ya', 'ユ': 'yu', 'ヨ': 'yo',
      'ラ': 'ra', 'リ': 'ri', 'ル': 'ru', 'レ': 're', 'ロ': 'ro',
      'ワ': 'wa', 'ヲ': 'wo', 'ン': 'n',
    };

    return translations[character] ?? character;
  }

  /// Create fallback result when API is not available
  static RecognitionResult _createFallbackResult(
      JapaneseCharacter expectedCharacter, String reason) {
    return RecognitionResult(
      recognizedCharacter: expectedCharacter.character,
      confidence: 0.0,
      alternativeMatches: [],
      isCorrect: false,
      englishTranslation: _getEnglishTranslation(expectedCharacter.character),
      feedback: '❌ $reason - Please check your internet connection.',
      accuracyScore: 0.0,
      shapeScore: 0.0,
      strokeScore: 0.0,
      proportionScore: 0.0,
      qualityScore: 0.0,
    );
  }
}
