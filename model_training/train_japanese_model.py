#!/usr/bin/env python3
"""
Japanese Character Recognition Model Training
Using TensorFlow/Keras for accurate character recognition
"""

import os
import json
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
import cv2
from PIL import Image
import base64
import io

class JapaneseCharacterTrainer:
    def __init__(self):
        self.model = None
        self.label_encoder = LabelEncoder()
        self.input_size = 64
        self.num_classes = 46  # Basic hiragana characters
        
        # Character mapping
        self.character_to_index = {
            'あ': 0, 'い': 1, 'う': 2, 'え': 3, 'お': 4,
            'か': 5, 'き': 6, 'く': 7, 'け': 8, 'こ': 9,
            'さ': 10, 'し': 11, 'す': 12, 'せ': 13, 'そ': 14,
            'た': 15, 'ち': 16, 'つ': 17, 'て': 18, 'と': 19,
            'な': 20, 'に': 21, 'ぬ': 22, 'ね': 23, 'の': 24,
            'は': 25, 'ひ': 26, 'ふ': 27, 'へ': 28, 'ほ': 29,
            'ま': 30, 'み': 31, 'む': 32, 'め': 33, 'も': 34,
            'や': 35, 'ゆ': 36, 'よ': 37,
            'ら': 38, 'り': 39, 'る': 40, 'れ': 41, 'ろ': 42,
            'わ': 43, 'を': 44, 'ん': 45,
        }
        
        self.index_to_character = {v: k for k, v in self.character_to_index.items()}
        
    def load_training_data(self, data_path):
        """Load training data from JSON file"""
        print(f"Loading training data from {data_path}...")
        
        with open(data_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        images = []
        labels = []
        
        for entry in data['data']:
            try:
                # Decode base64 image
                image_data = base64.b64decode(entry['imageData'])
                image = Image.open(io.BytesIO(image_data))
                
                # Convert to grayscale and resize
                image = image.convert('L')
                image = image.resize((self.input_size, self.input_size))
                
                # Convert to numpy array and normalize
                image_array = np.array(image) / 255.0
                images.append(image_array)
                
                # Get character label
                character = entry['character']
                if character in self.character_to_index:
                    labels.append(self.character_to_index[character])
                else:
                    print(f"Unknown character: {character}")
                    
            except Exception as e:
                print(f"Error processing entry: {e}")
                continue
        
        print(f"Loaded {len(images)} training samples")
        return np.array(images), np.array(labels)
    
    def create_model(self):
        """Create CNN model for character recognition"""
        print("Creating CNN model...")
        
        model = keras.Sequential([
            # Input layer
            layers.Input(shape=(self.input_size, self.input_size, 1)),
            
            # First convolutional block
            layers.Conv2D(32, (3, 3), activation='relu'),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            layers.Dropout(0.25),
            
            # Second convolutional block
            layers.Conv2D(64, (3, 3), activation='relu'),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            layers.Dropout(0.25),
            
            # Third convolutional block
            layers.Conv2D(128, (3, 3), activation='relu'),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            layers.Dropout(0.25),
            
            # Fourth convolutional block
            layers.Conv2D(256, (3, 3), activation='relu'),
            layers.BatchNormalization(),
            layers.Dropout(0.25),
            
            # Global average pooling
            layers.GlobalAveragePooling2D(),
            
            # Dense layers
            layers.Dense(512, activation='relu'),
            layers.BatchNormalization(),
            layers.Dropout(0.5),
            
            layers.Dense(256, activation='relu'),
            layers.BatchNormalization(),
            layers.Dropout(0.5),
            
            # Output layer
            layers.Dense(self.num_classes, activation='softmax')
        ])
        
        # Compile model
        model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=0.001),
            loss='sparse_categorical_crossentropy',
            metrics=['accuracy']
        )
        
        self.model = model
        print("Model created successfully!")
        return model
    
    def train_model(self, X, y, epochs=100, batch_size=32, validation_split=0.2):
        """Train the model"""
        print(f"Training model for {epochs} epochs...")
        
        # Split data
        X_train, X_val, y_train, y_val = train_test_split(
            X, y, test_size=validation_split, random_state=42, stratify=y
        )
        
        # Data augmentation
        datagen = keras.preprocessing.image.ImageDataGenerator(
            rotation_range=10,
            width_shift_range=0.1,
            height_shift_range=0.1,
            zoom_range=0.1,
            horizontal_flip=False,  # Don't flip Japanese characters
            fill_mode='nearest'
        )
        
        # Callbacks
        callbacks = [
            keras.callbacks.EarlyStopping(
                monitor='val_accuracy',
                patience=10,
                restore_best_weights=True
            ),
            keras.callbacks.ReduceLROnPlateau(
                monitor='val_loss',
                factor=0.5,
                patience=5,
                min_lr=1e-7
            ),
            keras.callbacks.ModelCheckpoint(
                'best_model.h5',
                monitor='val_accuracy',
                save_best_only=True
            )
        ]
        
        # Train model
        history = self.model.fit(
            datagen.flow(X_train, y_train, batch_size=batch_size),
            steps_per_epoch=len(X_train) // batch_size,
            epochs=epochs,
            validation_data=(X_val, y_val),
            callbacks=callbacks,
            verbose=1
        )
        
        return history
    
    def evaluate_model(self, X_test, y_test):
        """Evaluate model performance"""
        print("Evaluating model...")
        
        # Load best model
        self.model = keras.models.load_model('best_model.h5')
        
        # Evaluate
        test_loss, test_accuracy = self.model.evaluate(X_test, y_test, verbose=0)
        
        print(f"Test Accuracy: {test_accuracy:.4f}")
        print(f"Test Loss: {test_loss:.4f}")
        
        # Predictions
        predictions = self.model.predict(X_test)
        predicted_classes = np.argmax(predictions, axis=1)
        
        # Confusion matrix
        from sklearn.metrics import confusion_matrix, classification_report
        
        cm = confusion_matrix(y_test, predicted_classes)
        
        # Print classification report
        target_names = [self.index_to_character[i] for i in range(self.num_classes)]
        print("\nClassification Report:")
        print(classification_report(y_test, predicted_classes, target_names=target_names))
        
        return test_accuracy, cm
    
    def plot_training_history(self, history):
        """Plot training history"""
        plt.figure(figsize=(12, 4))
        
        plt.subplot(1, 2, 1)
        plt.plot(history.history['accuracy'], label='Training Accuracy')
        plt.plot(history.history['val_accuracy'], label='Validation Accuracy')
        plt.title('Model Accuracy')
        plt.xlabel('Epoch')
        plt.ylabel('Accuracy')
        plt.legend()
        
        plt.subplot(1, 2, 2)
        plt.plot(history.history['loss'], label='Training Loss')
        plt.plot(history.history['val_loss'], label='Validation Loss')
        plt.title('Model Loss')
        plt.xlabel('Epoch')
        plt.ylabel('Loss')
        plt.legend()
        
        plt.tight_layout()
        plt.savefig('training_history.png')
        plt.show()
    
    def convert_to_tflite(self, output_path='japanese_character_model.tflite'):
        """Convert model to TensorFlow Lite format"""
        print("Converting model to TensorFlow Lite...")
        
        # Load best model
        self.model = keras.models.load_model('best_model.h5')
        
        # Convert to TensorFlow Lite
        converter = tf.lite.TFLiteConverter.from_keras_model(self.model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        # Convert
        tflite_model = converter.convert()
        
        # Save
        with open(output_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"TensorFlow Lite model saved to {output_path}")
        
        # Test the converted model
        interpreter = tf.lite.Interpreter(model_path=output_path)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print("TensorFlow Lite model details:")
        print(f"Input shape: {input_details[0]['shape']}")
        print(f"Output shape: {output_details[0]['shape']}")
        
        return output_path
    
    def generate_synthetic_data(self, num_samples_per_class=100):
        """Generate synthetic training data for characters with few samples"""
        print("Generating synthetic training data...")
        
        # This would generate additional training data
        # For now, we'll use the existing data
        pass

def main():
    """Main training function"""
    print("Japanese Character Recognition Model Training")
    print("=" * 50)
    
    # Initialize trainer
    trainer = JapaneseCharacterTrainer()
    
    # Load training data
    data_path = 'training_data_export.json'
    if not os.path.exists(data_path):
        print(f"Training data file {data_path} not found!")
        print("Please export training data from the Flutter app first.")
        return
    
    X, y = trainer.load_training_data(data_path)
    
    if len(X) < 50:
        print(f"Not enough training data ({len(X)} samples). Need at least 50 samples.")
        return
    
    # Reshape data for CNN
    X = X.reshape(-1, trainer.input_size, trainer.input_size, 1)
    
    print(f"Training data shape: {X.shape}")
    print(f"Labels shape: {y.shape}")
    print(f"Number of classes: {len(np.unique(y))}")
    
    # Create model
    model = trainer.create_model()
    model.summary()
    
    # Train model
    history = trainer.train_model(X, y, epochs=50, batch_size=16)
    
    # Plot training history
    trainer.plot_training_history(history)
    
    # Evaluate model
    test_accuracy, cm = trainer.evaluate_model(X, y)
    
    # Convert to TensorFlow Lite
    tflite_path = trainer.convert_to_tflite()
    
    print("\nTraining completed successfully!")
    print(f"Final test accuracy: {test_accuracy:.4f}")
    print(f"TensorFlow Lite model saved to: {tflite_path}")

if __name__ == "__main__":
    main()