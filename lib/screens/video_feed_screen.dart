import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/video.dart';
import '../services/video_service.dart';
import '../theme/colors.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/video_viewer.dart';
import '../widgets/sidebar_layout.dart';

class VideoFeedScreen extends StatefulWidget {
  final List<Video>? videos;  // Optional list of videos to show instead of feed
  final int initialIndex;     // Starting position in the video list

  const VideoFeedScreen({
    super.key,
    this.videos,
    this.initialIndex = 0,
  });

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final _videoService = VideoService();
  final _authService = AuthService();
  late final PageController _pageController;
  int _currentVideoIndex = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentVideoIndex = widget.initialIndex;
    _pageController.addListener(_handlePageChange);
  }

  void _handlePageChange() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentVideoIndex) {
      setState(() => _currentVideoIndex = page);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    super.dispose();
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

      final newVideo = await _videoService.uploadVideo(
        videoFile: video,
        title: 'Uploaded Video',
        description: 'My custom video',
        tags: ['custom'],
        onProgress: (progress) {
          print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        },
      );

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
      body: SidebarLayout(
        showBackButton: widget.videos != null,
        child: StreamBuilder<List<Video>>(
          stream: widget.videos != null 
              ? Stream.value(widget.videos!) 
              : _videoService.getVideoFeed(),
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
                      if (index == _currentVideoIndex)
                        VideoViewer(
                          video: video,
                          autoPlay: true,
                          showControls: true,
                          isInFeed: true,
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
                                  GestureDetector(
                                    onTap: () async {
                                      try {
                                        await _videoService.toggleLike(video.id);
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
                                      stream: _videoService.hasLiked(video.id),
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
                                              '${video.likeCount}',
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
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
} 