#!/usr/bin/env python3
"""
Quick Training Script for Japanese Character Recognition
Simplified version for immediate model training
"""

import os
import json
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import base64
import io
from PIL import Image
import random

def create_simple_model():
    """Create a simple CNN model"""
    model = keras.Sequential([
        layers.Input(shape=(64, 64, 1)),
        
        # Convolutional layers
        layers.Conv2D(32, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),
        
        layers.Conv2D(64, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),
        
        layers.Conv2D(128, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),
        
        # Dense layers
        layers.Flatten(),
        layers.Dense(256, activation='relu'),
        layers.Dropout(0.5),
        layers.Dense(46, activation='softmax')  # 46 hiragana characters
    ])
    
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    return model

def generate_quick_data():
    """Generate quick training data"""
    print("Generating quick training data...")
    
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
    
    character_to_index = {char: i for i, char in enumerate(characters)}
    
    # Generate synthetic data
    X = []
    y = []
    
    for char in characters:
        for _ in range(50):  # 50 samples per character
            # Create simple character image
            img = Image.new('L', (64, 64), 255)
            
            # Add some random noise to simulate different writing styles
            img_array = np.array(img)
            
            # Add character-like patterns (simplified)
            center_x, center_y = 32, 32
            
            # Simple character simulation
            if char == 'あ':
                # Draw simple 'a' shape
                img_array[center_y-10:center_y+10, center_x-5:center_x+5] = 0
                img_array[center_y-5:center_y+5, center_x-10:center_x+10] = 0
            elif char == 'い':
                # Draw simple 'i' shape
                img_array[center_y-15:center_y+15, center_x-2:center_x+2] = 0
            elif char == 'う':
                # Draw simple 'u' shape
                img_array[center_y-10:center_y+10, center_x-8:center_x-6] = 0
                img_array[center_y+8:center_y+10, center_x-8:center_x+8] = 0
            else:
                # Generic character pattern
                img_array[center_y-8:center_y+8, center_x-8:center_x+8] = random.randint(0, 100)
            
            # Add noise
            noise = np.random.normal(0, 10, img_array.shape)
            img_array = np.clip(img_array + noise, 0, 255)
            
            X.append(img_array / 255.0)
            y.append(character_to_index[char])
    
    return np.array(X), np.array(y)

def quick_train():
    """Quick training function"""
    print("Starting quick training...")
    
    # Generate data
    X, y = generate_quick_data()
    X = X.reshape(-1, 64, 64, 1)
    
    print(f"Training data shape: {X.shape}")
    print(f"Labels shape: {y.shape}")
    
    # Create model
    model = create_simple_model()
    model.summary()
    
    # Train model
    print("Training model...")
    history = model.fit(
        X, y,
        epochs=20,
        batch_size=32,
        validation_split=0.2,
        verbose=1
    )
    
    # Save model
    model.save('quick_model.h5')
    print("Model saved as 'quick_model.h5'")
    
    # Convert to TensorFlow Lite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    
    with open('quick_model.tflite', 'wb') as f:
        f.write(tflite_model)
    
    print("TensorFlow Lite model saved as 'quick_model.tflite'")
    
    # Test accuracy
    test_loss, test_accuracy = model.evaluate(X, y, verbose=0)
    print(f"Final accuracy: {test_accuracy:.4f}")
    
    return model

if __name__ == "__main__":
    quick_train()