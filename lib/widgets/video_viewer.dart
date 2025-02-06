import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/video.dart';
import '../services/video_service.dart';
import '../theme/colors.dart';
import 'add_to_playlist_dialog.dart';
import '../screens/profile_screen.dart';
import 'dart:async';

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
  Timer? _singleTapTimer;

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

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
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

  void _handleTap() {
    _singleTapTimer = Timer(const Duration(milliseconds: 200), () {
      _togglePlayPause();
      _toggleOverlay();
    });
  }

  void _handleDoubleTap() {
    _singleTapTimer?.cancel();
    setState(() {
      if (_controller.value.volume > 0) {
        _controller.setVolume(0.0);
      } else {
        _controller.setVolume(1.0);
      }
    });
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
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
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _handleTap(),
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          
          // Pause indicator overlay (shows only when paused)
          if (!_controller.value.isPlaying)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pause,
                  color: AppColors.accent,
                  size: 48,
                ),
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

          // Progress bar at top
          if (widget.showControls)
            Positioned(
              left: 0,
              right: 0,
              top: widget.isInFeed ? 0 : MediaQuery.of(context).padding.top,
              child: Stack(
                children: [
                  // Larger transparent scrubber for better touch target
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: Colors.transparent,
                      bufferedColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  // Visual scrubber
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
                ],
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