import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video.dart';
import '../theme/colors.dart';
import '../services/video_service.dart';
import 'add_to_playlist_dialog.dart';

class VideoCard extends StatefulWidget {
  final Video video;
  final VoidCallback? onTap;

  const VideoCard({
    super.key,
    required this.video,
    this.onTap,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  final _videoService = VideoService();

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.video.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showAddToPlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => AddToPlaylistDialog(videoId: widget.video.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.background,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Player
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _isInitialized
                  ? VideoPlayer(_controller)
                  : Image.network(
                      widget.video.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.background.withOpacity(0.1),
                          child: Center(
                            child: Icon(
                              Icons.error_outline,
                              color: AppColors.accent,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            
            // Video Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                ),
              ],
            ),

            // Video Info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.video.description,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      StreamBuilder<bool>(
                        stream: _videoService.hasLiked(widget.video.id),
                        builder: (context, snapshot) {
                          final hasLiked = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(
                              hasLiked ? Icons.favorite : Icons.favorite_border,
                              color: hasLiked ? AppColors.accent : AppColors.textPrimary,
                            ),
                            onPressed: () => _videoService.toggleLike(widget.video.id),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.playlist_add,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: _showAddToPlaylistDialog,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.share,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () {
                          // TODO: Implement share
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 