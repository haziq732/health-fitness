import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/user_service.dart';
import 'services/nutrition_service.dart';

class FoodLogScreen extends StatefulWidget {
  const FoodLogScreen({super.key});

  @override
  _FoodLogScreenState createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends State<FoodLogScreen> {
  final TextEditingController foodController = TextEditingController();
  final UserService _userService = UserService();
  final NutritionixService _nutritionixService = NutritionixService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _foodLogs = [];

  @override
  void initState() {
    super.initState();
    _loadFoodLogs();
  }

  Future<void> _loadFoodLogs() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        List<Map<String, dynamic>> logs = await _userService.getFoodLogs(user.uid);
        // Sort logs by timestamp, newest first
        logs.sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));
        setState(() {
          _foodLogs = logs;
        });
      } catch (e) {
        _showErrorSnackBar('Failed to load food logs: $e');
      }
    }
  }

  Future<void> _submitFood() async {
    if (foodController.text.isEmpty) {
      _showErrorSnackBar('Please enter a food description');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get nutrition data from Nutritionix API
      final nutritionData = await _nutritionixService.getNutritionData(foodController.text.trim());

      // Prepare food data to be saved in Firestore
      final foodData = {
        'food': foodController.text.trim(),
        'calories': nutritionData['calories'],
        'protein': nutritionData['protein'],
        'carbs': nutritionData['carbs'],
        'fats': nutritionData['fats'],
        'timestamp': Timestamp.now(), // Use client-side timestamp
      };

      await _userService.addFoodLog(user.uid, foodData);

      foodController.clear();
      _showSuccessSnackBar('Food logged successfully!');
      // After successful submission, reload logs to show the new entry
      await _loadFoodLogs();
    } catch (e) {
      _showErrorSnackBar('Failed to log food: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Log Food Intake")),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade100, Colors.green.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Input Card
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.fastfood, size: 40, color: Colors.green.shade700),
                      SizedBox(height: 10),
                      TextField(
                        controller: foodController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: "e.g., 1 large apple and 2 slices of bread",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.restaurant_menu),
                        ),
                      ),
                      SizedBox(height: 16),
                      _isLoading
                          ? CircularProgressIndicator(color: Colors.green.shade700)
                          : ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                              ),
                              onPressed: _submitFood,
                              icon: Icon(Icons.send),
                              label: Text("Submit", style: TextStyle(fontSize: 16)),
                            ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Food History
              Expanded(
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Food History",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: _foodLogs.isEmpty
                            ? Center(
                                child: Text(
                                  "No food logs yet. Add a food above!",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _foodLogs.length,
                                itemBuilder: (context, index) {
                                  final log = _foodLogs[index];
                                  final timestamp = log['timestamp'] as Timestamp?;
                                  final date = timestamp?.toDate();
                                  final formattedDate = date != null
                                      ? DateFormat('MMM d, yyyy - hh:mm a').format(date)
                                      : 'No date';

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: Text(
                                        '${(log['calories'] ?? 0.0).toStringAsFixed(0)}',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                      ),
                                    ),
                                    title: Text(log['food'] ?? 'Unknown food', style: TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      'P: ${log['protein']?.toStringAsFixed(1)}g, C: ${log['carbs']?.toStringAsFixed(1)}g, F: ${log['fats']?.toStringAsFixed(1)}g\n$formattedDate',
                                      style: TextStyle(color: Colors.grey.shade700),
                                    ),
                                    isThreeLine: true,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}