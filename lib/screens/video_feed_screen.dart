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
import '../widgets/comment_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/add_to_playlist_dialog.dart';

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
  bool _showComments = false;
  final Map<String, int> _localLikeCounts = {};
  final Set<String> _likeInProgress = {};

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

  void _toggleComments() {
    setState(() {
      _showComments = !_showComments;
    });
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
      body: SafeArea(
        child: SidebarLayout(
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

              return Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: videos.length + 1,
                    onPageChanged: (index) {
                      setState(() {
                        _currentVideoIndex = index;
                        _showComments = false;
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
                          if (!_showComments) {
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
                                isInFeed: false,
                                onCommentTap: _toggleComments,
                              ),

                            // Video info overlay at bottom
                            Positioned(
                              left: 16,
                              right: 96, // Make room for controls on right
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.background.withOpacity(0.5),
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
                                    const SizedBox(height: 4),
                                    // View count
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.remove_red_eye_outlined,
                                          size: 16,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${video.viewCount} views'.toLowerCase(),
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (video.description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        video.description.toLowerCase(),
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
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
                                  ],
                                ),
                              ),
                            ),

                            // Right side controls
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Like button
                                  StreamBuilder<bool>(
                                    stream: _videoService.hasLiked(video.id),
                                    builder: (context, snapshot) {
                                      final hasLiked = snapshot.data ?? false;
                                      final likeCount = _localLikeCounts[video.id] ?? video.likeCount;
                                      
                                      return GestureDetector(
                                        onTap: _likeInProgress.contains(video.id) ? null : () async {
                                          // Prevent rapid taps
                                          if (_likeInProgress.contains(video.id)) return;
                                          _likeInProgress.add(video.id);
                                          
                                          // Update local like count
                                          setState(() {
                                            _localLikeCounts[video.id] = likeCount + (hasLiked ? -1 : 1);
                                          });
                                          
                                          try {
                                            await _videoService.toggleLike(video.id);
                                          } catch (e) {
                                            // Revert on error
                                            setState(() {
                                              _localLikeCounts[video.id] = likeCount;
                                            });
                                            
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
                                          } finally {
                                            if (mounted) {
                                              _likeInProgress.remove(video.id);
                                            }
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.background.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                hasLiked ? Icons.favorite : Icons.favorite_border,
                                                size: 28,
                                                color: hasLiked ? AppColors.accent : AppColors.textPrimary,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$likeCount'.toLowerCase(),
                                                style: TextStyle(
                                                  color: hasLiked ? AppColors.accent : AppColors.textPrimary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Comment button
                                  GestureDetector(
                                    onTap: _toggleComments,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.background.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.comment_outlined,
                                            size: 28,
                                            color: _showComments ? AppColors.accent : AppColors.textPrimary,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${video.commentCount}'.toLowerCase(),
                                            style: TextStyle(
                                              color: _showComments ? AppColors.accent : AppColors.textPrimary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Add to playlist button
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AddToPlaylistDialog(
                                          videoId: video.id,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.background.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Icon(
                                        Icons.bookmark_outline,
                                        size: 28,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  if (_showComments && _currentVideoIndex < videos.length)
                    Positioned(
                      right: 0,  // Align to right side
                      top: 0,
                      bottom: 0,
                      width: MediaQuery.of(context).size.width * 0.6,  // Take up 60% of screen width
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _showComments ? 1.0 : 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(-2, 0),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AppColors.divider,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'comments'.toLowerCase(),
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StreamBuilder<DocumentSnapshot>(
                                        stream: _videoService.firestore
                                            .collection('videos')
                                            .doc(videos[_currentVideoIndex].id)
                                            .snapshots(),
                                        builder: (context, snapshot) {
                                          final commentCount = snapshot.hasData
                                              ? (snapshot.data!.data() as Map<String, dynamic>)['commentCount'] ?? 0
                                              : videos[_currentVideoIndex].commentCount;
                                          return Text(
                                            '($commentCount)'.toLowerCase(),
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 16,
                                            ),
                                          );
                                        },
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          color: AppColors.textPrimary,
                                        ),
                                        onPressed: _toggleComments,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: CommentList(
                                    key: ValueKey(videos[_currentVideoIndex].id),
                                    videoId: videos[_currentVideoIndex].id,
                                    showInput: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
} 