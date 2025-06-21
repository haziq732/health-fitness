import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'custom_textfield.dart';
import 'custom_button.dart';
import 'services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signUp() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    if (passwordController.text.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters long');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signUpWithEmailAndPassword(
        emailController.text.trim(),
        passwordController.text,
      );
      
      if (mounted) {
        _showSuccessSnackBar('Account created successfully! Please login.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade200, Colors.green.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add, size: 48, color: Colors.green.shade700),
                  SizedBox(height: 10),
                  Text("Register", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  SizedBox(height: 20),
                  CustomTextField(
                    controller: emailController,
                    hintText: "Email",
                    icon: Icons.email,
                  ),
                  SizedBox(height: 10),
                  CustomTextField(
                    controller: passwordController,
                    hintText: "Password",
                    obscureText: true,
                    icon: Icons.lock,
                  ),
                  SizedBox(height: 20),
                  _isLoading
                      ? CircularProgressIndicator(color: Colors.green.shade700)
                      : CustomButton(
                          label: "Register",
                          onPressed: _signUp,
                        ),
                  SizedBox(height: 10),
                  TextButton(
                    onPressed: _isLoading ? null : () {
                      Navigator.pop(context);
                    },
                    child: Text("Already have an account? Login", style: TextStyle(color: Colors.green.shade700)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}