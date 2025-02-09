import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/video.dart';
import '../services/video_service.dart';
import '../theme/colors.dart';
import 'add_to_playlist_dialog.dart';
import '../screens/profile_screen.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/audio_state_provider.dart';
import '../providers/captions_state_provider.dart';

class VideoViewer extends StatefulWidget {
  final Video video;
  final VideoPlayerController controller;
  final bool showControls;
  final bool isInFeed;
  final VoidCallback? onVideoEnd;
  final VoidCallback? onCommentTap;

  const VideoViewer({
    super.key,
    required this.video,
    required this.controller,
    this.showControls = true,
    this.isInFeed = false,
    this.onVideoEnd,
    this.onCommentTap,
  });

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  final _videoService = VideoService();
  bool _viewCounted = false;
  bool _showOverlay = false;
  Timer? _singleTapTimer;
  bool _userPaused = false;  // Track if video was paused by user action
  String? _captionsUrl;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleVideoProgress);
    // Add position listener for captions
    widget.controller.addListener(() {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() => _currentPosition = widget.controller.value.position);
      }
    });
    _loadCaptions();
  }

  Future<void> _loadCaptions() async {
    if (widget.video.captionsUrl != null) {
      setState(() => _captionsUrl = widget.video.captionsUrl);
    } else {
      final url = await _videoService.getOrCreateCaptions(widget.video.id);
      if (mounted && url != null) {
        setState(() => _captionsUrl = url);
      }
    }
  }

  void _handleVideoProgress() {
    if (!_viewCounted && widget.controller.value.isInitialized) {
      final duration = widget.controller.value.duration;
      final position = widget.controller.value.position;
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
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
        _userPaused = true;
      } else {
        widget.controller.play();
        _userPaused = false;
      }
    });
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });

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
    final audioState = context.read<AudioStateProvider>();
    audioState.toggleMute();
    widget.controller.setVolume(audioState.isMuted ? 0.0 : 1.0);
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    widget.controller.removeListener(_handleVideoProgress);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.value.isInitialized) {
      return Container(
        color: AppColors.background,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _togglePlayPause();
        _toggleOverlay();
      },
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: widget.controller.value.size.width,
              height: widget.controller.value.size.height,
              child: VideoPlayer(widget.controller),
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
                    widget.controller,
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
                    widget.controller,
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

          // Captions toggle button
          if (_captionsUrl != null)
            Positioned(
              top: 16,
              left: 16,
              child: Consumer<CaptionsStateProvider>(
                builder: (context, captionsState, child) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => captionsState.toggleCaptions(),
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
                          captionsState.showCaptions ? Icons.closed_caption : Icons.closed_caption_off,
                          color: captionsState.showCaptions ? AppColors.accent : AppColors.textPrimary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Captions display - only show when we have actual captions loaded
          if (_captionsUrl != null)
            Consumer<CaptionsStateProvider>(
              builder: (context, captionsState, child) {
                if (!captionsState.showCaptions) return const SizedBox.shrink();
                return Positioned(
                  left: 16,
                  top: widget.isInFeed ? 60 : MediaQuery.of(context).padding.top + 60,
                  child: StreamBuilder<String?>(
                    stream: _videoService.getCaptionsStream(widget.video.id, _currentPosition),
                    builder: (context, snapshot) {
                      final captionText = snapshot.data;
                      if (captionText == null || captionText.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width - 240
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.background.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            captionText,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          
          // Pause indicator overlay (shows only when explicitly paused by user)
          if (!widget.controller.value.isPlaying && _userPaused)
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
          Consumer<AudioStateProvider>(
            builder: (context, audioState, child) {
              if (!audioState.isMuted) return const SizedBox.shrink();
              
              return Positioned(
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
              );
            },
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