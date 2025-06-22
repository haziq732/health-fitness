import 'package:flutter/material.dart';
import 'services/gemini_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/user_service.dart';

class AIDietScreen extends StatefulWidget {
  @override
  _AIDietScreenState createState() => _AIDietScreenState();
}

class _AIDietScreenState extends State<AIDietScreen> {
  final TextEditingController promptController = TextEditingController();
  final UserService _userService = UserService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String? generatedPlan;
  bool isLoading = false;
  String? errorMessage;

  Future<void> _savePlan() async {
    if (generatedPlan == null || _currentUser == null) return;

    final dietData = {
      'plan': generatedPlan!,
      'createdAt': Timestamp.now(),
      'source': 'AI-Generated'
    };

    try {
      await _userService.addDietPlan(_currentUser!.uid, dietData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Diet plan saved to your profile!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save plan: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _generateDietPlan() async {
    if (promptController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please enter your fitness goal';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      generatedPlan = null;
    });

    try {
      final plan = await GeminiService.generateDietPlan(promptController.text.trim());
      setState(() {
        generatedPlan = plan;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AI Diet Plan"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
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
              // Input Section
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.smart_toy, size: 40, color: Colors.green.shade700),
                      SizedBox(height: 16),
                      Text(
                        "AI-Powered Diet Planning",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: promptController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Describe your goal (e.g., 'I want to gain muscle and lose fat', 'I need a vegetarian diet for weight loss')",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.flag),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: isLoading ? null : _generateDietPlan,
                          icon: isLoading 
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(Icons.auto_awesome),
                          label: Text(
                            isLoading ? "Generating..." : "Generate Plan",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Error Message
              if (errorMessage != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Generated Plan Section
              if (generatedPlan != null) ...[
                Expanded(
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.restaurant_menu, color: Colors.green.shade700),
                              SizedBox(width: 8),
                              Text(
                                "Your Personalized Diet Plan",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                generatedPlan!,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _savePlan,
                              icon: Icon(Icons.save),
                              label: Text("Save Plan"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
