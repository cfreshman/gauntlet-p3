import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String username;
  final String? photoUrl;
  final List<String> subscribedTo;
  final int subscriberCount;
  final List<String> playlists;

  User({
    required this.id,
    required this.username,
    this.photoUrl,
    this.subscribedTo = const [],
    this.subscriberCount = 0,
    this.playlists = const [],
  });

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      username: data['username'] ?? '',
      photoUrl: data['photoUrl'],
      subscribedTo: List<String>.from(data['subscribedTo'] ?? []),
      subscriberCount: data['subscriberCount'] ?? 0,
      playlists: List<String>.from(data['playlists'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'photoUrl': photoUrl,
      'subscribedTo': subscribedTo,
      'subscriberCount': subscriberCount,
      'playlists': playlists,
    };
  }
} 