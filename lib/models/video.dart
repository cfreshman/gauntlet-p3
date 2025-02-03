import 'package:cloud_firestore/cloud_firestore.dart';

class Video {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String creatorId;
  final String creatorName;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final int shareCount;
  final DateTime createdAt;
  final List<String> hashtags;
  final String soundId;      // Reference to the sound/music used
  final String soundName;    // Name of the sound/music

  Video({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.creatorId,
    required this.creatorName,
    this.likeCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.shareCount = 0,
    required this.createdAt,
    this.hashtags = const [],
    this.soundId = '',
    this.soundName = '',
  });

  factory Video.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Video(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      soundId: data['soundId'] ?? '',
      soundName: data['soundName'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'viewCount': viewCount,
      'shareCount': shareCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'hashtags': hashtags,
      'soundId': soundId,
      'soundName': soundName,
    };
  }
} 