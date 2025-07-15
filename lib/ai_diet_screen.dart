import 'package:flutter/material.dart';
import 'services/gemini_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/user_service.dart';

class AIDietScreen extends StatefulWidget {
  final String? initialPrompt;
  const AIDietScreen({super.key, this.initialPrompt});
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
  bool _planSaved = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      promptController.text = widget.initialPrompt!;
    }
  }

  // New: Show dialog to ask user questions
  Future<void> _showPromptDialog() async {
    final ageController = TextEditingController();
    String gender = 'Male';
    String activity = 'Low';
    String diet = 'No preference';
    String goal = 'Lose weight';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Tell us about yourself'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Age'),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: gender,
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) => gender = val ?? 'Male',
                  decoration: InputDecoration(labelText: 'Gender'),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: activity,
                  items: ['Low', 'Moderate', 'High']
                      .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                      .toList(),
                  onChanged: (val) => activity = val ?? 'Low',
                  decoration: InputDecoration(labelText: 'Activity Level'),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: diet,
                  items: ['No preference', 'Vegetarian', 'Vegan', 'Halal', 'Kosher']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) => diet = val ?? 'No preference',
                  decoration: InputDecoration(labelText: 'Dietary Preference'),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: goal,
                  items: ['Lose weight', 'Maintain weight', 'Gain muscle', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) => goal = val ?? 'Lose weight',
                  decoration: InputDecoration(labelText: 'Goal'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'age': ageController.text,
                  'gender': gender,
                  'activity': activity,
                  'diet': diet,
                  'goal': goal,
                });
              },
              child: Text('Continue'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      // Generate summary sentence
      final age = result['age']?.isNotEmpty == true ? result['age'] : 'unknown age';
      final gender = result['gender'] ?? 'unspecified';
      final activity = result['activity'] ?? 'unspecified';
      final diet = result['diet'] ?? 'no preference';
      final goal = result['goal'] ?? 'unspecified';
      final summary =
          'I am a $age-year-old $gender, my activity level is $activity, my dietary preference is $diet, and my goal is to $goal.';
      setState(() {
        promptController.text = summary;
      });
    }
  }

  // Modified: Only show dialog if prompt is empty
  Future<void> _handleGeneratePlan() async {
    if (promptController.text.trim().isEmpty) {
      await _showPromptDialog();
      if (promptController.text.trim().isEmpty) {
        setState(() {
          errorMessage = 'Please enter your fitness goal';
        });
        return;
      }
    }
    await _generateDietPlan();
  }

  Future<void> _savePlan() async {
    if (generatedPlan == null || _currentUser == null) return;

    final dietData = {
      'plan': generatedPlan!,
      'createdAt': Timestamp.now(),
      'source': 'AI-Generated'
    };

    try {
      // Check for duplicate plan
      final existingPlans = await _userService.getDietPlans(_currentUser.uid);
      final alreadyExists = existingPlans.any((plan) =>
        (plan['plan'] as String?)?.trim() == generatedPlan!.trim()
      );
      if (alreadyExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This plan is already saved.'),
            backgroundColor: Colors.orange.shade600,
          ),
        );
        return;
      }
      await _userService.addDietPlan(_currentUser.uid, dietData);
      setState(() { _planSaved = true; });
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
      _planSaved = false;
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
    Future<bool> _onWillPop() async {
      if (generatedPlan != null && !_planSaved) {
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 0),
            contentPadding: EdgeInsets.fromLTRB(24, 16, 24, 0),
            actionsPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Unsaved Plan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.orange.shade800,
                      fontFamily: 'Montserrat',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have a generated diet plan that is not saved.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontFamily: 'Montserrat',
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Are you sure you want to leave? Your plan will be lost.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.red.shade700,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  textStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, color: Colors.green.shade700),
                    SizedBox(width: 4),
                    Text('Stay'),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: Icon(Icons.exit_to_app, color: Colors.white),
                label: Text('Leave', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  textStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                ),
              ),
            ],
          ),
        );
        return shouldLeave ?? false;
      }
      return true;
    }
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      appBar: AppBar(
        title: Text("AI Diet Plan"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () async {
                if (await _onWillPop()) {
                  Navigator.of(context).maybePop();
                }
              },
            ),
          ),
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
                            onPressed: isLoading ? null : _handleGeneratePlan,
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
      ),
    );
  }
}
