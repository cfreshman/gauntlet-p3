import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/playlist.dart';
import '../models/video.dart';

class PlaylistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new playlist
  Future<Playlist> createPlaylist(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to create a playlist');

    final now = DateTime.now();
    final playlistData = {
      'name': name,
      'userId': user.uid,
      'videoIds': <String>[],
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    final docRef = await _firestore.collection('playlists').add(playlistData);
    return Playlist(
      id: docRef.id,
      name: name,
      userId: user.uid,
      videoIds: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  // Get all playlists for a user
  Stream<List<Playlist>> getUserPlaylists({String? userId}) {
    final targetUserId = userId ?? _auth.currentUser?.uid;
    if (targetUserId == null) return Stream.value([]);

    return _firestore
        .collection('playlists')
        .where('userId', isEqualTo: targetUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Playlist.fromFirestore(doc)).toList());
  }

  // Add a video to a playlist
  Future<void> addVideoToPlaylist(String playlistId, String videoId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to modify playlists');

    final playlistRef = _firestore.collection('playlists').doc(playlistId);
    final playlist = await playlistRef.get();

    if (!playlist.exists) throw Exception('Playlist not found');
    if (playlist.data()!['userId'] != user.uid) {
      throw Exception('You do not have permission to modify this playlist');
    }

    final currentVideoIds = List<String>.from(playlist.data()!['videoIds'] ?? []);
    
    // If this is the first video, get its thumbnail
    String? firstVideoThumbnail;
    if (currentVideoIds.isEmpty) {
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (videoDoc.exists) {
        firstVideoThumbnail = videoDoc.data()!['thumbnailUrl'] as String?;
      }
    }

    await playlistRef.update({
      'videoIds': FieldValue.arrayUnion([videoId]),
      'updatedAt': FieldValue.serverTimestamp(),
      if (firstVideoThumbnail != null) 'firstVideoThumbnail': firstVideoThumbnail,
    });
  }

  // Remove a video from a playlist
  Future<void> removeVideoFromPlaylist(String playlistId, String videoId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to modify playlists');

    final playlistRef = _firestore.collection('playlists').doc(playlistId);
    final playlist = await playlistRef.get();

    if (!playlist.exists) throw Exception('Playlist not found');
    if (playlist.data()!['userId'] != user.uid) {
      throw Exception('You do not have permission to modify this playlist');
    }

    final currentVideoIds = List<String>.from(playlist.data()!['videoIds'] ?? []);
    final updatedVideoIds = currentVideoIds.where((id) => id != videoId).toList();

    // If we're removing the first video, update the thumbnail
    String? newFirstVideoThumbnail;
    if (updatedVideoIds.isNotEmpty && currentVideoIds.first == videoId) {
      final newFirstVideoDoc = await _firestore.collection('videos').doc(updatedVideoIds.first).get();
      if (newFirstVideoDoc.exists) {
        newFirstVideoThumbnail = newFirstVideoDoc.data()!['thumbnailUrl'] as String?;
      }
    }

    await playlistRef.update({
      'videoIds': updatedVideoIds,
      'updatedAt': FieldValue.serverTimestamp(),
      'firstVideoThumbnail': newFirstVideoThumbnail ?? FieldValue.delete(),
    });
  }

  // Delete a playlist
  Future<void> deletePlaylist(String playlistId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to delete playlists');

    final playlistRef = _firestore.collection('playlists').doc(playlistId);
    final playlist = await playlistRef.get();

    if (!playlist.exists) throw Exception('Playlist not found');
    if (playlist.data()!['userId'] != user.uid) {
      throw Exception('You do not have permission to delete this playlist');
    }

    await playlistRef.delete();
  }

  // Get videos in a playlist
  Future<List<Video>> getPlaylistVideos(String playlistId) async {
    final playlistDoc = await _firestore.collection('playlists').doc(playlistId).get();
    
    if (!playlistDoc.exists) throw Exception('Playlist not found');
    
    final videoIds = List<String>.from(playlistDoc.data()!['videoIds'] ?? []);
    if (videoIds.isEmpty) return [];

    final videoDocs = await Future.wait(
      videoIds.map((id) => _firestore.collection('videos').doc(id).get())
    );

    // Filter out non-existent videos and get their IDs
    final existingVideos = videoDocs.where((doc) => doc.exists).toList();
    final existingIds = existingVideos.map((doc) => doc.id).toList();
    
    // If we found deleted videos, update the playlist
    if (existingIds.length != videoIds.length) {
      await _firestore.collection('playlists').doc(playlistId).update({
        'videoIds': existingIds,
        'updatedAt': FieldValue.serverTimestamp(),
        // Update thumbnail if first video was deleted
        if (videoIds.isNotEmpty && videoIds.first != existingIds.first) 
          'firstVideoThumbnail': existingVideos.isNotEmpty 
              ? existingVideos.first.data()!['thumbnailUrl'] 
              : FieldValue.delete(),
      });
    }

    return existingVideos.map((doc) => Video.fromFirestore(doc)).toList();
  }

  // Update playlist name
  Future<void> updatePlaylistName(String playlistId, String newName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to modify playlists');

    final playlistRef = _firestore.collection('playlists').doc(playlistId);
    final playlist = await playlistRef.get();

    if (!playlist.exists) throw Exception('Playlist not found');
    if (playlist.data()!['userId'] != user.uid) {
      throw Exception('You do not have permission to modify this playlist');
    }

    await playlistRef.update({
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Reorder videos in a playlist
  Future<void> reorderVideos(String playlistId, List<String> newVideoOrder) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to modify playlists');

    final playlistRef = _firestore.collection('playlists').doc(playlistId);
    final playlist = await playlistRef.get();

    if (!playlist.exists) throw Exception('Playlist not found');
    if (playlist.data()!['userId'] != user.uid) {
      throw Exception('You do not have permission to modify this playlist');
    }

    // Verify that we're not losing any videos in the reorder
    final currentVideoIds = List<String>.from(playlist.data()!['videoIds'] ?? []);
    if (currentVideoIds.length != newVideoOrder.length ||
        !currentVideoIds.every((id) => newVideoOrder.contains(id))) {
      throw Exception('Invalid reorder operation: video list mismatch');
    }

    // Get the new first video's thumbnail if it changed
    String? newFirstVideoThumbnail;
    if (newVideoOrder.isNotEmpty && newVideoOrder.first != currentVideoIds.first) {
      final newFirstVideoDoc = await _firestore.collection('videos').doc(newVideoOrder.first).get();
      if (newFirstVideoDoc.exists) {
        newFirstVideoThumbnail = newFirstVideoDoc.data()!['thumbnailUrl'] as String?;
      }
    }

    await playlistRef.update({
      'videoIds': newVideoOrder,
      'updatedAt': FieldValue.serverTimestamp(),
      if (newFirstVideoThumbnail != null) 'firstVideoThumbnail': newFirstVideoThumbnail,
    });
  }

  // Get a single playlist by ID
  Stream<Playlist?> getPlaylistById(String playlistId) {
    return _firestore
        .collection('playlists')
        .doc(playlistId)
        .snapshots()
        .map((doc) => doc.exists ? Playlist.fromFirestore(doc) : null);
  }

  // Get videos in a playlist as a stream
  Stream<List<Video>> getPlaylistVideosStream(String playlistId) {
    return _firestore
        .collection('playlists')
        .doc(playlistId)
        .snapshots()
        .asyncMap((playlistDoc) async {
          if (!playlistDoc.exists) throw Exception('Playlist not found');
          
          final videoIds = List<String>.from(playlistDoc.data()!['videoIds'] ?? []);
          if (videoIds.isEmpty) return [];

          final videoDocs = await Future.wait(
            videoIds.map((id) => _firestore.collection('videos').doc(id).get())
          );

          // Filter out non-existent videos and get their IDs
          final existingVideos = videoDocs.where((doc) => doc.exists).toList();
          final existingIds = existingVideos.map((doc) => doc.id).toList();
          
          // If we found deleted videos, update the playlist
          if (existingIds.length != videoIds.length) {
            await _firestore.collection('playlists').doc(playlistId).update({
              'videoIds': existingIds,
              'updatedAt': FieldValue.serverTimestamp(),
              // Update thumbnail if first video was deleted
              if (videoIds.isNotEmpty && videoIds.first != existingIds.first) 
                'firstVideoThumbnail': existingVideos.isNotEmpty 
                    ? existingVideos.first.data()!['thumbnailUrl'] 
                    : FieldValue.delete(),
            });
          }

          return existingVideos.map((doc) => Video.fromFirestore(doc)).toList();
        });
  }
} 