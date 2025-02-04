import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video.dart';
import '../services/video_service.dart';
import '../theme/colors.dart';

class VideoViewer extends StatefulWidget {
  final Video video;
  final bool autoPlay;
  final bool showControls;
  final bool isInFeed;
  final VoidCallback? onVideoEnd;

  const VideoViewer({
    super.key,
    required this.video,
    this.autoPlay = true,
    this.showControls = true,
    this.isInFeed = false,
    this.onVideoEnd,
  });

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  late VideoPlayerController _controller;
  final _videoService = VideoService();
  bool _viewCounted = false;

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
            // Progress bar background (invisible touch target)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: Colors.transparent,
                  bufferedColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            // Visible progress bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
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

            // Play/Pause indicator
            Center(
              child: AnimatedOpacity(
                opacity: _controller.value.isPlaying ? 0.0 : 1.0,
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
        ],
      ),
    );
  }
} 