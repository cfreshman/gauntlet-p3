import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';

class VideoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> uploadVideo(
    File videoFile, {
    String? title,
    String? description,
    List<String>? tags,
    void Function(double progress)? onProgress,
  }) async {
    if (_auth.currentUser == null) {
      throw 'User must be logged in to upload videos';
    }

    try {
      // Generate a unique filename
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(videoFile.path)}';
      final String userId = _auth.currentUser!.uid;
      
      // Create the storage reference
      final storageRef = _storage.ref().child('videos/$userId/$fileName');
      
      // Start the upload with progress monitoring
      final UploadTask uploadTask = storageRef.putFile(videoFile);
      
      // Monitor upload progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }
      
      // Wait for the upload to complete and get the download URL
      final TaskSnapshot snapshot = await uploadTask;
      final String videoUrl = await snapshot.ref.getDownloadURL();

      // Generate thumbnail
      final thumbnailUrl = await _generateThumbnail(videoFile);
      
      // Create the video document in Firestore
      final videoDoc = await _firestore.collection('videos').add({
        'userId': userId,
        'title': title ?? 'Untitled',
        'description': description ?? '',
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'tags': tags ?? [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'views': 0,
        'likes': 0,
        'shares': 0,
        'comments': 0,
      });
      
      return videoDoc.id;
    } catch (e) {
      throw 'Failed to upload video: $e';
    }
  }

  Future<String> _generateThumbnail(File videoFile) async {
    try {
      // Initialize video controller
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      
      // TODO: Generate actual thumbnail from video frame
      // For now, we'll return an empty string
      controller.dispose();
      return '';
    } catch (e) {
      return '';
    }
  }

  Future<void> deleteVideo(String videoId) async {
    if (_auth.currentUser == null) {
      throw 'User must be logged in to delete videos';
    }

    try {
      // Get the video document
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        throw 'Video not found';
      }

      final videoData = videoDoc.data()!;
      
      // Check if the user owns this video
      if (videoData['userId'] != _auth.currentUser!.uid) {
        throw 'You do not have permission to delete this video';
      }

      // Delete the video file from storage
      final videoUrl = videoData['videoUrl'] as String;
      final storageRef = _storage.refFromURL(videoUrl);
      await storageRef.delete();

      // Delete the thumbnail if it exists
      final thumbnailUrl = videoData['thumbnailUrl'] as String;
      if (thumbnailUrl.isNotEmpty) {
        final thumbnailRef = _storage.refFromURL(thumbnailUrl);
        await thumbnailRef.delete();
      }

      // Delete the video document
      await videoDoc.reference.delete();
    } catch (e) {
      throw 'Failed to delete video: $e';
    }
  }

  Stream<QuerySnapshot> getVideosForUser(String userId) {
    return _firestore
        .collection('videos')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getAllVideos() {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getVideosByTag(String tag) {
    return _firestore
        .collection('videos')
        .where('tags', arrayContains: tag)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
} 