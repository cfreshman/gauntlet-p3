import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/video.dart';
import '../services/video_service.dart';
import '../theme/colors.dart';
import 'add_to_playlist_dialog.dart';
import '../screens/profile_screen.dart';

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
    _controller = VideoPlayerController.network(
      widget.video.videoUrl,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
      ),
    );
    
    try {
      await _controller.initialize();
      _controller.addListener(_handleVideoProgress);
      
      if (widget.autoPlay) {
        // Only start muted on web
        if (kIsWeb) {
          await _controller.setVolume(0.0);
        }
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

    return Stack(
      children: [
        // Video player with tap gesture
        GestureDetector(
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
          onDoubleTap: () {
            setState(() {
              if (_controller.value.volume > 0) {
                _controller.setVolume(0.0);
              } else {
                _controller.setVolume(1.0);
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
              
              // Volume indicator
              if (_controller.value.volume == 0)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.volume_off,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        if (kIsWeb) ...[
                          const SizedBox(width: 8),
                          Text(
                            'double tap to unmute',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Progress bar at top
        if (widget.showControls)
          Positioned(
            left: 0,
            right: 0,
            top: widget.isInFeed ? 0 : MediaQuery.of(context).padding.top,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTapDown: (details) {
                  final box = context.findRenderObject() as RenderBox;
                  final tapPos = details.localPosition;
                  final relative = tapPos.dx / box.size.width;
                  _controller.seekTo(
                    Duration(milliseconds: (_controller.value.duration.inMilliseconds * relative).toInt()),
                  );
                },
                child: Container(
                  height: 20,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: AppColors.accent,
                      bufferedColor: AppColors.accent.withOpacity(0.3),
                      backgroundColor: AppColors.background.withOpacity(0.5),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
} 