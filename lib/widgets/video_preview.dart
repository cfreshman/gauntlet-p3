import 'package:flutter/material.dart';
import '../models/video.dart';
import '../theme/colors.dart';
import '../extensions/string_extensions.dart';
import '../screens/video_screen.dart';
import '../screens/video_feed_screen.dart';
import '../screens/standalone_video_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;

class VideoPreview extends StatelessWidget {
  final Video video;
  final bool showTitle;
  final bool showCreator;
  final bool showTimeAgo;
  final bool showDuration;
  final double? width;
  final double? height;
  final List<Video>? videos;  // The current list of videos being displayed
  final int? currentIndex;    // Position of this video in the list
  final VoidCallback? onTap;

  const VideoPreview({
    super.key,
    required this.video,
    this.showTitle = true,
    this.showCreator = true,
    this.showTimeAgo = false,
    this.showDuration = false,
    this.width,
    this.height,
    this.videos,
    this.currentIndex,
    this.onTap,
  });

  Future<String> _getLatestUsername() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(video.creatorId)
          .get();
      
      if (userDoc.exists) {
        return userDoc.data()?['displayName'] ?? video.creatorUsername;
      }
    } catch (e) {
      debugPrint('Error fetching username: $e');
    }
    return video.creatorUsername;
  }

  void _openVideo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StandaloneVideoScreen(
          videos: videos ?? [video],
          initialIndex: currentIndex ?? 0,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '${duration.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
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
            fit: StackFit.passthrough,
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

              // Duration overlay (top right)
              if (showDuration)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(video.duration ?? const Duration(seconds: 0)),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

              // Info overlay at bottom
              if (showTitle || showCreator || showTimeAgo)
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
                        // View count
                        Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 12,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${video.viewCount}'.lowercase,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        if (showTitle) ...[
                          const SizedBox(height: 2),
                          Text(
                            video.title.lowercase,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        Row(
                          children: [
                            if (showCreator) 
                              Expanded(
                                child: FutureBuilder<String>(
                                  future: _getLatestUsername(),
                                  builder: (context, snapshot) {
                                    final username = snapshot.data?.toLowerCase() ?? video.creatorUsername.toLowerCase();
                                    return Row(
                                      children: [
                                        Text(
                                          '@$username',
                                          style: TextStyle(
                                            color: AppColors.accent,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            if (showTimeAgo) ...[
                              Text(
                                timeago.format(video.createdAt).toLowerCase(),
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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