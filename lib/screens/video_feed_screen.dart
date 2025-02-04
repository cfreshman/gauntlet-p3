import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:video_player/video_player.dart';
import '../models/video.dart';
import '../services/video_service.dart';
import '../theme/colors.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../widgets/loading_indicator.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final _videoService = VideoService();
  final _authService = AuthService();
  final _pageController = PageController();
  Map<int, VideoPlayerController> _controllers = {};
  int _currentVideoIndex = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_handlePageChange);
  }

  void _handlePageChange() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentVideoIndex) {
      setState(() => _currentVideoIndex = page);
      _controllers.forEach((i, controller) {
        if (i != page) controller.pause();
      });
      _cleanupControllers();
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeController(String videoUrl, int index) async {
    if (_controllers[index] != null) {
      // If controller exists, just play it
      await _controllers[index]!.play();
      return;
    }

    final controller = VideoPlayerController.network(videoUrl);
    _controllers[index] = controller;
    
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing video controller: $e');
    }
  }

  void _cleanupControllers() {
    final keysToKeep = {_currentVideoIndex - 1, _currentVideoIndex, _currentVideoIndex + 1};
    
    // Fix concurrent modification by creating a list of keys to remove
    final keysToRemove = _controllers.keys.where((k) => !keysToKeep.contains(k)).toList();
    
    for (final key in keysToRemove) {
      _controllers[key]?.pause();
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }
  }

  Future<void> _pickVideo() async {
    try {
      final currentUser = _authService.auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please login to upload videos'),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      
      if (video == null) return;

      setState(() => _isLoading = true);

      // Use the existing uploadVideo method
      final newVideo = await _videoService.uploadVideo(
        videoFile: video,
        title: 'Uploaded Video',
        description: 'My custom video',
        tags: ['custom'],
        onProgress: (progress) {
          // Optionally handle upload progress
          print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        },
      );

      await _initializeController(newVideo.videoUrl, _controllers.length);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Video uploaded successfully',
              style: TextStyle(color: AppColors.background),
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (e) {
      print('Error picking video: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error uploading video: ${e.toString()}',
              style: TextStyle(color: AppColors.background),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<Video>>(
        stream: _videoService.getVideoFeed(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const LoadingIndicator();
          }

          final videos = snapshot.data!;
          if (videos.isEmpty) {
            return Center(
              child: Text(
                'No videos yet',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            physics: const NeverScrollableScrollPhysics(),
            pageSnapping: true,
            itemBuilder: (context, index) {
              final video = videos[index];
              if (index == _currentVideoIndex) {
                _initializeController(video.videoUrl, index);
              }

              return GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity! < 0 && index < videos.length - 1) {
                    // Swipe up - next video
                    _pageController.animateToPage(
                      index + 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  } else if (details.primaryVelocity! > 0 && index > 0) {
                    // Swipe down - previous video
                    _pageController.animateToPage(
                      index - 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video Player
                    _controllers[index]?.value.isInitialized == true
                        ? GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_controllers[index]!.value.isPlaying) {
                                  _controllers[index]!.pause();
                                } else {
                                  _controllers[index]!.play();
                                }
                              });
                            },
                            child: FittedBox(
                              fit: BoxFit.cover,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: _controllers[index]!.value.size.width,
                                height: _controllers[index]!.value.size.height,
                                child: VideoPlayer(_controllers[index]!),
                              ),
                            ),
                          )
                        : Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          ),

                    // Video Info Overlay
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.title.toLowerCase(),
                              style: TextStyle(
                                fontFamily: 'Menlo',
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              video.description.toLowerCase(),
                              style: TextStyle(
                                fontFamily: 'Menlo',
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: video.tags.map((tag) {
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
                                      fontFamily: 'Menlo',
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.remove_red_eye_outlined, 
                                  size: 16, 
                                  color: AppColors.textSecondary
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${video.viewCount}'.toLowerCase(),
                                  style: TextStyle(
                                    fontFamily: 'Menlo',
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(Icons.favorite_border, 
                                  size: 16, 
                                  color: AppColors.textSecondary
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${video.likeCount}',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // First the invisible touch target
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: VideoProgressIndicator(
                        _controllers[index]!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: Colors.transparent,
                          bufferedColor: Colors.transparent,
                          backgroundColor: Colors.transparent,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),  // Large touch target
                      ),
                    ),

                    // Then the visible progress bar
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: VideoProgressIndicator(
                        _controllers[index]!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: AppColors.accent,
                          bufferedColor: AppColors.accent.withOpacity(0.3),
                          backgroundColor: AppColors.background.withOpacity(0.5),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),

                    // Play/Pause Indicator
                    if (_controllers[index]?.value.isInitialized == true)
                      Center(
                        child: AnimatedOpacity(
                          opacity:
                              _controllers[index]!.value.isPlaying ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Icon(
                              _controllers[index]!.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 50,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
} 