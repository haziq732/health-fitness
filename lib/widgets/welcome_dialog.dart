import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class WelcomeDialog extends StatefulWidget {
  final User user;

  const WelcomeDialog({super.key, required this.user});

  @override
  _WelcomeDialogState createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog> {
  final PageController _pageController = PageController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _goalController = TextEditingController();

  double _bmi = 0.0;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _calculateBmi() {
    final double weight = double.tryParse(_weightController.text) ?? 0;
    final double height = double.tryParse(_heightController.text) ?? 0;
    if (weight > 0 && height > 0) {
      setState(() {
        _bmi = weight / ((height / 100) * (height / 100));
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    final double weight = double.tryParse(_weightController.text) ?? 0;
    final double height = double.tryParse(_heightController.text) ?? 0;
    final String goal = _goalController.text;

    final userData = {
      'weight': weight,
      'height': height,
      'fitnessGoal': goal,
    };
    
    final userService = UserService();
    await userService.updateUserProfile(widget.user.uid, userData);
    await userService.update(widget.user.uid, {'isNewUser': false});

    setState(() => _isLoading = false);

    if(mounted) {
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildHealthDetailsPage(),
            _buildGoalPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthDetailsPage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Welcome!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('Let\'s set up your profile.'),
        const SizedBox(height: 16),
        TextField(
          controller: _weightController,
          decoration: const InputDecoration(labelText: 'Weight (kg)'),
          keyboardType: TextInputType.number,
          onChanged: (_) => _calculateBmi(),
        ),
        TextField(
          controller: _heightController,
          decoration: const InputDecoration(labelText: 'Height (cm)'),
          keyboardType: TextInputType.number,
          onChanged: (_) => _calculateBmi(),
        ),
        const SizedBox(height: 16),
        if (_bmi > 0) Text('Your BMI: ${_bmi.toStringAsFixed(2)}'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
            );
          },
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildGoalPage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('What\'s Your Goal?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _goalController,
          decoration: const InputDecoration(labelText: 'e.g., Lose weight, build muscle'),
        ),
        const SizedBox(height: 24),
        _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Save and Continue'),
              ),
      ],
    );
  }
}
