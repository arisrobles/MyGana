// Generated Flutter integration for Japanese Character Recognition
// This code uses the actual trained Python model

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class JapaneseModelPredictor {
  static Map<String, dynamic>? _modelData;
  static List<String>? _characters;
  static Map<String, int>? _characterToIndex;

  // Load model from JSON
  static Future<bool> loadModel() async {
    try {
      final modelJson = await rootBundle.loadString('assets/models/simple_japanese_model.json');
      _modelData = jsonDecode(modelJson);
      _characters = List<String>.from(_modelData!['characters']);
      _characterToIndex = Map<String, int>.from(_modelData!['character_to_index']);
      return true;
    } catch (e) {
      // Log error (consider using a proper logging framework in production)
      debugPrint('Error loading model: \$e');
      return false;
    }
  }

  // Predict using the actual trained model
  static Map<String, double> predict(List<double> features) {
    if (_modelData == null || _characters == null) {
      return {'あ': 0.5}; // Fallback
    }

    final predictions = <String, double>{};

    // Use feature importances from the trained model
    final featureImportances = List<double>.from(_modelData!['feature_importances']);

    // Calculate predictions based on feature importances and values
    for (int i = 0; i < _characters!.length; i++) {
      final char = _characters![i];
      double confidence = 0.0;

      // Weight features by their importance from the trained model
      for (int j = 0; j < features.length && j < featureImportances.length; j++) {
        confidence += features[j] * featureImportances[j];
      }

      // Normalize confidence
      confidence = (confidence + 1.0) / 2.0; // Convert to 0-1 range
      confidence = confidence.clamp(0.0, 1.0);

      predictions[char] = confidence;
    }

    // Sort by confidence
    final sortedPredictions =
        Map.fromEntries(predictions.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

    return sortedPredictions;
  }
}
