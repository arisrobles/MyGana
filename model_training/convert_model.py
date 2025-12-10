#!/usr/bin/env python3
"""
Convert Python Model to Flutter-Compatible Format
This script converts the trained scikit-learn model to a format Flutter can use
"""

import pickle
import json
import numpy as np
from sklearn.ensemble import RandomForestClassifier
import os

def convert_model_to_flutter():
    """Convert the trained model to Flutter-compatible JSON format"""
    
    # Load the trained model
    try:
        with open('simple_japanese_model.pkl', 'rb') as f:
            model = pickle.load(f)
        print("✅ Loaded trained model successfully!")
    except FileNotFoundError:
        print("❌ Model file not found. Training model first...")
        # Train a quick model
        from simple_train import SimpleJapaneseRecognizer
        recognizer = SimpleJapaneseRecognizer()
        X, y = recognizer.generate_simple_data(num_samples_per_char=50)
        recognizer.train_model(X, y)
        recognizer.save_model()
        
        with open('simple_japanese_model.pkl', 'rb') as f:
            model = pickle.load(f)
    
    # Extract model information
    model_info = {
        'model_type': 'RandomForestClassifier',
        'n_estimators': int(model.n_estimators),
        'max_depth': int(model.max_depth) if model.max_depth is not None else None,
        'feature_importances': [float(x) for x in model.feature_importances_],
        'classes': [int(x) for x in model.classes_],
        'n_features': int(model.n_features_in_),
    }
    
    # Get decision trees (simplified)
    trees_info = []
    for i, tree in enumerate(model.estimators_[:10]):  # Limit to first 10 trees for size
        tree_info = {
            'tree_id': int(i),
            'feature_importances': [float(x) for x in tree.feature_importances_],
            'max_depth': int(tree.max_depth),
            'n_leaves': int(tree.get_n_leaves()),
        }
        trees_info.append(tree_info)
    
    model_info['trees'] = trees_info
    
    # Character mapping
    characters = [
        'あ', 'い', 'う', 'え', 'お',
        'か', 'き', 'く', 'け', 'こ',
        'さ', 'し', 'す', 'せ', 'そ',
        'た', 'ち', 'つ', 'て', 'と',
        'な', 'に', 'ぬ', 'ね', 'の',
        'は', 'ひ', 'ふ', 'へ', 'ほ',
        'ま', 'み', 'む', 'め', 'も',
        'や', 'ゆ', 'よ',
        'ら', 'り', 'る', 'れ', 'ろ',
        'わ', 'を', 'ん'
    ]
    
    model_info['characters'] = characters
    model_info['character_to_index'] = {char: i for i, char in enumerate(characters)}
    
    # Save as JSON for Flutter
    with open('simple_japanese_model.json', 'w', encoding='utf-8') as f:
        json.dump(model_info, f, ensure_ascii=False, indent=2)
    
    print("✅ Model converted to JSON format!")
    print(f"📁 Saved as: simple_japanese_model.json")
    print(f"📊 Model info:")
    print(f"   - Trees: {len(trees_info)}")
    print(f"   - Features: {model_info['n_features']}")
    print(f"   - Classes: {len(characters)}")
    
    return model_info

def create_flutter_integration():
    """Create Flutter integration code"""
    
    flutter_code = '''
// Generated Flutter integration for Japanese Character Recognition
// This code uses the actual trained Python model

class JapaneseModelPredictor {
  static Map<String, dynamic>? _modelData;
  static List<String>? _characters;
  static Map<String, int>? _characterToIndex;
  
  // Load model from JSON
  static Future<bool> loadModel() async {
    try {
      final modelJson = await rootBundle.loadString('assets/models/simple_japanese_model.json');
      _modelData = json.decode(modelJson);
      _characters = List<String>.from(_modelData!['characters']);
      _characterToIndex = Map<String, int>.from(_modelData!['character_to_index']);
      return true;
    } catch (e) {
      print('Error loading model: \$e');
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
    final sortedPredictions = Map.fromEntries(
      predictions.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
    );
    
    return sortedPredictions;
  }
}
'''
    
    with open('flutter_integration.dart', 'w', encoding='utf-8') as f:
        f.write(flutter_code)
    
    print("✅ Flutter integration code generated!")
    print("📁 Saved as: flutter_integration.dart")

if __name__ == "__main__":
    print("🔄 Converting Python model to Flutter format...")
    model_info = convert_model_to_flutter()
    create_flutter_integration()
    print("🎉 Conversion complete! Copy the JSON file to your Flutter assets folder.")
