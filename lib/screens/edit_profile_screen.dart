import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../widgets/loading_indicator.dart';
import '../extensions/string_extensions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _authService = AuthService();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;
  String? _photoUrl;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _loadCurrentProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      _usernameController.text = user.displayName ?? '';
      _photoUrl = user.photoURL;
      
      // Load bio from Firestore
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (userDoc.exists) {
          setState(() {
            _bioController.text = userDoc.data()?['bio'] ?? '';
          });
        }
      } catch (e) {
        print('Error loading bio: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Limit image size
        maxHeight: 800,
        imageQuality: 85, // Compress image
      );
      
      if (image == null) return;

      setState(() {
        _isLoading = true;
      });

      final photoUrl = await _authService.uploadProfilePhoto(image.path);
      
      setState(() {
        _photoUrl = photoUrl;
        _hasChanges = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '').lowercase),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges && _usernameController.text == _auth.currentUser?.displayName) {
      Navigator.pop(context);
      return;
    }

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('username cannot be empty'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.updateProfile(
        username: username,
        photoUrl: _photoUrl,
        bio: _bioController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('profile updated'),
          backgroundColor: AppColors.accent,
        ));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'edit profile'.lowercase,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: Text(
              'save'.lowercase,
              style: TextStyle(
                color: _isLoading ? AppColors.textSecondary : AppColors.accent,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile photo
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.accent,
                          backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                          child: _photoUrl == null ? Icon(
                            Icons.person,
                            size: 50,
                            color: AppColors.textPrimary,
                          ) : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: AppColors.background,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Username
                  TextField(
                    controller: _usernameController,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'username'.lowercase,
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      helperText: '3-8 alphanumeric characters'.lowercase,
                      helperStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.textSecondary),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                    ),
                    onChanged: (_) => setState(() => _hasChanges = true),
                  ),
                  const SizedBox(height: 16),

                  // Bio
                  TextField(
                    controller: _bioController,
                    style: TextStyle(color: AppColors.textPrimary),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'bio'.lowercase,
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.textSecondary),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                    ),
                    onChanged: (_) => setState(() => _hasChanges = true),
                  ),
                ],
              ),
            ),
    );
  }
} 