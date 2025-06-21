import 'dart:convert';
import 'package:http/http.dart' as http;

class NutritionixService {
  // IMPORTANT: In a real application, you should store these keys securely
  // (e.g., using environment variables or a secrets management service),
  // not directly in the code.
  final String _appId = '01d91f39';
  final String _appKey = '24203ae4e2b1dcb0766914f46178b3e4';
  final String _apiUrl = 'https://trackapi.nutritionix.com/v2/natural/nutrients';

  /// Fetches nutritional data for a given food query from the Nutritionix API.
  ///
  /// The [query] is a natural language string of the food eaten,
  /// e.g., "1 large apple and 2 slices of whole wheat bread".
  ///
  /// Returns a [Map] containing the total calories, protein, carbs, and fats.
  /// Throws an exception if the API call fails or if the food is not found.
  Future<Map<String, double>> getNutritionData(String query) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-app-id': _appId,
        'x-app-key': _appKey,
      },
      body: json.encode({'query': query}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final foods = data['foods'] as List<dynamic>?;

      if (foods == null || foods.isEmpty) {
        throw Exception('Food not found. Please try a different query.');
      }

      // Sum up the nutrients from all food items identified.
      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFats = 0;

      for (var food in foods) {
        totalCalories += (food['nf_calories'] ?? 0.0).toDouble();
        totalProtein += (food['nf_protein'] ?? 0.0).toDouble();
        totalCarbs += (food['nf_total_carbohydrate'] ?? 0.0).toDouble();
        totalFats += (food['nf_total_fat'] ?? 0.0).toDouble();
      }

      return {
        'calories': totalCalories,
        'protein': totalProtein,
        'carbs': totalCarbs,
        'fats': totalFats,
      };
    } else {
      // Handle API errors
      throw Exception('Failed to load nutrition data. Status code: ${response.statusCode}');
    }
  }
} 