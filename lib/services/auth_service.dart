import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

class AuthService {
  final auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  // Get current user
  User? get currentUser => auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Create account with email and password
  Future<UserCredential> createAccountWithEmailAndPassword(
    String email,
    String password,
    String username,
  ) async {
    try {
      // Check username availability first
      final isAvailable = await isUsernameAvailable(username);
      if (!isAvailable) {
        throw 'Username is already taken';
      }

      // Create auth account
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update the user's display name in Firebase Auth
      await credential.user!.updateDisplayName(username);

      // Create user document in Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'username': username.toLowerCase(),
        'displayName': username,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'followerCount': 0,
        'followingCount': 0,
        'likeCount': 0,
        'videoCount': 0,
        'following': const [],
        'followers': const [],
      });

      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    // Don't query if current user already has this username
    if (auth.currentUser?.displayName?.toLowerCase() == username.toLowerCase()) {
      return true;
    }
    
    final snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase())
        .get();
    return snapshot.docs.isEmpty;
  }

  bool isValidUsername(String username) {
    final RegExp alphanumeric = RegExp(r'^[a-zA-Z0-9]+$');
    return username.length >= 3 && 
           username.length <= 8 && 
           alphanumeric.hasMatch(username);
  }

  Future<void> updateProfile({
    required String username,
    String? photoUrl,
    String? bio,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    // Validate username
    if (!isValidUsername(username)) {
      throw Exception('Username must be 3-8 alphanumeric characters');
    }

    // Check availability
    final isAvailable = await isUsernameAvailable(username);
    if (!isAvailable) {
      throw Exception('Username is already taken');
    }

    try {
      // Check if user document exists
      final userRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userRef.get();

      // Prepare update data
      final Map<String, dynamic> userData = {
        'username': username.toLowerCase(),
        'displayName': username,
      };
      if (bio != null && bio.isNotEmpty) {
        userData['bio'] = bio;
      }

      // If document doesn't exist, add additional required fields
      if (!userDoc.exists) {
        userData.addAll({
          'email': user.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'followerCount': 0,
          'followingCount': 0,
          'likeCount': 0,
          'videoCount': 0,
          'following': const [],
          'followers': const [],
        });
      }

      // Update or create document
      await Future.wait([
        user.updateDisplayName(username),
        if (photoUrl != null) user.updatePhotoURL(photoUrl),
        userDoc.exists ? userRef.update(userData) : userRef.set(userData),
      ]);
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  Future<String> uploadProfilePhoto(String filePath) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    try {
      final ref = storage.ref().child('profile_photos/${user.uid}/${DateTime.now().millisecondsSinceEpoch}');
      late final TaskSnapshot snapshot;
      
      if (kIsWeb) {
        // For web, convert the file path to Uint8List
        final imageFile = XFile(filePath);
        final bytes = await imageFile.readAsBytes();
        snapshot = await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // For mobile platforms
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('Image file not found');
        }
        snapshot = await ref.putFile(file);
      }

      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Update user document with new photo URL
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': downloadUrl,
      });
      
      return downloadUrl;
    } catch (e) {
      print('Profile photo upload error: $e');
      throw Exception('Failed to upload profile photo: ${e.toString()}');
    }
  }
} 