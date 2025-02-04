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
  Map<int, bool> _viewCounted = {}; // Track if view has been counted
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
      // Pause all videos except the current one
      _controllers.forEach((i, controller) {
        if (i != page) {
          controller.pause();
        }
      });
      // Play the current video if it exists
      if (_controllers[page] != null) {
        _controllers[page]!.play();
      }
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

  void _checkVideoProgress(int index, Video video) {
    if (_controllers[index] == null || _viewCounted[index] == true) return;

    final controller = _controllers[index]!;
    final duration = controller.value.duration;
    final position = controller.value.position;
    final progress = position.inMilliseconds / duration.inMilliseconds;

    // If video is watched 75% and view hasn't been counted yet
    if (progress >= 0.75 && _viewCounted[index] != true) {
      _viewCounted[index] = true;
      _videoService.incrementViewCount(video.id);
    }
  }

  Future<void> _initializeController(String videoUrl, int index, Video video) async {
    if (_controllers[index] != null) {
      await _controllers[index]!.play();
      return;
    }

    final controller = VideoPlayerController.network(videoUrl);
    _controllers[index] = controller;
    _viewCounted[index] = false; // Initialize view count tracking
    
    try {
      await controller.initialize();
      await controller.setLooping(true);
      
      // Add listener for progress tracking
      controller.addListener(() {
        if (index == _currentVideoIndex) {
          _checkVideoProgress(index, video);
        }
      });

      if (index == _currentVideoIndex) {
        await controller.play();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing video controller: $e');
      _controllers.remove(index);
      _viewCounted.remove(index);
    }
  }

  void _cleanupControllers() {
    final keysToKeep = {_currentVideoIndex - 1, _currentVideoIndex, _currentVideoIndex + 1};
    
    final keysToRemove = _controllers.keys.where((k) => !keysToKeep.contains(k)).toList();
    
    for (final key in keysToRemove) {
      final controller = _controllers[key];
      if (controller != null) {
        controller.pause();
        controller.dispose();
        _controllers.remove(key);
        _viewCounted.remove(key); // Clean up view count tracking
      }
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

      await _initializeController(newVideo.videoUrl, _controllers.length, newVideo);

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
                'Error loading videos',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: LoadingIndicator());
          }

          final videos = snapshot.data!;
          
          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 64,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'no videos yet'.toLowerCase(),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'be the first to upload!'.toLowerCase(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _pickVideo,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        'upload video'.toLowerCase(),
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: videos.length + 1,
            onPageChanged: (index) {
              setState(() {
                _currentVideoIndex = index;
              });
            },
            itemBuilder: (context, index) {
              if (index == videos.length) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'you\'re all caught up!'.toLowerCase(),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'check back later for more videos'.toLowerCase(),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => _pageController.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'back to top'.toLowerCase(),
                            style: TextStyle(
                              color: AppColors.background,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final video = videos[index];
              if (index == _currentVideoIndex) {
                _initializeController(video.videoUrl, index, video);
              }

              return GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity! < 0 && index < videos.length) {
                    _pageController.animateToPage(
                      index + 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  } else if (details.primaryVelocity! > 0 && index > 0) {
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
                    if (_controllers[index]?.value.isInitialized == true)
                      GestureDetector(
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
                    else
                      Container(
                        color: AppColors.background,
                      ),

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

                    if (_controllers[index]?.value.isInitialized == true) ...[
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

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
                    ],

                    if (_controllers[index]?.value.isInitialized == true)
                      Center(
                        child: AnimatedOpacity(
                          opacity: _controllers[index]!.value.isPlaying ? 0.0 : 1.0,
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