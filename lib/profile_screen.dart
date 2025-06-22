// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../services/user_service.dart';
// 
// class ProfileScreen extends StatefulWidget {
//   @override
//   _ProfileScreenState createState() => _ProfileScreenState();
// }
// 
// class _ProfileScreenState extends State<ProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final UserService _userService = UserService();
//   final FirebaseAuth _auth = FirebaseAuth.instance;
// 
//   // Form field controllers
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _ageController = TextEditingController();
//   final TextEditingController _weightController = TextEditingController();
//   final TextEditingController _heightController = TextEditingController();
//   final TextEditingController _goalController = TextEditingController();
// 
//   bool _isLoading = true;
//   double _bmi = 0.0;
// 
//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//   }
// 
//   Future<void> _loadUserData() async {
//     setState(() {
//       _isLoading = true;
//     });
//     final user = _auth.currentUser;
//     if (user != null) {
//       try {
//         final userData = await _userService.getUserData(user.uid);
//         if (userData != null && userData['profile'] != null) {
//           final profile = userData['profile'];
//           _nameController.text = profile['name'] ?? '';
//           _ageController.text = (profile['age'] ?? 0).toString();
//           _weightController.text = (profile['weight'] ?? 0.0).toString();
//           _heightController.text = (profile['height'] ?? 0.0).toString();
//           _goalController.text = profile['fitnessGoal'] ?? '';
//           _calculateBmi();
//         }
//       } catch (e) {
//         _showErrorSnackBar('Failed to load user data: $e');
//       }
//     }
//     setState(() {
//       _isLoading = false;
//     });
//   }
// 
//   Future<void> _saveProfile() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }
// 
//     setState(() {
//       _isLoading = true;
//     });
// 
//     final user = _auth.currentUser;
//     if (user == null) {
//       _showErrorSnackBar('User not authenticated.');
//       setState(() => _isLoading = false);
//       return;
//     }
// 
//     try {
//       final profileData = {
//         'name': _nameController.text,
//         'age': int.tryParse(_ageController.text) ?? 0,
//         'weight': double.tryParse(_weightController.text) ?? 0.0,
//         'height': double.tryParse(_heightController.text) ?? 0.0,
//         'fitnessGoal': _goalController.text,
//       };
// 
//       await _userService.updateUserProfile(user.uid, profileData);
//       _showSuccessSnackBar('Profile updated successfully!');
//     } catch (e) {
//       _showErrorSnackBar('Failed to save profile: $e');
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
// 
//   void _calculateBmi() {
//     final double weight = double.tryParse(_weightController.text) ?? 0;
//     final double height = double.tryParse(_heightController.text) ?? 0;
//     if (weight > 0 && height > 0) {
//       setState(() {
//         _bmi = weight / ((height / 100) * (height / 100));
//       });
//     } else {
//       setState(() {
//         _bmi = 0.0;
//       });
//     }
//   }
// 
//   void _showErrorSnackBar(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       content: Text(message),
//       backgroundColor: Colors.red,
//       behavior: SnackBarBehavior.floating,
//     ));
//   }
// 
//   void _showSuccessSnackBar(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       content: Text(message),
//       backgroundColor: Colors.green,
//       behavior: SnackBarBehavior.floating,
//     ));
//   }
// 
//   @override
//   void dispose() {
//     _nameController.dispose();
//     _ageController.dispose();
//     _weightController.dispose();
//     _heightController.dispose();
//     _goalController.dispose();
//     super.dispose();
//   }
// 
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("My Profile")),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [Colors.green.shade100, Colors.green.shade400],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//               ),
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.all(24.0),
//                 child: Form(
//                   key: _formKey,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       _buildTextField(_nameController, "Name", Icons.person, onChanged: (_) => setState(() {})),
//                       _buildTextField(_ageController, "Age", Icons.cake, keyboardType: TextInputType.number),
//                       _buildTextField(_weightController, "Weight (kg)", Icons.fitness_center, keyboardType: TextInputType.number, onChanged: (_) => _calculateBmi()),
//                       _buildTextField(_heightController, "Height (cm)", Icons.height, keyboardType: TextInputType.number, onChanged: (_) => _calculateBmi()),
//                       if (_bmi > 0) ...[
//                         const SizedBox(height: 10),
//                         Text('BMI: ${_bmi.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
//                         const SizedBox(height: 10),
//                       ],
//                       _buildTextField(_goalController, "My Fitness Goal", Icons.flag, maxLines: 3),
//                       const SizedBox(height: 30),
//                       ElevatedButton.icon(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.green.shade700,
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                           padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
//                         ),
//                         onPressed: _saveProfile,
//                         icon: Icon(Icons.save),
//                         label: Text("Save Profile", style: TextStyle(fontSize: 18)),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//     );
//   }
// 
//   Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, Function(String)? onChanged}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 10.0),
//       child: TextFormField(
//         controller: controller,
//         keyboardType: keyboardType,
//         maxLines: maxLines,
//         onChanged: onChanged,
//         decoration: InputDecoration(
//           labelText: label,
//           prefixIcon: Icon(icon, color: Colors.green.shade800),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//           filled: true,
//           fillColor: Colors.white70,
//         ),
//         validator: (value) {
//           if (value == null || value.isEmpty) {
//             return 'Please enter your $label';
//           }
//           return null;
//         },
//       ),
//     );
//   }
// } 