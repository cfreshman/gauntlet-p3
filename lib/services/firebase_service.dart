import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/video.dart';
import '../models/user.dart';
import '../models/playlist.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Video Methods
  Stream<List<Video>> getVideoFeed() {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
    });
  }

  Future<void> likeVideo(String videoId, String userId) async {
    // TODO: Implement like functionality
  }

  // User Methods
  Future<void> createUser(User user) async {
    await _firestore.collection('users').doc(user.id).set(user.toMap());
  }

  Future<User?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return User.fromFirestore(doc);
    }
    return null;
  }

  // Playlist Methods
  Future<void> createPlaylist(Playlist playlist) async {
    await _firestore.collection('playlists').add(playlist.toMap());
  }

  Stream<List<Playlist>> getUserPlaylists(String userId) {
    return _firestore
        .collection('playlists')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Playlist.fromFirestore(doc)).toList();
    });
  }

  // Subscription Methods
  Future<void> subscribeToUser(String userId, String targetUserId) async {
    await _firestore.collection('users').doc(userId).update({
      'subscribedTo': FieldValue.arrayUnion([targetUserId])
    });
    
    await _firestore.collection('users').doc(targetUserId).update({
      'subscriberCount': FieldValue.increment(1)
    });
  }

  Future<void> unsubscribeFromUser(String userId, String targetUserId) async {
    await _firestore.collection('users').doc(userId).update({
      'subscribedTo': FieldValue.arrayRemove([targetUserId])
    });
    
    await _firestore.collection('users').doc(targetUserId).update({
      'subscriberCount': FieldValue.increment(-1)
    });
  }
} 