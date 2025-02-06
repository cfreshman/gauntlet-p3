import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';
import '../models/video.dart';
import '../models/comment.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_functions/cloud_functions.dart';

class VideoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  // Add getter for firestore
  FirebaseFirestore get firestore => _firestore;

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

      // Store in the correct path structure: videos/{userId}/{fileName}
      final videoRef = _storage.ref().child('videos/${user.uid}/$videoFileName');
      print('Storage reference created');

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await videoFile.readAsBytes();
        uploadTask = videoRef.putData(bytes, SettableMetadata(
          contentType: 'video/mp4',
        ));
      } else {
        uploadTask = videoRef.putFile(File(videoFile.path), SettableMetadata(
          contentType: 'video/mp4',
        ));
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

      // Call the Cloud Function to generate thumbnail and get metadata
      print('Calling generateThumbnail function...');
      final result = await _functions.httpsCallable('generateThumbnail').call({
        'filePath': 'videos/${user.uid}/$videoFileName',
      });
      
      final data = result.data as Map<String, dynamic>;
      final thumbnailUrl = data['thumbnailUrl'] as String;
      final durationMs = data['durationMs'] as int;
      print('Got metadata from function - thumbnail: $thumbnailUrl, duration: $durationMs');
      
      // Create video document in Firestore with all metadata
      print('Creating Firestore document...');
      final videoDoc = await _firestore.collection('videos').add({
        'title': title,
        'description': description,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'durationMs': durationMs,
        'creatorId': user.uid,
        'creatorUsername': user.displayName ?? 'Anonymous',
        'tags': tags,
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
        'viewCount': 0,
      });
      print('Firestore document created with ID: ${videoDoc.id}');

      // Fetch the created document
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

      // Extract the video filename from the URL
      final videoUrl = videoData['videoUrl'] as String;
      final videoUri = Uri.parse(videoUrl);
      final pathSegments = videoUri.pathSegments;
      final fileName = pathSegments.last.split('?').first;  // Remove query parameters
      
      // Delete the video file from storage
      try {
        final storageRef = _storage.ref().child('videos/${_auth.currentUser!.uid}/$fileName');
        await storageRef.delete();
      } catch (e) {
        print('Error deleting video file: $e');
        // Continue with document deletion even if file deletion fails
      }

      // Delete the thumbnail if it exists
      final thumbnailUrl = videoData['thumbnailUrl'] as String;
      if (thumbnailUrl.isNotEmpty) {
        try {
          final thumbnailUri = Uri.parse(thumbnailUrl);
          final thumbnailFileName = thumbnailUri.pathSegments.last.split('?').first;
          final thumbnailRef = _storage.ref().child('thumbnails/$thumbnailFileName');
          await thumbnailRef.delete();
        } catch (e) {
          print('Error deleting thumbnail: $e');
          // Continue with document deletion even if thumbnail deletion fails
        }
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
        .orderBy('createdAt', descending: true)  // Latest videos first
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList());
  }

  // Increment view count
  Future<void> incrementViewCount(String videoId) async {
    await _firestore.collection('videos').doc(videoId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  // Get current user's videos
  Future<List<Video>> getUserVideos({String? userId}) async {
    final user = _auth.currentUser;
    if (user == null && userId == null) {
      throw Exception('User must be logged in to fetch their videos');
    }

    final snapshot = await _firestore
        .collection('videos')
        .where('creatorId', isEqualTo: userId ?? user!.uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
  }

  // Search videos by title or tags
  Future<List<Video>> searchVideos({String? query, String? tag}) async {
    Query videosQuery = _firestore.collection('videos');

    // If tag is provided, filter by tag
    if (tag != null) {
      videosQuery = videosQuery.where('tags', arrayContains: tag);
    }

    // If search query is provided, filter by title
    if (query != null && query.isNotEmpty) {
      videosQuery = videosQuery.where('title', isEqualTo: query);
    }

    // Order by creation date
    videosQuery = videosQuery.orderBy('createdAt', descending: true);

    final snapshot = await videosQuery.get();
    return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
  }

  // Like/Unlike a video
  Future<void> toggleLike(String videoId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in');

    try {
      // First check if video exists
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        throw Exception('Video not found');
      }

      // Reference to the user's liked_videos collection
      final userLikeRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('liked_videos')
        .doc(videoId);

      // Reference to the video's likes collection
      final videoLikeRef = _firestore
        .collection('videos')
        .doc(videoId)
        .collection('likes')
        .doc(user.uid);

      // Check if already liked
      final likeDoc = await userLikeRef.get();
      
      // Use a batch to ensure atomic operation
      final batch = _firestore.batch();
      
      if (likeDoc.exists) {
        // Unlike
        batch.delete(userLikeRef);
        batch.delete(videoLikeRef);
        batch.update(videoDoc.reference, {
          'likeCount': FieldValue.increment(-1)
        });
      } else {
        // Like
        final likeData = {
          'timestamp': FieldValue.serverTimestamp(),
          'videoId': videoId,
          'userId': user.uid
        };
        batch.set(userLikeRef, likeData);
        batch.set(videoLikeRef, likeData);
        batch.update(videoDoc.reference, {
          'likeCount': FieldValue.increment(1)
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error toggling like: $e');
      throw Exception('Failed to update like: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // Check if user has liked a video
  Stream<bool> hasLiked(String videoId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _firestore
      .collection('users')
      .doc(user.uid)
      .collection('liked_videos')
      .doc(videoId)
      .snapshots()
      .map((doc) => doc.exists);
  }

  // Get liked videos with pagination
  Stream<List<Video>> getLikedVideos({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // Query the user's liked_videos collection
    Query query = _firestore
      .collection('users')
      .doc(user.uid)
      .collection('liked_videos')
      .orderBy('timestamp', descending: true)
      .limit(limit);

    // Add pagination if startAfter is provided
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // Transform the stream to include full video data
    return query.snapshots().asyncMap((snapshot) async {
      final videoFutures = snapshot.docs.map((doc) async {
        final videoDoc = await _firestore
          .collection('videos')
          .doc(doc.id)
          .get();
        
        if (!videoDoc.exists) {
          // Video was deleted, clean up the like
          await doc.reference.delete();
          return null;
        }
        
        return Video.fromFirestore(videoDoc);
      });

      final videos = await Future.wait(videoFutures);
      return videos.where((v) => v != null).cast<Video>().toList();
    });
  }

  // Add a comment to a video
  Future<Comment> addComment(String videoId, String text) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to comment');
    }

    try {
      late Comment newComment;
      
      await _firestore.runTransaction((transaction) async {
        // Get the video document first
        final videoDoc = await transaction.get(
          _firestore.collection('videos').doc(videoId)
        );
        
        if (!videoDoc.exists) {
          throw Exception('Video not found');
        }

        // Create the comment document
        final commentRef = _firestore
            .collection('videos')
            .doc(videoId)
            .collection('comments')
            .doc();

        final commentData = {
          'videoId': videoId,
          'userId': user.uid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'likeCount': 0,
          'likedBy': [],
        };

        // Add the comment
        transaction.set(commentRef, commentData);

        // Update video's comment count
        transaction.update(videoDoc.reference, {
          'commentCount': FieldValue.increment(1),
        });

        // Create Comment object for return
        newComment = Comment(
          id: commentRef.id,
          videoId: videoId,
          userId: user.uid,
          text: text,
          createdAt: DateTime.now(),
          likeCount: 0,
          likedBy: const [],
        );
      });

      return newComment;
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  // Get comments for a video
  Stream<List<Comment>> getVideoComments(String videoId) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList());
  }

  // Delete a comment
  Future<void> deleteComment(String videoId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to delete comments');

    try {
      // Get the comment document
      final commentDoc = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) throw Exception('Comment not found');
      
      // Check if user owns the comment
      if (commentDoc.data()!['userId'] != user.uid) {
        throw Exception('You can only delete your own comments');
      }

      // Delete the comment
      await commentDoc.reference.delete();

      // Update comment count
      await _firestore.collection('videos').doc(videoId).update({
        'commentCount': FieldValue.increment(-1),
      });
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  // Toggle like on a comment
  Future<void> toggleCommentLike(String videoId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to like comments');
    }

    final commentRef = _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .doc(commentId);

    try {
      await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        
        if (!commentDoc.exists) {
          throw Exception('Comment not found');
        }

        final likedBy = List<String>.from(commentDoc.data()!['likedBy'] ?? []);
        
        if (likedBy.contains(user.uid)) {
          // Unlike
          likedBy.remove(user.uid);
          transaction.update(commentRef, {
            'likeCount': FieldValue.increment(-1),
            'likedBy': likedBy,
          });
        } else {
          // Like
          likedBy.add(user.uid);
          transaction.update(commentRef, {
            'likeCount': FieldValue.increment(1),
            'likedBy': likedBy,
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to toggle comment like: $e');
    }
  }

  // Check if user has liked a comment
  Stream<bool> hasLikedComment(String videoId, String commentId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .doc(commentId)
        .snapshots()
        .map((doc) => 
            doc.exists && 
            (doc.data()?['likedBy'] as List<dynamic>?)?.contains(user.uid) == true);
  }
} 