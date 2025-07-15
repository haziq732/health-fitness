import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const EditProfileDialog({super.key, required this.profileData});

  @override
  _EditProfileDialogState createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final TextEditingController _nameController;
  late final TextEditingController _roleController;
  late final TextEditingController _locationController;
  late final TextEditingController _bioController;
  
  final int _bioMaxLength = 180;
  int _bioCharacterCount = 0;
  File? _pickedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profileData['name']);
    _roleController = TextEditingController(text: widget.profileData['role'] ?? 'Web Developer');
    _locationController = TextEditingController(text: widget.profileData['location'] ?? 'Merlimau, Malaysia');
    _bioController = TextEditingController(text: widget.profileData['bio'] ?? "I'm passionate about building user-centric applications that solve problems.");
    
    _bioCharacterCount = _bioController.text.length;
    _bioController.addListener(() {
      if(mounted) {
        setState(() {
          _bioCharacterCount = _bioController.text.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // This is temporarily disabled to resolve a build issue.
    /*
    if (_isSaving) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null && mounted) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
    */
  }

  Future<void> _saveChanges() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      // String? imageUrl;
      // if (_pickedImage != null) {
      //   imageUrl = await _userService.uploadProfileImage(user.uid, _pickedImage!);
      // }

      final updatedProfileData = {
        ...widget.profileData,
        'name': _nameController.text,
        'role': _roleController.text,
        'location': _locationController.text,
        'bio': _bioController.text,
        // if (imageUrl != null) 'profileImageUrl': imageUrl,
      };

      await _userService.updateUserProfile(user.uid, updatedProfileData);

      if (mounted) {
        Navigator.of(context).pop(true); // Pop with a success flag
      }
    } catch (e) {
      // Handle error, maybe show a snackbar
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildForm(),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          height: 100,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFFEAAECB), Color(0xFF94BBE9)],
              center: Alignment.center,
              radius: 1.0,
            ),
          ),
        ),
        Positioned(
          top: 50,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 44,
                  backgroundImage: _pickedImage != null
                      ? FileImage(_pickedImage!) as ImageProvider
                      : (widget.profileData['profileImageUrl'] != null
                          ? NetworkImage(widget.profileData['profileImageUrl'])
                          : null),
                  child: _pickedImage == null && widget.profileData['profileImageUrl'] == null
                      ? Icon(Icons.person, size: 50)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.black.withOpacity(0.6),
                    child: Icon(Icons.add_a_photo, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 50), // For spacing below avatar
        _buildTextField(_nameController, "Full Name"),
        SizedBox(height: 16),
        _buildTextField(_roleController, "Role"),
        SizedBox(height: 16),
        _buildTextField(_locationController, "Location"),
        SizedBox(height: 16),
        _buildTextField(
          _bioController,
          "About",
          maxLength: _bioMaxLength,
          maxLines: 4,
        ),
        SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            "${_bioMaxLength - _bioCharacterCount} characters left",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int? maxLength, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        counterText: "", // Hide the default counter
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: Text("Cancel"),
          ),
          SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveChanges,
            child: _isSaving
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text("Save Changes"),
          ),
        ],
      ),
    );
  }
} 