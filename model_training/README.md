# Japanese Character Recognition Model Training

This directory contains Python scripts for training a TensorFlow/Keras model for Japanese character recognition.

## Files

- `train_japanese_model.py` - Main training script with full CNN architecture
- `quick_train.py` - Simplified training script for quick testing
- `collect_training_data.py` - Data collection and synthetic data generation
- `requirements.txt` - Python dependencies

## Setup

1. Install Python dependencies:

```bash
pip install -r requirements.txt
```

2. Export training data from Flutter app:
   - Go to Model Training screen in the app
   - Tap "Export Data" button
   - This creates `training_data_export.json`

## Training

### Quick Training (for testing)

```bash
python quick_train.py
```

### Full Training (for production)

```bash
python train_japanese_model.py
```

### Generate Synthetic Data

```bash
python collect_training_data.py
```

## Model Architecture

The model uses a CNN architecture:

- Input: 64x64 grayscale images
- Convolutional layers with batch normalization
- Dropout for regularization
- Global average pooling
- Dense layers with dropout
- Output: 46 classes (basic hiragana characters)

## Training Process

1. **Data Loading**: Loads training data from JSON export
2. **Preprocessing**: Converts images to 64x64 grayscale, normalizes to 0-1
3. **Data Augmentation**: Rotation, shifting, zooming
4. **Training**: Uses Adam optimizer with early stopping
5. **Evaluation**: Tests on validation set
6. **Export**: Converts to TensorFlow Lite format

## Model Integration

After training, the TensorFlow Lite model should be placed in:

- `assets/models/japanese_character_model.tflite` (for assets)
- Or documents directory (for dynamic loading)

## Expected Results

With sufficient training data (1000+ samples):

- Training accuracy: 95%+
- Validation accuracy: 90%+
- Real-world accuracy: 85%+

## Troubleshooting

### Not enough training data

- Run `collect_training_data.py` to generate synthetic data
- Practice more characters in the Flutter app
- Export data regularly

### Low accuracy

- Increase training epochs
- Add more training data
- Adjust model architecture
- Check data quality

### Model not loading in Flutter

- Ensure model file exists in correct location
- Check TensorFlow Lite compatibility
- Verify model input/output shapes
