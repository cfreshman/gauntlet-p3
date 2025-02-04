import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';
import '../models/video.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';

class VideoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Video> uploadVideo({
    required XFile videoFile,
    required String title,
    required String description,
    required List<String> tags,
    void Function(double)? onProgress,
  }) async {
    try {
      print('Starting video upload process...');
      print('File path: ${videoFile.path}');

      final user = _auth.currentUser;
      if (user == null) throw Exception('User must be logged in to upload videos');
      print('User authenticated: ${user.uid}');

      // 1. Upload video file to Storage
      final videoFileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(videoFile.path)}';
      print('Generated filename: $videoFileName');

      final videoRef = _storage.ref().child('videos/$videoFileName');
      print('Storage reference created');

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await videoFile.readAsBytes();
        uploadTask = videoRef.putData(bytes);
      } else {
        uploadTask = videoRef.putFile(File(videoFile.path));
      }
      print('Upload task started');

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes);
        onProgress?.call(progress);
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      }, onError: (error) {
        print('Upload error: $error');
      });

      final snapshot = await uploadTask;
      print('Upload completed');

      final videoUrl = await snapshot.ref.getDownloadURL();
      print('Video URL obtained: $videoUrl');

      // Use the first frame of the video as thumbnail for now
      // TODO: Generate proper thumbnail
      final thumbnailUrl = videoUrl;
      print('Using video URL as thumbnail');

      // 2. Create video document in Firestore
      print('Creating Firestore document...');
      final videoDoc = await _firestore.collection('videos').add({
        'title': title,
        'description': description,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'creatorId': user.uid,
        'creatorUsername': user.displayName ?? 'Anonymous',
        'tags': tags,
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
        'viewCount': 0,
      });
      print('Firestore document created with ID: ${videoDoc.id}');

      // 3. Fetch the created document
      final docSnapshot = await videoDoc.get();
      print('Upload process completed successfully');
      
      return Video.fromFirestore(docSnapshot);
    } catch (e, stackTrace) {
      print('Error during video upload: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to upload video: $e');
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
      if (videoData['creatorId'] != _auth.currentUser!.uid) {
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
        .where('creatorId', isEqualTo: userId)
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

  // Fetch videos for the feed
  Stream<List<Video>> getVideoFeed() {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
        });
  }

  // Increment view count
  Future<void> incrementViewCount(String videoId) async {
    await _firestore.collection('videos').doc(videoId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  // Get current user's videos
  Future<List<Video>> getUserVideos() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to fetch their videos');
    }

    final snapshot = await _firestore
        .collection('videos')
        .where('creatorId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
  }
} 