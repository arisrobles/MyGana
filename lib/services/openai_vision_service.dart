import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nihongo_japanese_app/config/openai_config.dart';

class OpenAIVisionService {
  /// Test if the API key is working with a simple text request
  static Future<bool> testApiKey() async {
    try {
      debugPrint('🧪 Testing OpenAI API key...');

      final response = await http.post(
        Uri.parse(OpenAIConfig.baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
        },
        body: jsonEncode({
          'model': OpenAIConfig.model,
          'messages': [
            {
              'role': 'user',
              'content': 'Say "API test successful" if you can read this.',
            },
          ],
          'max_tokens': 50,
          'temperature': 0.1,
        }),
      );

      debugPrint('🧪 Test response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        debugPrint('🧪 Test response: $content');
        debugPrint('✅ API key is working!');
        return true;
      } else {
        debugPrint('❌ API key test failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ API key test error: $e');
      return false;
    }
  }

  /// Compare user's handwritten character with the target character using OpenAI Vision API
  static Future<RecognitionResult> compareCharacter({
    required String base64Image,
    required String targetCharacter,
    required String characterType, // 'hiragana' or 'katakana'
    String? referenceImageBase64, // Optional reference character image
  }) async {
    try {
      debugPrint('🔍 OpenAI Vision: Analyzing character "$targetCharacter"');
      debugPrint('📸 Handwritten image size: ${base64Image.length} characters');
      debugPrint('📸 Reference image size: ${referenceImageBase64?.length ?? 0} characters');

      final prompt = _buildPrompt(targetCharacter, characterType);

      // Count images being sent
      final imageCount = 1 + (referenceImageBase64 != null ? 1 : 0);
      debugPrint('📤 Sending $imageCount images to OpenAI API');

      // Prepare request body
      final requestBody = {
        'model': OpenAIConfig.model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': prompt,
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/png;base64,$base64Image',
                },
              },
              // Add reference image if available
              if (referenceImageBase64 != null)
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/png;base64,$referenceImageBase64',
                  },
                },
            ],
          },
        ],
        'max_tokens': OpenAIConfig.maxTokens,
        'temperature': OpenAIConfig.temperature,
      };

      debugPrint('🌐 Making API request to: ${OpenAIConfig.baseUrl}');
      debugPrint('🔑 Using API key: ${OpenAIConfig.apiKey.substring(0, 20)}...');
      debugPrint('🤖 Using model: ${OpenAIConfig.model}');
      debugPrint('📝 Request body size: ${jsonEncode(requestBody).length} characters');

      final response = await http.post(
        Uri.parse(OpenAIConfig.baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        debugPrint('✅ API call successful!');
        final data = jsonDecode(response.body);

        // Check if we have the expected structure
        if (data['choices'] == null || data['choices'].isEmpty) {
          debugPrint('❌ No choices in response: $data');
          return _createErrorResult(targetCharacter, 'No choices in API response');
        }

        final content = data['choices'][0]['message']['content'] as String;
        debugPrint('🤖 Raw OpenAI Response: $content');
        debugPrint('📊 Response length: ${content.length} characters');

        final result = _parseResponse(content, targetCharacter);
        debugPrint(
            '🎯 Parsed result - isCorrect: ${result.isCorrect}, confidence: ${result.confidence}');

        return result;
      } else {
        debugPrint('❌ OpenAI API Error: ${response.statusCode}');
        debugPrint('❌ Error response body: ${response.body}');
        debugPrint('❌ Error response headers: ${response.headers}');

        // Try to parse error details
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
          debugPrint('❌ API Error message: $errorMessage');
          return _createErrorResult(targetCharacter, 'API Error: $errorMessage');
        } catch (e) {
          return _createErrorResult(
              targetCharacter, 'API Error: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      debugPrint('❌ OpenAI Vision Error: $e');
      return _createErrorResult(targetCharacter, 'Error: $e');
    }
  }

  /// Build enhanced prompt with character-specific details
  static String _buildPrompt(String targetCharacter, String characterType) {
    final characterDetails = _getCharacterSpecificDetails(targetCharacter);

    return '''
You are an expert Japanese calligraphy teacher. I will show you a comparison image with two characters side by side:

- **LEFT SIDE**: A handwritten character drawn by a student
- **RIGHT SIDE**: The correct reference character "$targetCharacter"

${characterDetails}

EVALUATION CRITERIA:
1. **Shape Recognition (40%)** - Does the handwritten character resemble the reference?
2. **Stroke Count (30%)** - Does it have the correct number of strokes?
3. **Proportions (20%)** - Are the size relationships reasonable?
4. **Stroke Quality (10%)** - Is the execution clean?

REASONABLE STANDARDS:
- The handwritten character should be recognizable as "$targetCharacter"
- Stroke count should match the reference
- Overall shape should be similar to the reference
- Minor variations in curves, angles, and proportions are acceptable
- If the character is very close to the reference, consider it correct even with small differences
- Be generous with scoring - aim for 70-90% scores for reasonably good attempts

Respond with ONLY this JSON format (no other text):
{
  "isCorrect": true/false,
  "confidence": 0.0-1.0,
  "accuracyScore": 0-100,
  "shapeScore": 0-100,
  "strokeScore": 0-100,
  "proportionScore": 0-100,
  "qualityScore": 0-100,
  "feedback": "Brief, specific feedback",
  "issues": ["list of problems"],
  "strengths": ["what was done well"],
  "suggestions": ["improvement tips"]
}

Be encouraging and fair. Focus on helping the student improve while recognizing good effort.
''';
  }

  /// Get character-specific details for enhanced recognition
  static String _getCharacterSpecificDetails(String character) {
    final details = {
      // Hiragana characters
      'あ': 'Three strokes: horizontal line, vertical line with hook, horizontal line below',
      'い': 'Two strokes: short diagonal down-right, longer diagonal down-right',
      'う': 'Two strokes: short horizontal, curved line down and up',
      'え': 'Two strokes: horizontal line, curved line with hook',
      'お': 'Three strokes: horizontal, vertical with hook, horizontal below',
      'か': 'Two strokes: horizontal line, vertical line with hook',
      'き': 'Three strokes: horizontal, vertical, horizontal below',
      'く': 'One stroke: curved line down-right',
      'け': 'Two strokes: vertical line, horizontal line with hook',
      'こ': 'Two strokes: horizontal line, horizontal line below',
      'さ': 'Two strokes: horizontal, vertical with hook',
      'し': 'One stroke: vertical line with slight curve',
      'す': 'Two strokes: horizontal, curved line down-right',
      'せ': 'Two strokes: horizontal, vertical with hook',
      'そ': 'One stroke: curved line with multiple bends',
      'た': 'Two strokes: horizontal, vertical with hook',
      'ち': 'Two strokes: horizontal, curved line down-right',
      'つ': 'One stroke: horizontal line',
      'て': 'One stroke: horizontal line with hook',
      'と': 'Two strokes: horizontal, vertical with hook',
      'な': 'Two strokes: horizontal, vertical with hook',
      'に': 'Two strokes: vertical, horizontal with hook',
      'ぬ': 'Two strokes: horizontal, curved line down-right',
      'ね': 'Two strokes: horizontal, vertical with hook',
      'の': 'One stroke: curved line forming circle',
      'は': 'Two strokes: horizontal, vertical with hook',
      'ひ': 'One stroke: curved line with multiple bends',
      'ふ': 'Two strokes: horizontal, curved line down-right',
      'へ': 'One stroke: curved line down-right',
      'ほ': 'Two strokes: horizontal, vertical with hook',
      'ま': 'Two strokes: horizontal, vertical with hook',
      'み': 'Two strokes: horizontal, vertical with hook',
      'む': 'Two strokes: horizontal, curved line down-right',
      'め': 'Two strokes: horizontal, curved line down-right',
      'も': 'Two strokes: horizontal, vertical with hook',
      'や': 'Two strokes: horizontal, vertical with hook',
      'ゆ': 'Two strokes: horizontal, curved line down-right',
      'よ': 'Two strokes: horizontal, vertical with hook',
      'ら': 'Two strokes: horizontal, vertical with hook',
      'り': 'Two strokes: vertical, vertical',
      'る': 'One stroke: curved line with multiple bends',
      'れ': 'Two strokes: horizontal, vertical with hook',
      'ろ': 'One stroke: curved line with multiple bends',
      'わ': 'Two strokes: horizontal, vertical with hook',
      'を': 'Two strokes: horizontal, vertical with hook',
      'ん': 'Two strokes: horizontal, vertical with hook',

      // Katakana characters
      'ア': 'Two strokes: horizontal line, diagonal down-right',
      'イ': 'Two strokes: vertical line, diagonal down-right',
      'ウ': 'Two strokes: horizontal line, curved line down-right',
      'エ': 'Two strokes: horizontal line, vertical line',
      'オ': 'Three strokes: horizontal, vertical, horizontal below',
      'カ': 'Two strokes: horizontal line, vertical line with hook',
      'キ': 'Two strokes: horizontal line, vertical line',
      'ク': 'Two strokes: horizontal line, curved line down-right',
      'ケ': 'Two strokes: horizontal line, vertical line with hook',
      'コ': 'Two strokes: horizontal line, vertical line',
      'サ': 'Two strokes: horizontal line, vertical line with hook',
      'シ': 'Two strokes: horizontal line, curved line down-right',
      'ス': 'Two strokes: horizontal line, curved line down-right',
      'セ': 'Two strokes: horizontal line, vertical line with hook',
      'ソ': 'Two strokes: horizontal line, diagonal down-right',
      'タ': 'Two strokes: horizontal line, vertical line with hook',
      'チ': 'Two strokes: horizontal line, curved line down-right',
      'ツ': 'Two strokes: horizontal line, diagonal down-right',
      'テ': 'Two strokes: horizontal line, vertical line with hook',
      'ト': 'Two strokes: horizontal line, vertical line with hook',
      'ナ': 'Two strokes: horizontal line, vertical line with hook',
      'ニ': 'Two strokes: horizontal line, horizontal line below',
      'ヌ': 'Two strokes: horizontal line, curved line down-right',
      'ネ': 'Two strokes: horizontal line, vertical line with hook',
      'ノ': 'One stroke: diagonal down-right',
      'ハ': 'Two strokes: diagonal down-right, diagonal down-left',
      'ヒ': 'Two strokes: horizontal line, vertical line',
      'フ': 'Two strokes: horizontal line, curved line down-right',
      'ヘ': 'One stroke: curved line down-right',
      'ホ': 'Two strokes: horizontal line, vertical line with hook',
      'マ': 'Two strokes: horizontal line, curved line down-right',
      'ミ': 'Two strokes: horizontal line, vertical line',
      'ム': 'Two strokes: horizontal line, curved line down-right',
      'メ': 'Two strokes: horizontal line, diagonal down-right',
      'モ': 'Two strokes: horizontal line, vertical line with hook',
      'ヤ': 'Two strokes: horizontal line, vertical line with hook',
      'ユ': 'Two strokes: horizontal line, curved line down-right',
      'ヨ': 'Two strokes: horizontal line, vertical line',
      'ラ': 'Two strokes: horizontal line, vertical line with hook',
      'リ': 'Two strokes: vertical line, vertical line',
      'ル': 'Two strokes: horizontal line, curved line down-right',
      'レ': 'Two strokes: horizontal line, vertical line with hook',
      'ロ': 'Two strokes: horizontal line, vertical line',
      'ワ': 'Two strokes: horizontal line, curved line down-right',
      'ヲ': 'Two strokes: horizontal line, vertical line with hook',
      'ン': 'Two strokes: horizontal line, curved line down-right',
    };

    return details[character] ??
        'Standard $character character - analyze stroke count, shape, and proportions carefully';
  }

  /// Parse OpenAI response into RecognitionResult
  static RecognitionResult _parseResponse(String content, String targetCharacter) {
    try {
      debugPrint('🔍 Parsing response for character: $targetCharacter');

      // Extract JSON from the response (it might have extra text)
      final jsonStart = content.indexOf('{');
      final jsonEnd = content.lastIndexOf('}') + 1;

      if (jsonStart == -1 || jsonEnd == 0) {
        debugPrint('❌ No JSON found in response');
        throw Exception('No JSON found in response');
      }

      final jsonString = content.substring(jsonStart, jsonEnd);
      debugPrint('📝 Extracted JSON: $jsonString');

      final data = jsonDecode(jsonString);

      final isCorrect = data['isCorrect'] as bool? ?? false;
      final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
      final accuracyScore = (data['accuracyScore'] as num?)?.toDouble() ?? 0.0;

      // Enhanced scoring breakdown
      final shapeScore = (data['shapeScore'] as num?)?.toDouble() ?? 0.0;
      final strokeScore = (data['strokeScore'] as num?)?.toDouble() ?? 0.0;
      final proportionScore = (data['proportionScore'] as num?)?.toDouble() ?? 0.0;
      final qualityScore = (data['qualityScore'] as num?)?.toDouble() ?? 0.0;

      final feedback = data['feedback'] as String? ?? 'No feedback provided';
      final issues = List<String>.from(data['issues'] ?? []);
      final strengths = List<String>.from(data['strengths'] ?? []);
      final suggestions = List<String>.from(data['suggestions'] ?? []);

      debugPrint('✅ Parsed successfully - isCorrect: $isCorrect, confidence: $confidence');

      // Enhanced feedback with detailed scoring
      String enhancedFeedback = feedback;

      // Add scoring breakdown
      enhancedFeedback += '\n\n📊 Detailed Scores:';
      enhancedFeedback += '\n• Shape Recognition: ${shapeScore.toInt()}%';
      enhancedFeedback += '\n• Stroke Count & Order: ${strokeScore.toInt()}%';
      enhancedFeedback += '\n• Proportional Accuracy: ${proportionScore.toInt()}%';
      enhancedFeedback += '\n• Stroke Quality: ${qualityScore.toInt()}%';

      if (strengths.isNotEmpty) {
        enhancedFeedback += '\n\n✅ Strengths: ${strengths.join(', ')}';
      }
      if (issues.isNotEmpty) {
        enhancedFeedback += '\n\n❌ Issues: ${issues.join(', ')}';
      }
      if (suggestions.isNotEmpty) {
        enhancedFeedback += '\n\n💡 Suggestions: ${suggestions.join(', ')}';
      }

      return RecognitionResult(
        recognizedCharacter: targetCharacter,
        confidence: confidence.clamp(0.0, 1.0),
        alternativeMatches: [],
        isCorrect: isCorrect,
        englishTranslation: _getEnglishTranslation(targetCharacter),
        feedback: enhancedFeedback,
        accuracyScore: accuracyScore.clamp(0.0, 100.0),
        shapeScore: shapeScore.clamp(0.0, 100.0),
        strokeScore: strokeScore.clamp(0.0, 100.0),
        proportionScore: proportionScore.clamp(0.0, 100.0),
        qualityScore: qualityScore.clamp(0.0, 100.0),
      );
    } catch (e) {
      debugPrint('❌ Error parsing OpenAI response: $e');
      debugPrint('Raw response: $content');

      // Fallback: try to extract basic info from the response
      final isCorrect =
          content.toLowerCase().contains('correct') && !content.toLowerCase().contains('incorrect');
      final confidence = isCorrect ? 0.8 : 0.3;

      return RecognitionResult(
        recognizedCharacter: targetCharacter,
        confidence: confidence,
        alternativeMatches: [],
        isCorrect: isCorrect,
        englishTranslation: _getEnglishTranslation(targetCharacter),
        feedback:
            'AI Analysis: ${content.length > 200 ? content.substring(0, 200) + '...' : content}',
        accuracyScore: confidence * 100,
        shapeScore: confidence * 100,
        strokeScore: confidence * 100,
        proportionScore: confidence * 100,
        qualityScore: confidence * 100,
      );
    }
  }

  /// Create error result
  static RecognitionResult _createErrorResult(String targetCharacter, String error) {
    return RecognitionResult(
      recognizedCharacter: targetCharacter,
      confidence: 0.0,
      alternativeMatches: [],
      isCorrect: false,
      englishTranslation: _getEnglishTranslation(targetCharacter),
      feedback: '❌ Recognition Error: $error',
      accuracyScore: 0.0,
      shapeScore: 0.0,
      strokeScore: 0.0,
      proportionScore: 0.0,
      qualityScore: 0.0,
    );
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
}

/// Recognition result class
class RecognitionResult {
  final String recognizedCharacter;
  final double? confidence;
  final List<String> alternativeMatches;
  final bool isCorrect;
  final String englishTranslation;
  final String feedback;
  final double? accuracyScore;

  // Detailed scoring breakdown
  final double? shapeScore;
  final double? strokeScore;
  final double? proportionScore;
  final double? qualityScore;

  RecognitionResult({
    required this.recognizedCharacter,
    this.confidence,
    this.alternativeMatches = const [],
    required this.isCorrect,
    required this.englishTranslation,
    required this.feedback,
    this.accuracyScore,
    this.shapeScore,
    this.strokeScore,
    this.proportionScore,
    this.qualityScore,
  });
}
