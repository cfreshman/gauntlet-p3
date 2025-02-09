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
import 'url_service.dart';
import 'captions_service.dart';
import 'video_converter_service.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class VideoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  // Add getter for firestore
  FirebaseFirestore get firestore => _firestore;

  Future<VideoUploadResult> uploadVideo({
    required String title,
    required String description,
    required Set<String> tags,
    required String videoUrl,
    required String thumbnailUrl,
    required int durationMs,
  }) async {
    try {
      // Create video document in Firestore
      final videoRef = _firestore.collection('videos').doc();
      await videoRef.set({
        'id': videoRef.id,
        'title': title,
        'description': description,
        'tags': tags.toList(),
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'durationMs': durationMs,
        'creatorId': _auth.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'viewCount': 0,
        'likeCount': 0,
        'commentCount': 0,
      });

      return VideoUploadResult(
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        title: title,
        description: description,
        tags: tags,
      );
    } catch (e) {
      print('Error in uploadVideo: $e');
      throw Exception('Failed to upload video: $e');
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

  // Increment view count and track video history
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

  // Search videos by title, description, or semantic content
  Future<List<Video>> searchVideos({String? query, String? tag}) async {
    try {
      if (tag != null) {
        // If tag is provided, use traditional tag search
        final snapshot = await _firestore
          .collection('videos')
          .where('tags', arrayContains: tag)
          .orderBy('createdAt', descending: true)
          .get();
        return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
      }

      if (query == null || query.isEmpty) {
        // If no query, return latest videos
        return getVideoFeed().first;
      }

      print('Starting semantic search for query: $query');
      
      // Use RAG for semantic search
      final result = await _functions
        .httpsCallable('searchVideos')
        .call({
          'query': query,
          'limit': 20,  // Get more results for better filtering
          'minScore': 0.2,  // Lowered threshold significantly for more results
          'searchMode': 'semantic', // Tell backend to prioritize semantic matching
          'fields': ['title', 'description', 'tags'], // Search across all text fields
        });

      print('RAG search results: ${result.data}');
      
      final videoIds = (result.data['results'] as List)
        .map((v) => v['id'] as String)
        .toList();

      print('Found ${videoIds.length} matching videos');

      if (videoIds.isEmpty) {
        print('No semantic matches found, falling back to title search');
        // Fallback to traditional title search if no semantic matches
        final snapshot = await _firestore
          .collection('videos')
          .where('title', isGreaterThanOrEqualTo: query ?? '')
          .where('title', isLessThanOrEqualTo: (query ?? '') + '\uf8ff')
          .orderBy('title')
          .orderBy('createdAt', descending: true)
          .get();
        return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
      }

      // Fetch full video objects
      final videos = await Future.wait(
        videoIds.map((id) => getVideoById(id))
      );

      final validVideos = videos.whereType<Video>().toList();
      print('Returning ${validVideos.length} valid videos');
      
      return validVideos;
    } catch (e) {
      print('Error searching videos: $e');
      // Fallback to traditional search on error
      final snapshot = await _firestore
        .collection('videos')
        .where('title', isGreaterThanOrEqualTo: query ?? '')
        .where('title', isLessThanOrEqualTo: (query ?? '') + '\uf8ff')
        .orderBy('title')
        .orderBy('createdAt', descending: true)
        .get();
      return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
    }
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

  // Get a single video by ID
  Future<Video?> getVideoById(String videoId) async {
    final doc = await _firestore.collection('videos').doc(videoId).get();
    if (!doc.exists) return null;
    return Video.fromFirestore(doc);
  }

  // Get related videos from the same creator
  Future<List<Video>> getRelatedVideos(String creatorId, String currentVideoId, {int limit = 10}) async {
    final snapshot = await _firestore
        .collection('videos')
        .where('creatorId', isEqualTo: creatorId)
        .where(FieldPath.documentId, isNotEqualTo: currentVideoId)
        .orderBy(FieldPath.documentId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
  }

  // Get a shareable video URL
  String getShareableUrl(String videoId) {
    // Use URL service for web, otherwise use production URL
    final origin = kIsWeb 
        ? UrlService.instance.getCurrentOrigin() ?? 'https://reel-ai-dev.web.app'
        : 'https://reel-ai-dev.web.app';
    return '$origin/video/$videoId';
  }

  // Get personalized video recommendations using RAG
  Future<List<Video>> getRecommendedVideos({int limit = 10}) async {
    try {
      final user = _auth.currentUser;
      
      // If no user, return trending videos
      if (user == null) {
        final snapshot = await _firestore
          .collection('videos')
          .orderBy('viewCount', descending: true)
          .limit(limit)
          .get();
        return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
      }

      // Get user's liked videos
      final likedVideos = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('liked_videos')
        .orderBy('timestamp', descending: true)
        .limit(20)  // Increased to get more signal for recommendations
        .get();

      // Extract metadata from liked videos
      final likedTags = <String>{};
      final likedVideoIds = <String>{};
      final likedTitles = <String>[];
      final likedDescriptions = <String>[];

      // Process liked videos
      for (final doc in likedVideos.docs) {
        final videoId = doc.id;
        likedVideoIds.add(videoId);
        final videoDoc = await _firestore.collection('videos').doc(videoId).get();
        if (videoDoc.exists) {
          final data = videoDoc.data()!;
          final tags = List<String>.from(data['tags'] ?? []);
          likedTags.addAll(tags);
          likedTitles.add(data['title'] as String);
          if (data['description'] != null && data['description'].toString().isNotEmpty) {
            likedDescriptions.add(data['description'] as String);
          }
        }
      }

      // If user has no likes, return trending videos
      if (likedTags.isEmpty && likedTitles.isEmpty) {
        final snapshot = await _firestore
          .collection('videos')
          .orderBy('viewCount', descending: true)
          .limit(limit)
          .get();
        return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
      }

      // Build semantic query from all metadata
      final queryParts = [
        ...likedTitles,
        ...likedDescriptions,
        ...likedTags,
      ];

      // Call RAG function to get personalized recommendations
      final result = await _functions
        .httpsCallable('searchVideos')
        .call({
          'query': queryParts.join(' '),  // Combine all metadata into search query
          'tags': likedTags.toList(),
          'excludeIds': likedVideoIds.toList(),
          'limit': limit,
          'minScore': 0,  // Allow all matches through RAG scoring
          'searchMode': 'rag',
        });

      final videoIds = (result.data['results'] as List)
        .map((v) => v['id'] as String)
        .toList();

      // Fetch full video objects
      final videos = await Future.wait(
        videoIds.map((id) => getVideoById(id))
      );

      return videos.whereType<Video>().toList();
    } catch (e) {
      print('Error getting recommendations: $e');
      // Fallback to trending videos on error
      final snapshot = await _firestore
        .collection('videos')
        .orderBy('viewCount', descending: true)
        .limit(limit)
        .get();
      return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
    }
  }

  // Helper to get videos user has interacted with recently
  Future<List<Video>> _getRecentInteractions({int hours = 24}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    // Get recently viewed
    final recentlyViewed = await _firestore
      .collection('users')
      .doc(user.uid)
      .collection('video_history')
      .where('viewedAt', isGreaterThan: Timestamp.fromDate(
        DateTime.now().subtract(Duration(hours: hours))
      ))
      .orderBy('viewedAt', descending: true)
      .limit(10)
      .get();

    // Get recently liked
    final recentlyLiked = await _firestore
      .collection('users')
      .doc(user.uid)
      .collection('liked_videos')
      .where('timestamp', isGreaterThan: Timestamp.fromDate(
        DateTime.now().subtract(Duration(hours: hours))
      ))
      .orderBy('timestamp', descending: true)
      .limit(10)
      .get();

    // Combine and fetch full video objects
    final videoIds = {
      ...recentlyViewed.docs.map((doc) => doc.data()['videoId'] as String),
      ...recentlyLiked.docs.map((doc) => doc.id)
    };

    final videos = await Future.wait(
      videoIds.map((id) => getVideoById(id))
    );

    return videos.whereType<Video>().toList();
  }

  // Helper to get videos by tags
  Future<List<Video>> _getVideosByTags({
    required List<String> tags,
    required int limit
  }) async {
    if (tags.isEmpty) return [];

    final snapshot = await _firestore
      .collection('videos')
      .where('tags', arrayContainsAny: tags)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .get();

    return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
  }

  // Get comment summary
  Future<String?> getCommentSummary(String videoId) async {
    try {
      // Check cache first
      final cachedSummary = await _firestore
        .collection('videos')
        .doc(videoId)
        .collection('metadata')
        .doc('commentSummary')
        .get();

      if (cachedSummary.exists) {
        final data = cachedSummary.data()!;
        // If cache is fresh (less than 1 hour old)
        if ((data['updatedAt'] as Timestamp).toDate().isAfter(
          DateTime.now().subtract(const Duration(hours: 1))
        )) {
          return data['summary'] as String?;
        }
      }

      // Generate new summary
      final result = await _functions
        .httpsCallable('summarizeComments')
        .call({ 'videoId': videoId });
      
      return result.data['summary'] as String?;
    } catch (e) {
      print('Error getting comment summary: $e');
      return null;
    }
  }

  // Get captions for a video
  Future<String?> getOrCreateCaptions(String videoId) async {
    try {
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) return null;
      
      final video = Video.fromFirestore(videoDoc);
      if (video.captionsUrl != null) return video.captionsUrl;

      // If no captions, call cloud function to generate them
      final result = await _functions.httpsCallable('getOrCreateCaptions').call({
        'videoId': videoId,
      });

      final captionsUrl = result.data['captionsUrl'] as String?;
      if (captionsUrl != null) {
        // Update video document with captions URL
        await _firestore.collection('videos').doc(videoId).update({
          'captionsUrl': captionsUrl,
        });
      }
      return captionsUrl;
    } catch (e) {
      print('Error getting captions: $e');
      return null;
    }
  }

  // Stream captions based on video position
  Stream<String?> getCaptionsStream(String videoId, Duration position) async* {
    try {
      print('Getting captions for video: $videoId at position: $position');
      
      // Get the captions URL
      final url = await getOrCreateCaptions(videoId);
      if (url == null) {
        print('No captions URL found for video: $videoId');
        yield null;
        return;
      }

      print('Got captions URL: $url');

      // Parse captions if not already cached
      try {
        final captions = await CaptionsService.parseCaptions(url);
        print('Successfully parsed captions, got ${captions.length} entries');
        
        // Get current caption text
        final captionText = CaptionsService.getCurrentCaption(captions, position);
        print('Current caption at ${position.inMilliseconds}ms: $captionText');
        
        yield captionText;
      } catch (e, stackTrace) {
        print('Error parsing captions: $e');
        print('Stack trace: $stackTrace');
        yield null;
      }
    } catch (e, stackTrace) {
      print('Error streaming captions: $e');
      print('Stack trace: $stackTrace');
      yield null;
    }
  }
}

class VideoUploadResult {
  final String videoUrl;
  final String thumbnailUrl;
  final String title;
  final String description;
  final Set<String> tags;

  VideoUploadResult({
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.description,
    required this.tags,
  });
} 