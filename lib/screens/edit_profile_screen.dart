import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../services/minecraft_skin_service.dart';
import '../widgets/loading_indicator.dart';
import '../extensions/string_extensions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _authService = AuthService();
  final _minecraftService = MinecraftSkinService();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _minecraftUsernameController = TextEditingController();
  bool _isLoading = false;
  String? _photoUrl;
  String? _skinUrl;
  bool _hasChanges = false;
  bool _isCheckingUsername = false;
  final _firestore = FirebaseFirestore.instance;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Initial load
    _loadCurrentProfile();
    
    // Reload data each time screen is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCurrentProfile();
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _minecraftUsernameController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadCurrentProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Always refresh the user to get latest data
      await user.reload();
      final refreshedUser = _auth.currentUser;
      
      if (refreshedUser != null) {
        _usernameController.text = refreshedUser.displayName ?? '';
        _photoUrl = refreshedUser.photoURL;
        
        try {
          final userDoc = await _firestore.collection('users').doc(refreshedUser.uid).get();
          if (userDoc.exists && mounted) {
            setState(() {
              _bioController.text = userDoc.data()?['bio'] ?? '';
              _minecraftUsernameController.text = userDoc.data()?['minecraftUsername'] ?? '';
              // Get photo URL from Firestore as fallback
              _photoUrl = refreshedUser.photoURL ?? userDoc.data()?['photoUrl'];
            });
            
            if (_minecraftUsernameController.text.isNotEmpty) {
              _loadMinecraftSkin();
            }
          }
        } catch (e) {
          print('Error loading profile: $e');
        }
      }
    }
  }

  Future<void> _loadMinecraftSkin() async {
    _debounceTimer?.cancel();
    final username = _minecraftUsernameController.text;
    print('Loading minecraft skin for username: $username');

    if (username.isEmpty) {
      print('Username is empty, clearing skin');
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _skinUrl = null;
          _hasChanges = true;  // Mark as changed even when clearing
        });
      }
      return;
    }

    // Mark as changed immediately when username is set/changed
    if (mounted) {
      setState(() {
        _isCheckingUsername = true;
        _hasChanges = true;  // Set this immediately, don't wait for skin
      });
    }
    print('Starting debounce timer for username: $username');

    // Debounce the API call
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) {
        print('Widget not mounted, cancelling');
        return;
      }
      
      try {
        if (!_minecraftService.isValidUsername(username)) {
          print('Invalid username format: $username');
          setState(() {
            _skinUrl = null;
            _isCheckingUsername = false;
          });
          return;
        }

        print('Fetching face URL for username: $username');
        final faceUrl = await _minecraftService.getFaceUrl(username);
        print('Received face URL: $faceUrl');
        
        // Only update if this is still the current username
        if (!mounted) {
          print('Widget unmounted after getting face URL');
          return;
        }

        if (_minecraftUsernameController.text != username) {
          print('Username changed while fetching, not updating state');
          return;
        }

        print('Updating skin URL in state to: $faceUrl');
        setState(() {
          _skinUrl = faceUrl;
          _isCheckingUsername = false;
        });
        print('State updated successfully - new skin URL: $_skinUrl');
      } catch (e) {
        print('Error loading Minecraft skin: $e');
        if (mounted && _minecraftUsernameController.text == username) {
          setState(() {
            _skinUrl = null;
            _isCheckingUsername = false;
          });
        }
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image == null) return;

      setState(() => _isLoading = true);

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
    if (!_hasChanges && 
        _usernameController.text == _auth.currentUser?.displayName &&
        _minecraftUsernameController.text.isEmpty) {
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
      // Only validate Minecraft username format if provided, don't wait for API
      final minecraftUsername = _minecraftUsernameController.text.trim();
      if (minecraftUsername.isNotEmpty && !_minecraftService.isValidUsername(minecraftUsername)) {
        throw Exception('Invalid Minecraft username format');
      }

      // Always pass the minecraftUsername, whether empty or not
      await _authService.updateProfile(
        username: username,
        bio: _bioController.text.trim(),
        minecraftUsername: minecraftUsername,
        photoUrl: _photoUrl,
      );

      // Clear skin URL if Minecraft username is empty
      if (minecraftUsername.isEmpty) {
        setState(() => _skinUrl = null);
      }

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
    print('Building EditProfileScreen - skinUrl: $_skinUrl, isCheckingUsername: $_isCheckingUsername');
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Photos Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Regular Profile Photo
                    Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: AppColors.accent.withOpacity(0.1),
                              backgroundImage: _photoUrl != null
                                  ? NetworkImage(_photoUrl!)
                                  : null,
                              child: _photoUrl == null
                                  ? Icon(
                                      Icons.person_outline,
                                      size: 50,
                                      color: AppColors.accent,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.accent,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: AppColors.background,
                                  ),
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'profile photo'.lowercase,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 32),

                    // Minecraft Skin Preview
                    if (_minecraftUsernameController.text.isNotEmpty)
                      Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _skinUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _skinUrl!,
                                      fit: BoxFit.contain,
                                      headers: {
                                        'User-Agent': 'TikBlok-App/1.0',
                                        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
                                      },
                                      loadingBuilder: (context, child, progress) {
                                        print('Image loading progress: $progress');
                                        if (progress == null) {
                                          print('Image load complete');
                                          return child;
                                        }
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: progress.expectedTotalBytes != null
                                                ? progress.cumulativeBytesLoaded / 
                                                  progress.expectedTotalBytes!
                                                : null,
                                            color: AppColors.accent,
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        print('Error loading skin image: $error');
                                        return Icon(
                                          Icons.error_outline,
                                          size: 50,
                                          color: AppColors.accent,
                                        );
                                      },
                                    ),
                                  )
                                : Icon(
                                    Icons.person_outline,
                                    size: 50,
                                    color: AppColors.accent,
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'minecraft skin'.lowercase,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

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

                // Minecraft Username
                TextField(
                  controller: _minecraftUsernameController,
                  style: TextStyle(color: AppColors.textPrimary),
                  onChanged: (value) {
                    if (!_hasChanges) {
                      setState(() => _hasChanges = true);
                    }
                    _loadMinecraftSkin();
                  },
                  decoration: InputDecoration(
                    labelText: 'minecraft username'.lowercase,
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    helperText: 'optional - use skin as profile photo'.lowercase,
                    helperStyle: TextStyle(color: AppColors.textSecondary),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.textSecondary),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                    suffixIcon: _isCheckingUsername
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              Icons.refresh,
                              color: AppColors.accent,
                            ),
                            onPressed: _loadMinecraftSkin,
                          ),
                  ),
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
        ),
      ),
    );
  }
} 