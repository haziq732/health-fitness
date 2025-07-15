import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/user_service.dart';

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({super.key});

  @override
  _ImageViewerScreenState createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  final _userService = UserService();
  final _auth = FirebaseAuth.instance;
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _error = "User not logged in.";
        _isLoading = false;
      });
      return;
    }

    try {
      final userData = await _userService.getUserData(user.uid);
      if (userData != null && userData['profile'] != null) {
        final profile = userData['profile'];
        final imageBase64 = profile['profileImageUrl'] as String?;

        if (imageBase64 != null && imageBase64.isNotEmpty) {
          _imageBytes = base64Decode(imageBase64);
        } else {
          _error = "No profile image found in the database.";
        }
      } else {
        _error = "Could not load user profile.";
      }
    } catch (e) {
      _error = "An error occurred while loading the image: $e";
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stored Profile Image'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  )
                : _imageBytes != null
                    ? InteractiveViewer(
                        child: Image.memory(_imageBytes!),
                      )
                    : const Text(
                        "No image to display.",
                        style: TextStyle(fontSize: 16),
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadImage,
        tooltip: 'Refresh Image',
        child: const Icon(Icons.refresh),
      ),
    );
  }
} 