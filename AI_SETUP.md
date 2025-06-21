# Google Gemini API Setup Guide

## Getting Your Google Gemini API Key

1.  **Visit Google AI Studio**: Go to [https://makersuite.google.com/app/apikey](https://makersuite.google.com/app/apikey)

2.  **Sign In**: Sign in with your Google account.

3.  **Create API Key**:
    *   Click on "**Create API key in new project**".
    *   A new API key will be generated for you. Copy this key.

## Configuring the App

1.  **Open the config file**: Navigate to `lib/config/api_config.dart`

2.  **Replace the placeholder**: Paste your Gemini API key in place of `YOUR_GEMINI_API_KEY_HERE`:
    ```dart
    static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
    ```

3.  **Save the file**: The app is now ready to generate AI-powered diet plans using Google's Gemini API.

## Usage

1.  **Run the app**: Use `flutter run` to start the application.
2.  **Navigate to AI Diet Plan**: Go to the AI Diet Plan screen from the dashboard.
3.  **Enter your goal**: Describe what you want to achieve (e.g., "I want to gain muscle and lose fat").
4.  **Generate plan**: Click "Generate Plan" and wait for the AI to create your personalized diet plan.

## Troubleshooting

*   **API Key Issues**: Ensure you have copied the entire API key correctly and that there are no extra spaces.
*   **Check API Restrictions**: In the Google Cloud Console for your project, make sure there are no restrictions on the API key that would prevent your app from using it.
*   **Enable the API**: Ensure the "Generative Language API" or a similar service is enabled for your project in the Google Cloud Console. 