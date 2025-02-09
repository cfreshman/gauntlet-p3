import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class VideoConverterService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if video needs processing by checking its extension
  static Future<bool> needsConversion(XFile video) async {
    // Always convert for consistency
    return true;
  }

  /// Convert video to MP4 format using Cloud Function
  static Future<Map<String, dynamic>?> convertToMp4(
    XFile inputVideo, {
    void Function(double)? onProgress,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User must be logged in to upload videos');

      // 1. Upload original file to temporary location
      final tempFileName = 'temp/${DateTime.now().millisecondsSinceEpoch}_${path.basename(inputVideo.path)}';
      final storageRef = _storage.ref().child(tempFileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await inputVideo.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'video/*'),
        );
      } else {
        uploadTask = storageRef.putFile(
          File(inputVideo.path),
          SettableMetadata(contentType: 'video/*'),
        );
      }

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      await uploadTask;
      onProgress?.call(1.0);  // Ensure we show 100% before processing starts

      // 2. Call Cloud Function to process video
      final result = await _functions.httpsCallable('processVideo').call({
        'filePath': tempFileName,
      });

      // 3. Return the processed video info
      return {
        'videoUrl': result.data['videoUrl'],
        'thumbnailUrl': result.data['thumbnailUrl'],
        'durationMs': result.data['durationMs'],
      };
    } catch (e) {
      print('Error converting video: $e');
      rethrow;
    }
  }
} 