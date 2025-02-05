import 'package:flutter/material.dart';
import '../models/video.dart';
import '../theme/colors.dart';
import '../extensions/string_extensions.dart';
import '../screens/video_screen.dart';
import '../screens/video_feed_screen.dart';

class VideoPreview extends StatelessWidget {
  final Video video;
  final bool showTitle;
  final bool showCreator;
  final double? width;
  final double? height;
  final List<Video>? videos;  // The current list of videos being displayed
  final int? currentIndex;    // Position of this video in the list
  final VoidCallback? onTap;

  const VideoPreview({
    super.key,
    required this.video,
    this.showTitle = false,
    this.showCreator = false,
    this.width,
    this.height,
    this.videos,
    this.currentIndex,
    this.onTap,
  });

  void _openVideo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoFeedScreen(
          videos: videos ?? [video],
          initialIndex: currentIndex ?? 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => _openVideo(context),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  video.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.cardBackground,
                      child: Center(
                        child: Icon(
                          Icons.video_library,
                          color: AppColors.accent,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Play button overlay
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    size: 32,
                    color: AppColors.accent,
                  ),
                ),
              ),

              // Info overlay at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showTitle) ...[
                        Text(
                          video.title.lowercase,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (showCreator) ...[
                        Text(
                          video.creatorUsername.lowercase,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 12,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${video.viewCount} views'.lowercase,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 