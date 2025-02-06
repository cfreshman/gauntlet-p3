import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String username;
  final String displayName;
  final String? photoUrl;
  final String? minecraftUsername;
  final String bio;
  final int followerCount;
  final int followingCount;
  final int likeCount;      // Total likes received on all videos
  final int videoCount;
  final List<String> following;    // List of user IDs this user follows
  final List<String> followers;    // List of user IDs following this user

  User({
    required this.id,
    required this.username,
    required this.displayName,
    this.photoUrl,
    this.minecraftUsername,
    this.bio = '',
    this.followerCount = 0,
    this.followingCount = 0,
    this.likeCount = 0,
    this.videoCount = 0,
    this.following = const [],
    this.followers = const [],
  });

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'],
      minecraftUsername: data['minecraftUsername'],
      bio: data['bio'] ?? '',
      followerCount: data['followerCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      likeCount: data['likeCount'] ?? 0,
      videoCount: data['videoCount'] ?? 0,
      following: List<String>.from(data['following'] ?? []),
      followers: List<String>.from(data['followers'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'minecraftUsername': minecraftUsername,
      'bio': bio,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'likeCount': likeCount,
      'videoCount': videoCount,
      'following': following,
      'followers': followers,
    };
  }
} 