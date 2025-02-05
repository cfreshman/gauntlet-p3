import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video.dart';
import '../services/video_service.dart';
import '../theme/colors.dart';
import 'add_to_playlist_dialog.dart';

class VideoViewer extends StatefulWidget {
  final Video video;
  final bool autoPlay;
  final bool showControls;
  final bool isInFeed;
  final VoidCallback? onVideoEnd;
  final VoidCallback? onCommentTap;

  const VideoViewer({
    super.key,
    required this.video,
    this.autoPlay = true,
    this.showControls = true,
    this.isInFeed = false,
    this.onVideoEnd,
    this.onCommentTap,
  });

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  late VideoPlayerController _controller;
  final _videoService = VideoService();
  bool _viewCounted = false;
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    _controller = VideoPlayerController.network(widget.video.videoUrl);
    
    try {
      await _controller.initialize();
      _controller.addListener(_handleVideoProgress);
      
      if (widget.autoPlay) {
        await _controller.play();
      }
      
      // Loop only if in feed
      await _controller.setLooping(widget.isInFeed);
      
      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing video controller: $e');
    }
  }

  void _handleVideoProgress() {
    if (!_viewCounted && _controller.value.isInitialized) {
      final duration = _controller.value.duration;
      final position = _controller.value.position;
      final progress = position.inMilliseconds / duration.inMilliseconds;

      if (progress >= 0.75) {
        _viewCounted = true;
        _videoService.incrementViewCount(widget.video.id);
      }

      if (!widget.isInFeed && progress >= 0.99) {
        widget.onVideoEnd?.call();
      }
    }
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });

    // Auto-hide overlay after 3 seconds if showing
    if (_showOverlay) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showOverlay = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleVideoProgress);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container(
        color: AppColors.background,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _toggleOverlay();
        setState(() {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          if (widget.showControls) ...[
            // Video overlay controls
            AnimatedOpacity(
              opacity: _showOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Right side controls
                    Positioned(
                      right: 8,
                      bottom: 80,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Like button
                          StreamBuilder<bool>(
                            stream: _videoService.hasLiked(widget.video.id),
                            builder: (context, snapshot) {
                              final hasLiked = snapshot.data ?? false;
                              return _buildActionButton(
                                icon: hasLiked ? Icons.favorite : Icons.favorite_border,
                                label: widget.video.likeCount.toString(),
                                color: hasLiked ? AppColors.accent : Colors.white,
                                onTap: () => _videoService.toggleLike(widget.video.id),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Comment button
                          StreamBuilder<bool>(
                            stream: Stream.value(true), // Always build
                            builder: (context, _) {
                              return _buildActionButton(
                                icon: Icons.comment_outlined,
                                label: widget.video.commentCount.toString(),
                                color: Colors.white,
                                onTap: () {
                                  // Keep overlay visible when opening comments
                                  setState(() {
                                    _showOverlay = true;
                                  });
                                  widget.onCommentTap?.call();
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Add to playlist button
                          if (!widget.isInFeed)
                            StreamBuilder<bool>(
                              stream: Stream.value(true), // Always build
                              builder: (context, _) {
                                return _buildActionButton(
                                  icon: Icons.bookmark_outline,
                                  label: 'Playlist',
                                  color: Colors.white,
                                  onTap: () {
                                    // Keep overlay visible when adding to playlist
                                    setState(() {
                                      _showOverlay = true;
                                    });
                                    showDialog(
                                      context: context,
                                      builder: (context) => AddToPlaylistDialog(
                                        videoId: widget.video.id,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    // Progress bar at bottom
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress bar
                          VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: AppColors.accent,
                              bufferedColor: AppColors.accent.withOpacity(0.3),
                              backgroundColor: AppColors.background.withOpacity(0.5),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          // Time indicator
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_controller.value.position),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(_controller.value.duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Play/Pause indicator
                    Center(
                      child: AnimatedOpacity(
                        opacity: !_controller.value.isPlaying && _showOverlay ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 50,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toLowerCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
} 