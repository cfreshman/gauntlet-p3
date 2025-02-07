import 'package:flutter/material.dart';
import '../models/video.dart';
import '../widgets/video_preview.dart';

class VideoGrid extends StatelessWidget {
  final List<Video> videos;
  final bool showCreator;

  const VideoGrid({
    super.key,
    required this.videos,
    this.showCreator = true,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 16 / 9,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return SizedBox(
          height: 180,
          child: VideoPreview(
            video: video,
            showTitle: true,
            showCreator: showCreator,
            videos: videos,
            currentIndex: index,
            showTimeAgo: true,
            showDuration: true,
          ),
        );
      },
    );
  }
} 