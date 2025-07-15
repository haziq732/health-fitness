import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import '../dashboard_screen.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/admin_service.dart';
import '../register_screen.dart';
import '../widgets/welcome_dialog.dart';
import '../admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  
  bool _isDarkMode = false;
  bool _showPassword = false;
  bool _rememberMe = false;
  bool _isEmailValid = true;
  final bool _isFormSubmitted = false;
  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;
  bool _isLoading = false;
  
  late AnimationController _particleController;
  late AnimationController _formAnimationController;
  late Animation<double> _formAnimation;
  
  final List<Particle> _particles = [];
  Timer? _particleTimer;

  @override
  void initState() {
    super.initState();
    
    _particleController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _formAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _formAnimation = CurvedAnimation(
      parent: _formAnimationController,
      curve: Curves.easeOutBack,
    );
    
    _emailFocusNode.addListener(() {
      setState(() {
        _isEmailFocused = _emailFocusNode.hasFocus;
      });
    });
    
    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });
    
    _formAnimationController.forward();
    _initializeParticles();
    _startParticleAnimation();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _particleController.dispose();
    _formAnimationController.dispose();
    _particleTimer?.cancel();
    super.dispose();
  }

  void _initializeParticles() {
    _particles.clear();
    for (int i = 0; i < 50; i++) {
      _particles.add(Particle());
    }
  }

  void _startParticleAnimation() {
    _particleTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          for (var particle in _particles) {
            particle.update();
          }
        });
      }
    });
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _handleEmailChange(String value) {
    setState(() {
      if (value.isNotEmpty) {
        _isEmailValid = _validateEmail(value);
      } else {
        _isEmailValid = true;
      }
    });
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _showPassword = !_showPassword;
    });
  }

  void _handleSubmit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authService = AuthService();
      final userService = UserService();
      final adminService = AdminService();
      
      final userCredential = await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (userCredential?.user != null) {
        await userService.checkAndCreateUserDocument(userCredential!.user!);
        await userService.updateLastLogin(userCredential.user!.uid);

        // Check if user is admin
        final isAdmin = await adminService.isAdmin();

        if (mounted) {
          if (isAdmin) {
            // Admin users go directly to admin dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminScreen()),
            );
          } else {
            // Regular users check if they're new and show welcome dialog if needed
            final userData = await userService.getUserData(userCredential.user!.uid);
            final bool isNewUser = userData?['isNewUser'] ?? false;

            if (isNewUser) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => WelcomeDialog(user: userCredential.user!),
              );
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => DashboardScreen()),
            );
          }
        }
      } else {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Login failed. Please try again.')),
            );
         }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'An unknown error occurred.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = _isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1a1a1a) : const Color(0xFFf8fafc),
      body: Stack(
        children: [
          // Animated Background with Particles
          CustomPaint(
            size: size,
            painter: ParticlePainter(
              particles: _particles,
              isDark: isDark,
            ),
          ),
          
          // Theme Toggle Button
          Positioned(
            top: 60,
            right: 20,
            child: GestureDetector(
              onTap: _toggleDarkMode,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2),
                  ),
                ),
                child: Icon(
                  isDark ? Icons.wb_sunny : Icons.nightlight_round,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
                ),
              ),
            ),
          ),
          
          // Login Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ScaleTransition(
                scale: _formAnimation,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2a2a2a) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isDark 
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please sign in to continue',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Email Field
                      _buildAnimatedTextField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        label: 'Email Address',
                        hint: 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                        isFocused: _isEmailFocused,
                        hasValue: _emailController.text.isNotEmpty,
                        isValid: _isEmailValid,
                        onChanged: _handleEmailChange,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      
                      // Password Field
                      _buildPasswordField(isDark),
                      const SizedBox(height: 20),
                      
                      // Remember Me & Forgot Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                activeColor: Colors.blue,
                              ),
                              Text(
                                'Remember me',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              // Handle forgot password
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading 
                            ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Separator
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[400])),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or continue with',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey[400])),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Social Login Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSocialButton(Icons.g_mobiledata, Colors.red, isDark),
                          _buildSocialButton(Icons.flutter_dash, Colors.blue, isDark),
                          _buildSocialButton(Icons.link, Colors.blue[700]!, isDark),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Sign Up Link
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => RegisterScreen()),
                            );
                          },
                          child: Text.rich(
                            TextSpan(
                              text: 'Don\'t have an account? ',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 14,
                              ),
                              children: const [
                                TextSpan(
                                  text: 'Sign up',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required bool isFocused,
    required bool hasValue,
    required bool isValid,
    required Function(String) onChanged,
    required bool isDark,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF3a3a3a) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused 
                ? Colors.blue 
                : (!isValid && hasValue) 
                  ? Colors.red 
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isFocused 
                    ? Colors.blue 
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: keyboardType,
                onChanged: onChanged,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: isFocused || hasValue ? null : hint,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        if (!isValid && hasValue)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              'Please enter a valid email',
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF3a3a3a) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isPasswordFocused ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Password',
                style: TextStyle(
                  fontSize: 12,
                  color: _isPasswordFocused 
                    ? Colors.blue 
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: !_showPassword,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: _isPasswordFocused || _passwordController.text.isNotEmpty ? null : 'Enter your password',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _togglePasswordVisibility,
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(IconData icon, Color color, bool isDark) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3a3a3a) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
}

class Particle {
  double x = 0;
  double y = 0;
  double size = 0;
  double speedX = 0;
  double speedY = 0;
  Color color = Colors.transparent;

  Particle() {
    reset();
  }

  void reset() {
    x = math.Random().nextDouble() * 1000;
    y = math.Random().nextDouble() * 2000;
    size = math.Random().nextDouble() * 3 + 1;
    speedX = (math.Random().nextDouble() - 0.5) * 0.5;
    speedY = (math.Random().nextDouble() - 0.5) * 0.5;
    color = Colors.blue.withOpacity(math.Random().nextDouble() * 0.3);
  }

  void update() {
    x += speedX;
    y += speedY;

    if (x > 1000) x = 0;
    if (x < 0) x = 1000;
    if (y > 2000) y = 0;
    if (y < 0) y = 2000;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final bool isDark;

  ParticlePainter({required this.particles, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      paint.color = isDark 
        ? Colors.white.withOpacity(0.1)
        : Colors.blue.withOpacity(0.1);
      
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 