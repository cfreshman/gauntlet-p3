import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String videoId;
  final String userId;
  final String username;
  final String? userPhotoUrl;
  final String text;
  final DateTime createdAt;
  final int likeCount;
  final List<String> likedBy;

  Comment({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.username,
    this.userPhotoUrl,
    required this.text,
    required this.createdAt,
    this.likeCount = 0,
    this.likedBy = const [],
  });

  // Create from Firestore document
  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      videoId: data['videoId'] ?? '',
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      userPhotoUrl: data['userPhotoUrl'],
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likeCount: data['likeCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'videoId': videoId,
      'userId': userId,
      'username': username,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
      'likedBy': likedBy,
    };
  }

  // Create a copy of the comment with updated fields
  Comment copyWith({
    String? id,
    String? videoId,
    String? userId,
    String? username,
    String? userPhotoUrl,
    String? text,
    DateTime? createdAt,
    int? likeCount,
    List<String>? likedBy,
  }) {
    return Comment(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      likedBy: likedBy ?? this.likedBy,
    );
  }
} 