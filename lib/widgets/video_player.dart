import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:your_app/providers/audio_state_provider.dart';
import 'package:your_app/styles/app_colors.dart';
import 'package:video_player/video_player.dart';

class VideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final bool autoplay;
  final VoidCallback? onVideoEnd;

  const VideoPlayer({
    super.key,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.autoplay = true,
    this.onVideoEnd,
  });

  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(widget.videoUrl);
    
    try {
      await _controller.initialize();
      // Get global mute state instead of defaulting to muted
      final audioState = context.read<AudioStateProvider>();
      _controller.setVolume(audioState.isMuted ? 0 : 1);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          if (widget.autoplay) {
            _controller.play();
          }
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void _handleDoubleTap() {
    final audioState = context.read<AudioStateProvider>();
    audioState.toggleMute();
    _controller.setVolume(audioState.isMuted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioStateProvider>(
      builder: (context, audioState, child) {
        return GestureDetector(
          onDoubleTap: _handleDoubleTap,
          child: Stack(
            children: [
              if (_isInitialized)
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              else
                Image.network(
                  widget.thumbnailUrl,
                  fit: BoxFit.cover,
                ),

              // Only show unmute hint if muted and on web
              if (audioState.isMuted && kIsWeb)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Text(
                    'double tap to unmute'.toLowerCase(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
} 