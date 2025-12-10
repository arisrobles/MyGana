#!/usr/bin/env python3
"""
Test the trained model to verify it's working correctly
"""

import pickle
import json
import numpy as np
from simple_train import SimpleJapaneseRecognizer

def test_model():
    """Test the trained model"""
    print("🧪 Testing the trained model...")
    
    # Load the model
    try:
        with open('simple_japanese_model.pkl', 'rb') as f:
            model = pickle.load(f)
        print("✅ Model loaded successfully!")
    except FileNotFoundError:
        print("❌ Model not found. Training first...")
        recognizer = SimpleJapaneseRecognizer()
        X, y = recognizer.generate_simple_data(num_samples_per_char=50)
        recognizer.train_model(X, y)
        recognizer.save_model()
        
        with open('simple_japanese_model.pkl', 'rb') as f:
            model = pickle.load(f)
    
    # Test predictions
    recognizer = SimpleJapaneseRecognizer()
    
    print("\n🎯 Testing character predictions:")
    test_characters = ['あ', 'い', 'う', 'え', 'お', 'か', 'き', 'く', 'け', 'こ']
    
    for char in test_characters:
        # Generate features for this character
        features = recognizer.create_character_features(char)
        
        # Predict using the model
        prediction = model.predict([features])[0]
        confidence = model.predict_proba([features])[0].max()
        
        predicted_char = recognizer.characters[prediction]
        
        print(f"   {char} -> {predicted_char} (confidence: {confidence:.3f})")
    
    print(f"\n📊 Model Statistics:")
    print(f"   - Accuracy: {model.score(recognizer.generate_simple_data()[0], recognizer.generate_simple_data()[1]):.3f}")
    print(f"   - Features: {model.n_features_in_}")
    print(f"   - Trees: {model.n_estimators}")
    print(f"   - Classes: {len(model.classes_)}")
    
    # Test feature importances
    print(f"\n🔍 Top 10 Most Important Features:")
    feature_importances = model.feature_importances_
    top_features = np.argsort(feature_importances)[-10:][::-1]
    
    for i, feature_idx in enumerate(top_features):
        print(f"   {i+1}. Feature {feature_idx}: {feature_importances[feature_idx]:.4f}")
    
    print("\n✅ Model testing complete!")

if __name__ == "__main__":
    test_model()
