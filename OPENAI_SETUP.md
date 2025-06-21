# OpenAI API Setup Guide

## Getting Your OpenAI API Key

1. **Visit OpenAI Platform**: Go to [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)

2. **Sign In/Up**: Create an account or sign in to your existing OpenAI account

3. **Create API Key**: 
   - Click "Create new secret key"
   - Give it a name (e.g., "Flutter Health App")
   - Copy the generated API key (it starts with `sk-`)

4. **Add Credits**: Make sure you have credits in your OpenAI account (new accounts get free credits)

## Configuring the App

1. **Open the config file**: Navigate to `lib/config/api_config.dart`

2. **Replace the placeholder**: Change `YOUR_OPENAI_API_KEY_HERE` with your actual API key:
   ```dart
   static const String openaiApiKey = 'sk-your-actual-api-key-here';
   ```

3. **Save the file**: The app will now be able to generate AI-powered diet plans

## Usage

1. **Run the app**: Use `flutter run` to start the application

2. **Navigate to AI Diet Plan**: Go to the AI Diet Plan screen from the dashboard

3. **Enter your goal**: Describe what you want to achieve (e.g., "I want to gain muscle and lose fat")

4. **Generate plan**: Click "Generate Plan" and wait for the AI to create your personalized diet plan

## Features

- **Personalized Plans**: AI generates diet plans based on your specific goals
- **Professional Guidance**: Uses nutritionist-level prompts for accurate advice
- **Structured Output**: Plans include breakfast, lunch, dinner, and snacks
- **Practical Details**: Includes portion sizes and cooking instructions

## Security Notes

- Never commit your API key to version control
- Consider using environment variables for production apps
- Monitor your OpenAI usage to avoid unexpected charges

## Troubleshooting

- **"Invalid API key"**: Make sure you've copied the entire API key correctly
- **"Insufficient credits"**: Add credits to your OpenAI account
- **"Rate limit exceeded"**: Wait a moment and try again 