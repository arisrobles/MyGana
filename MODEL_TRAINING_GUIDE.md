# Japanese Character Recognition Model Training Guide

This guide will help you train a real TensorFlow Lite model for Japanese character recognition, replacing the mock scores with actual AI-powered recognition.

## 🎯 Overview

The app now supports **real AI-powered character recognition** using TensorFlow Lite. This provides much more accurate results than rule-based analysis alone.

## 📋 Prerequisites

1. **Python 3.8+** installed on your computer
2. **TensorFlow 2.10+** for model training
3. **Training data** (Japanese character images)

## 🚀 Quick Start

### Step 1: Install Dependencies

```bash
cd model_training
pip install -r requirements.txt
```

### Step 2: Collect Training Data

#### Option A: Use the Data Collection Tool

```bash
python collect_training_data.py
```

This opens a drawing interface where you can:

- Draw each Japanese character
- Save multiple samples per character
- Organize data automatically

#### Option B: Use Existing Dataset

If you have a dataset of Japanese character images, organize them like this:

```
dataset/
├── あ/
│   ├── image1.png
│   ├── image2.png
│   └── ...
├── い/
│   ├── image1.png
│   └── ...
└── ...
```

### Step 3: Train the Model

```bash
python train_japanese_model.py
```

This will:

- Load your training data
- Train a CNN model
- Convert to TensorFlow Lite format
- Save `japanese_character_model.tflite` and `japanese_character_labels.txt`

### Step 4: Integrate with Flutter App

1. **Copy model files to Flutter project:**

   ```bash
   # Copy the trained model files
   cp japanese_character_model.tflite ../assets/models/
   cp japanese_character_labels.txt ../assets/models/
   ```

2. **Update pubspec.yaml:**

   ```yaml
   flutter:
     assets:
       - assets/models/
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## 📊 Model Architecture

The trained model uses a CNN architecture optimized for mobile:

```
Input: 64x64 grayscale image
├── Conv2D(32) + BatchNorm + MaxPool
├── Conv2D(64) + BatchNorm + MaxPool
├── Conv2D(128) + BatchNorm + MaxPool
├── Conv2D(256) + BatchNorm + MaxPool
├── GlobalAveragePooling2D
├── Dense(512) + Dropout(0.5)
├── Dense(256) + Dropout(0.3)
└── Dense(71) + Softmax  # 71 Japanese characters
```

## 🎯 Training Tips

### Data Quality

- **Minimum 50 images per character** for good results
- **Varied handwriting styles** - different people, different pens
- **Different sizes and positions** in the image
- **Clean, clear images** without noise

### Data Augmentation

The training script automatically applies:

- Rotation (±10°)
- Translation (±10%)
- Shear and zoom
- **No horizontal flipping** (Japanese characters shouldn't be flipped)

### Training Parameters

- **Epochs:** 50 (adjust based on your data size)
- **Batch Size:** 32
- **Learning Rate:** 0.001
- **Optimizer:** Adam

## 📈 Expected Results

With good training data, you should achieve:

- **Training accuracy:** 95%+
- **Validation accuracy:** 90%+
- **Model size:** <5MB
- **Inference time:** <100ms

## 🔧 Troubleshooting

### Common Issues

1. **"No dataset found"**

   - Make sure you have a `dataset/` folder with character subfolders
   - Each character folder should contain PNG/JPG images

2. **Low accuracy**

   - Add more training data (aim for 100+ images per character)
   - Check image quality and consistency
   - Ensure proper character labeling

3. **Model too large**

   - The script uses quantization to reduce size
   - Consider reducing model complexity if needed

4. **Slow inference**
   - Model is optimized for mobile devices
   - Consider using GPU acceleration if available

### Performance Optimization

1. **Reduce model size:**

   ```python
   # In train_japanese_model.py, modify:
   converter.optimizations = [tf.lite.Optimize.DEFAULT]
   converter.target_spec.supported_types = [tf.float16]  # Use float16
   ```

2. **Increase accuracy:**
   - Add more training data
   - Train for more epochs
   - Use data augmentation

## 📱 Integration Details

### How It Works in the App

1. **User draws character** → Strokes captured
2. **Convert to image** → 64x64 grayscale image
3. **TFLite inference** → AI model analyzes image
4. **Combine results** → 70% AI + 30% rule-based
5. **Real-time feedback** → Accurate recognition results

### Fallback System

If the TFLite model fails to load:

- App falls back to rule-based recognition
- No crashes or errors
- Still provides useful feedback

## 🎉 Success!

Once you've trained and integrated the model:

- ✅ **Real AI recognition** instead of mock scores
- ✅ **Accurate character detection**
- ✅ **Real-time feedback** as you draw
- ✅ **Professional-grade results**

## 📚 Additional Resources

- [TensorFlow Lite Documentation](https://www.tensorflow.org/lite)
- [Japanese Character Recognition Datasets](https://www.kaggle.com/datasets)
- [Model Optimization Guide](https://www.tensorflow.org/lite/performance/model_optimization)

## 🤝 Contributing

If you improve the model or find better training techniques:

1. Update the training script
2. Share your improvements
3. Help others achieve better results!

---

**Happy Training! 🚀**

Your Japanese learning app will now have real AI-powered character recognition!
