import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();
  bool _isLoading = false;
  final bool _newsletter = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar("Passwords do not match.");
      return;
    }
    
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
        _showErrorSnackBar("Please fill in all fields.");
        return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _authService.signUpWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      if (userCredential?.user != null) {
        await _authService.updateUserProfile(_nameController.text.trim());
      }

      if (mounted) {
        _showSuccessSnackBar('Account created successfully! Please login.');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color foregroundColor = isDarkMode ? Colors.white : Colors.black;
    Color mutedForegroundColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    Color cardColor = isDarkMode ? const Color(0xFF2a2a2a) : Colors.white;
    Color backgroundColor = isDarkMode ? const Color(0xFF1a1a1a) : const Color(0xFFf8fafc);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.heartPulse, size: 40, color: Colors.blue),
                const SizedBox(height: 8),
                Text(
                  'Create new account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: foregroundColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  color: cardColor,
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Name',
                          hint: 'Your Name',
                          isDarkMode: isDarkMode
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'test@gmail.com',
                          keyboardType: TextInputType.emailAddress,
                          isDarkMode: isDarkMode
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: '••••••••',
                          obscureText: true,
                          isDarkMode: isDarkMode
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm password',
                          hint: '••••••••',
                          obscureText: true,
                          isDarkMode: isDarkMode
                        ),
                        
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Create account'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(fontSize: 12, color: mutedForegroundColor),
                              children: [
                                const TextSpan(text: 'By signing in, you agree to our '),
                                _buildLinkSpan(context, 'Terms of use', () {}),
                                const TextSpan(text: ' and '),
                                _buildLinkSpan(context, 'Privacy policy', () {}),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text.rich(
                  TextSpan(
                    style: TextStyle(color: mutedForegroundColor),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      _buildLinkSpan(context, 'Sign in', () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _buildLinkSpan(BuildContext context, String text, VoidCallback onTap) {
    return TextSpan(
      text: text,
      style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
      recognizer: TapGestureRecognizer()..onTap = onTap,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    required bool isDarkMode
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}