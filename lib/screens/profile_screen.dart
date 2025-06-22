import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import '../image_viewer_screen.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _auth = FirebaseAuth.instance;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _goalController = TextEditingController();
  
  bool _isLoading = true;
  double _bmi = 0.0;
  XFile? _selectedImageFile;
  Uint8List? _imageBytes;
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userData = await _userService.getUserData(user.uid);
        if (userData != null && userData['profile'] != null) {
          final profile = userData['profile'];
          _nameController.text = profile['name'] ?? '';
          _ageController.text = (profile['age'] ?? 0).toString();
          _weightController.text = (profile['weight'] ?? 0.0).toString();
          _heightController.text = (profile['height'] ?? 0.0).toString();
          _goalController.text = profile['fitnessGoal'] ?? '';
          if (mounted) {
            setState(() {
              _profileImageUrl = profile['profileImageUrl'];
              if (_profileImageUrl != null) {
                _imageBytes = base64Decode(_profileImageUrl!);
              }
            });
          }
          _calculateBmi();
        }
      } catch (e) {
        _showErrorSnackBar('Failed to load user data: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    final user = _auth.currentUser;
    if (user == null) {
      _showErrorSnackBar('User not authenticated.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      String? imageBase64;
      if (_imageBytes != null) {
        imageBase64 = base64Encode(_imageBytes!);
      }

      final Map<String, dynamic> profileData = {
        'name': _nameController.text,
        'age': int.tryParse(_ageController.text) ?? 0,
        'weight': double.tryParse(_weightController.text) ?? 0.0,
        'height': double.tryParse(_heightController.text) ?? 0.0,
        'fitnessGoal': _goalController.text,
        'profileImageUrl': imageBase64,
      };

      await _userService.updateUserProfile(user.uid, profileData);

      if (mounted) {
        setState(() {
          if (imageBase64 != null) {
            _profileImageUrl = imageBase64;
          }
          _selectedImageFile = null;
        });
      }

      _showSuccessSnackBar('Profile updated successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to save profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateBmi() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final height = double.tryParse(_heightController.text) ?? 0;
    if (weight > 0 && height > 0) {
      setState(() {
        _bmi = weight / ((height / 100) * (height / 100));
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageFile = image;
        _imageBytes = bytes;
      });
    }
  }
  
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImageViewerScreen()),
              );
            },
            tooltip: 'View Stored Image',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Header and Avatar
                    _buildHeader(),
                    
                    const SizedBox(height: 64),
                    
                    // Form Fields
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildTextField(controller: _nameController, label: 'Name'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(controller: _ageController, label: 'Age', keyboardType: TextInputType.number)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField(controller: _weightController, label: 'Weight (kg)', keyboardType: TextInputType.number, onChanged: (_) => _calculateBmi())),
                            ],
                          ),
                          const SizedBox(height: 16),
                           Row(
                            children: [
                              Expanded(child: _buildTextField(controller: _heightController, label: 'Height (cm)', keyboardType: TextInputType.number, onChanged: (_) => _calculateBmi())),
                              const SizedBox(width: 16),
                              Expanded(child: _buildBmiDisplay()),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(controller: _goalController, label: 'Fitness Goal', maxLines: 3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          height: 144,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEEAECA), Color(0xFF94BBE9)],
            ),
          ),
        ),
        Positioned(
          top: 144 - 48,
          child: GestureDetector(
            onTap: _pickImage,
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 45,
                backgroundImage: _imageBytes != null
                    ? MemoryImage(_imageBytes!)
                    : (_profileImageUrl != null
                        ? MemoryImage(base64Decode(_profileImageUrl!))
                        : const NetworkImage('https://github.com/shadcn.png')) as ImageProvider,
                child: _imageBytes == null && _profileImageUrl == null
                    ? const Icon(Icons.person, size: 48)
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBmiDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BMI', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            _bmi > 0 ? _bmi.toStringAsFixed(2) : 'N/A',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a value';
        }
        return null;
      },
    );
  }
} 