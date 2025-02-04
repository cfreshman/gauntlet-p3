import 'package:flutter/material.dart';
import '../models/video.dart';
import '../theme/colors.dart';
import '../widgets/video_viewer.dart';
import '../services/video_service.dart';

class VideoScreen extends StatefulWidget {
  final Video video;

  const VideoScreen({
    super.key,
    required this.video,
  });

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final _videoService = VideoService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.video.title.toLowerCase(),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoViewer(
              video: widget.video,
              autoPlay: true,
              showControls: true,
              isInFeed: false,
              onVideoEnd: () {
                // Could implement "up next" functionality here
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video.description.toLowerCase(),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: widget.video.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        '#${tag.toLowerCase()}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.remove_red_eye_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.video.viewCount}'.toLowerCase(),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () async {
                        try {
                          await _videoService.toggleLike(widget.video.id);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString(),
                                  style: TextStyle(color: AppColors.background),
                                ),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      child: StreamBuilder<bool>(
                        stream: _videoService.hasLiked(widget.video.id),
                        builder: (context, snapshot) {
                          final hasLiked = snapshot.data ?? false;
                          return Row(
                            children: [
                              Icon(
                                hasLiked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: hasLiked ? AppColors.accent : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.video.likeCount}'.toLowerCase(),
                                style: TextStyle(
                                  color: hasLiked ? AppColors.accent : AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 