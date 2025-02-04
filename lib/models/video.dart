import 'package:cloud_firestore/cloud_firestore.dart';

class Video {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String creatorId;
  final String creatorUsername;
  final List<String> tags;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final int viewCount;

  Video({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.creatorId,
    required this.creatorUsername,
    required this.tags,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
  });

  // Create from Firestore document
  factory Video.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Video(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      creatorId: data['creatorId'] ?? '',
      creatorUsername: data['creatorUsername'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'creatorId': creatorId,
      'creatorUsername': creatorUsername,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
      'commentCount': commentCount,
      'viewCount': viewCount,
    };
  }
} 