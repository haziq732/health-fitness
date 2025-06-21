import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_config.dart';

class GeminiService {
  static final GenerativeModel _model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: ApiConfig.geminiApiKey,
  );

  static Future<String> generateDietPlan(String userGoal) async {
    final prompt = '''
      You are a professional nutritionist and fitness expert.
      Create a personalized diet plan that is practical, healthy, and achievable based on the following user goal: "$userGoal".
      
      Your response must be structured and clear. Include the following sections:
      1.  **Breakfast**: Suggest specific meals and portion sizes.
      2.  **Lunch**: Suggest specific meals and portion sizes.
      3.  **Dinner**: Suggest specific meals and portion sizes.
      4.  **Snacks**: Provide 2-3 healthy snack options.
      5.  **Nutritional Tips**: Give 3 actionable tips relevant to the user's goal.

      Provide realistic portion sizes and simple cooking instructions where appropriate.
      ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text != null) {
        return response.text!;
      } else {
        throw Exception('Failed to generate diet plan: No response text.');
      }
    } catch (e) {
      throw Exception('Error connecting to Gemini API: $e');
    }
  }
} 