# Model Assets Directory

This directory contains the trained TensorFlow Lite model files for Japanese character recognition.

## Required Files

To enable real AI-powered character recognition, place these files here:

1. **`japanese_character_model.tflite`** - The trained TensorFlow Lite model
2. **`japanese_character_labels.txt`** - Character labels (one per line)

## How to Get These Files

1. **Train your own model:**

   - Follow the `MODEL_TRAINING_GUIDE.md` in the project root
   - Use the training scripts in `model_training/` directory

2. **Use a pre-trained model:**
   - Download a compatible model from a trusted source
   - Ensure it matches the expected input/output format

## Model Specifications

- **Input:** 64x64 grayscale image
- **Output:** 71 Japanese characters (Hiragana + Katakana)
- **Format:** TensorFlow Lite (.tflite)
- **Size:** <5MB recommended

## Fallback Behavior

If these files are not present, the app will:

- Use rule-based character recognition
- Display mock confidence scores
- Still provide useful feedback to users

## Testing

To test if your model is working:

1. Place the model files in this directory
2. Run the Flutter app
3. Draw a Japanese character
4. Check if you get real confidence scores instead of mock ones
