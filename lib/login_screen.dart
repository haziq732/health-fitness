// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'register_screen.dart';
// import 'dashboard_screen.dart';
// import 'custom_textfield.dart';
// import 'custom_button.dart';
// import 'services/auth_service.dart';
// import 'services/user_service.dart';
//
// class LoginScreen extends StatefulWidget {
//   @override
//   _LoginScreenState createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen> {
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   final AuthService _authService = AuthService();
//   final UserService _userService = UserService();
//   bool _isLoading = false;
//
//   Future<void> _signIn() async {
//     if (emailController.text.isEmpty || passwordController.text.isEmpty) {
//       _showErrorSnackBar('Please fill in all fields');
//       return;
//     }
//
//     setState(() {
//       _isLoading = true;
//     });
//
//     try {
//       // Sign in with Firebase Auth
//       UserCredential? userCredential = await _authService.signInWithEmailAndPassword(
//         emailController.text.trim(),
//         passwordController.text,
//       );
//      
//       if (userCredential?.user != null) {
//         // Ensure the user document exists in Firestore before proceeding.
//         await _userService.checkAndCreateUserDocument(userCredential!.user!);
//
//         // Update last login time in Firestore
//         await _userService.updateLastLogin(userCredential.user!.uid);
//        
//         if (mounted) {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) => DashboardScreen()),
//           );
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         _showErrorSnackBar(e.toString());
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Colors.green.shade200, Colors.green.shade600],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: Center(
//           child: Card(
//             elevation: 8,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.fitness_center, size: 48, color: Colors.green.shade700),
//                   SizedBox(height: 10),
//                   Text("Login", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
//                   SizedBox(height: 20),
//                   CustomTextField(
//                     controller: emailController,
//                     hintText: "Email",
//                     icon: Icons.email,
//                   ),
//                   SizedBox(height: 10),
//                   CustomTextField(
//                     controller: passwordController,
//                     hintText: "Password",
//                     obscureText: true,
//                     icon: Icons.lock,
//                   ),
//                   SizedBox(height: 20),
//                   _isLoading
//                       ? CircularProgressIndicator(color: Colors.green.shade700)
//                       : CustomButton(
//                           label: "Login",
//                           onPressed: _signIn,
//                         ),
//                   SizedBox(height: 10),
//                   TextButton(
//                     onPressed: _isLoading ? null : () {
//                       Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen()));
//                     },
//                     child: Text("Don't have an account? Register", style: TextStyle(color: Colors.green.shade700)),
//                   )
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }