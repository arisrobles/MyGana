# OpenAI API Setup Guide

This app uses OpenAI's Vision API for Japanese character recognition. Follow these steps to set up your API key:

## 1. Get Your OpenAI API Key

1. Go to [OpenAI Platform](https://platform.openai.com/api-keys)
2. Sign in or create an account
3. Click "Create new secret key"
4. Copy your API key (starts with `sk-proj-`)

## 2. Configure the App

1. Open `lib/config/openai_config.dart`
2. Replace `YOUR_OPENAI_API_KEY_HERE` with your actual API key:

```dart
static const String apiKey = 'sk-proj-your-actual-api-key-here';
```

## 3. Important Security Notes

- ⚠️ **Never commit your real API key to version control**
- The API key is already removed from the repository for security
- Consider using environment variables for production apps
- Keep your API key private and secure

## 4. Cost Information

- The app uses GPT-4o-mini model for cost efficiency
- Each character recognition costs approximately $0.0001-0.0005
- Monitor your usage at [OpenAI Usage Dashboard](https://platform.openai.com/usage)

## 5. Troubleshooting

If you get "Recognition service unavailable" errors:
1. Check your internet connection
2. Verify your API key is correct
3. Ensure you have sufficient OpenAI credits
4. Check the API key has vision model access

## 6. Features

- **Combined Image Analysis**: Sends both handwritten and reference characters in one image
- **Real-time Recognition**: Manual checking to control API costs
- **Detailed Feedback**: Shape, stroke, proportion, and quality scores
- **Visual Confirmation**: Shows both images being analyzed