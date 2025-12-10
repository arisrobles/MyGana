#!/usr/bin/env python3
"""
Quick Start Script for Japanese Character Recognition Training
Run this to quickly train a model with synthetic data
"""

import os
import sys
import subprocess

def check_requirements():
    """Check if required packages are installed"""
    try:
        import tensorflow as tf
        import numpy as np
        import matplotlib.pyplot as plt
        import sklearn
        import cv2
        from PIL import Image
        print("✅ All required packages are installed!")
        return True
    except ImportError as e:
        print(f"❌ Missing package: {e}")
        print("Please install requirements: pip install -r requirements.txt")
        return False

def run_quick_training():
    """Run quick training with synthetic data"""
    print("🚀 Starting quick training...")
    
    try:
        # Run the quick training script
        result = subprocess.run([sys.executable, 'quick_train.py'], 
                              capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Training completed successfully!")
            print("📁 Model files created:")
            print("   - quick_model.h5 (Keras model)")
            print("   - quick_model.tflite (TensorFlow Lite model)")
            print("\n🎯 Next steps:")
            print("   1. Copy quick_model.tflite to assets/models/ in your Flutter project")
            print("   2. Hot restart your Flutter app")
            print("   3. Test the recognition accuracy!")
        else:
            print("❌ Training failed:")
            print(result.stderr)
            
    except Exception as e:
        print(f"❌ Error running training: {e}")

def run_full_training():
    """Run full training with real data"""
    print("🚀 Starting full training...")
    
    # Check if training data exists
    if not os.path.exists('training_data_export.json'):
        print("❌ No training data found!")
        print("Please export training data from your Flutter app first.")
        return
    
    try:
        # Run the full training script
        result = subprocess.run([sys.executable, 'train_japanese_model.py'], 
                              capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Full training completed successfully!")
            print("📁 Model files created:")
            print("   - best_model.h5 (Keras model)")
            print("   - japanese_character_model.tflite (TensorFlow Lite model)")
            print("   - training_history.png (Training graphs)")
        else:
            print("❌ Training failed:")
            print(result.stderr)
            
    except Exception as e:
        print(f"❌ Error running training: {e}")

def main():
    """Main function"""
    print("🇯🇵 Japanese Character Recognition Training")
    print("=" * 50)
    
    # Check requirements
    if not check_requirements():
        return
    
    print("\nChoose training option:")
    print("1. Quick training (synthetic data) - 2 minutes")
    print("2. Full training (real data) - 10+ minutes")
    print("3. Generate synthetic data only")
    
    choice = input("\nEnter choice (1-3): ").strip()
    
    if choice == '1':
        run_quick_training()
    elif choice == '2':
        run_full_training()
    elif choice == '3':
        print("🚀 Generating synthetic data...")
        subprocess.run([sys.executable, 'collect_training_data.py'])
    else:
        print("❌ Invalid choice!")

if __name__ == "__main__":
    main()
