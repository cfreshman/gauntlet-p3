import 'package:flutter/material.dart';
import '../models/video.dart';
import '../theme/colors.dart';
import '../extensions/string_extensions.dart';
import '../screens/video_screen.dart';
import '../screens/video_feed_screen.dart';
import '../screens/standalone_video_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.showTitle = true,
    this.showCreator = true,
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
          child: height != null ? Stack(
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
              if (showTitle || showCreator)
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
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
                            if (showCreator)
                              const SizedBox(width: 8),
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
                      ],
                    ),
                  ),
                ),
            ],
          ) : AspectRatio(
            aspectRatio: 16 / 9,
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
                if (showTitle || showCreator)
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
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
                              if (showCreator)
                                const SizedBox(width: 8),
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
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 