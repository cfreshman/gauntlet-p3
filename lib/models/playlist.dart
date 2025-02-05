import 'package:cloud_firestore/cloud_firestore.dart';

class Playlist {
  final String id;
  final String name;
  final String userId;
  final List<String> videoIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? firstVideoThumbnail;  // Optional thumbnail from first video

  Playlist({
    required this.id,
    required this.name,
    required this.userId,
    this.videoIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.firstVideoThumbnail,
  });

  factory Playlist.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Playlist(
      id: doc.id,
      name: data['name'] ?? '',
      userId: data['userId'] ?? '',
      videoIds: List<String>.from(data['videoIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      firstVideoThumbnail: data['firstVideoThumbnail'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'userId': userId,
      'videoIds': videoIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'firstVideoThumbnail': firstVideoThumbnail,
    };
  }

  Playlist copyWith({
    String? name,
    List<String>? videoIds,
    String? firstVideoThumbnail,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      userId: userId,
      videoIds: videoIds ?? this.videoIds,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      firstVideoThumbnail: firstVideoThumbnail ?? this.firstVideoThumbnail,
    );
  }
} 