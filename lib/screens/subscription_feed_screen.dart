import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video.dart';
import '../theme/colors.dart';
import 'video_feed_screen.dart';

class SubscriptionFeedScreen extends StatefulWidget {
  const SubscriptionFeedScreen({super.key});

  @override
  State<SubscriptionFeedScreen> createState() => _SubscriptionFeedScreenState();
}

class _SubscriptionFeedScreenState extends State<SubscriptionFeedScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<List<Video>> _getSubscriptionFeed() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .asyncMap((userDoc) async {
          if (!userDoc.exists) return [];
          final data = userDoc.data() as Map<String, dynamic>;
          final following = List<String>.from(data['following'] ?? []);
          if (following.isEmpty) return [];

          final videosQuery = await _firestore
              .collection('videos')
              .where('creatorId', whereIn: following)
              .orderBy('createdAt', descending: true)
              .get();

          return videosQuery.docs.map((doc) => Video.fromFirestore(doc)).toList();
        });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Video>>(
      stream: _getSubscriptionFeed(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}'.toLowerCase(),
              style: TextStyle(color: AppColors.error),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.accent,
            ),
          );
        }

        final videos = snapshot.data!;
        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.subscriptions,
                  size: 64,
                  color: AppColors.accent.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'follow creators to see their videos here'.toLowerCase(),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return VideoFeedScreen(
          videos: videos,
          showBackSidebar: false,
          initialIndex: 0,
        );
      },
    );
  }
} 