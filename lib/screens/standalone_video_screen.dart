import 'package:flutter/material.dart';
import '../models/video.dart';
import '../theme/colors.dart';
import 'video_feed_screen.dart';

class StandaloneVideoScreen extends StatelessWidget {
  final List<Video> videos;
  final int initialIndex;

  const StandaloneVideoScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: VideoFeedScreen(
        videos: videos,
        initialIndex: initialIndex,
        showBackSidebar: true,
      ),
    );
  }
} 