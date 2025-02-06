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
import '../screens/profile_screen.dart';
import '../screens/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class VideoFeedScreen extends StatefulWidget {
  final List<Video>? videos;  // Optional list of videos to show instead of feed
  final int initialIndex;     // Starting position in the video list
  final bool showBackSidebar; // Whether to show the back sidebar

  const VideoFeedScreen({
    super.key,
    this.videos,
    this.initialIndex = 0,
    this.showBackSidebar = true,
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
  bool _showFullInfo = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentVideoIndex = widget.initialIndex;
    _pageController.addListener(_handlePageChange);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showFullInfo = false);
      }
    });
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

  Future<void> _deleteVideo(Video video) async {
    try {
      await _videoService.deleteVideo(video.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'video deleted'.toLowerCase(),
              style: TextStyle(color: AppColors.background),
            ),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', '').toLowerCase(),
              style: TextStyle(color: AppColors.background),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleLike(Video video, bool currentlyLiked) async {
    // Don't allow multiple like operations at once
    if (_likeInProgress.contains(video.id)) return;

    // Update local state immediately
    setState(() {
      _likeInProgress.add(video.id);
      _localLikeCounts[video.id] = (_localLikeCounts[video.id] ?? video.likeCount) + (currentlyLiked ? -1 : 1);
    });

    try {
      await _videoService.toggleLike(video.id);
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _localLikeCounts[video.id] = (_localLikeCounts[video.id] ?? video.likeCount) + (currentlyLiked ? 1 : -1);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update like'.toLowerCase(),
              style: TextStyle(color: AppColors.background),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _likeInProgress.remove(video.id);
        });
      }
    }
  }

  Widget _buildVideoActions(Video video) {
    final isVideoOwner = _authService.currentUser?.uid == video.creatorId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Uploader profile
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: video.creatorId),
                ),
              );
            },
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(video.creatorId)
                  .snapshots(),
              builder: (context, snapshot) {
                String? photoUrl;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  photoUrl = userData['photoUrl'] as String?;
                }
                
                return CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accent,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null ? Text(
                    video.creatorUsername[0].toUpperCase(),
                    style: TextStyle(
                      color: AppColors.background,
                      fontWeight: FontWeight.bold,
                    ),
                  ) : null,
                );
              },
            ),
          ),
        ),

        // Like button with count
        StreamBuilder<bool>(
          stream: _videoService.hasLiked(video.id),
          builder: (context, snapshot) {
            final hasLiked = snapshot.data ?? false;
            final likeCount = _localLikeCounts[video.id] ?? video.likeCount;
            final isProcessing = _likeInProgress.contains(video.id);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: 40,
                child: Material(
                  color: AppColors.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: isProcessing ? null : () => _handleLike(video, hasLiked),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          isProcessing 
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: hasLiked ? AppColors.accent : AppColors.textPrimary,
                                ),
                              )
                            : Icon(
                                hasLiked ? Icons.favorite : Icons.favorite_border,
                                color: hasLiked ? AppColors.accent : AppColors.textPrimary,
                                size: 24,
                              ),
                          const SizedBox(height: 4),
                          Text(
                            '$likeCount'.toLowerCase(),
                            style: TextStyle(
                              color: hasLiked ? AppColors.accent : AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        
        // Comment button with count
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: 40,
            child: Material(
              color: AppColors.background.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _toggleComments,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        color: _showComments ? AppColors.accent : AppColors.textPrimary,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      StreamBuilder<DocumentSnapshot>(
                        stream: _videoService.firestore
                            .collection('videos')
                            .doc(video.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final commentCount = snapshot.hasData
                              ? (snapshot.data!.data() as Map<String, dynamic>)['commentCount'] ?? 0
                              : video.commentCount;
                          return Text(
                            '$commentCount'.toLowerCase(),
                            style: TextStyle(
                              color: _showComments ? AppColors.accent : AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Add to playlist button
        Container(
          margin: EdgeInsets.only(bottom: isVideoOwner ? 8 : 0),
          child: SizedBox(
            width: 40,
            child: Material(
              color: AppColors.background.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AddToPlaylistDialog(videoId: video.id),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Icon(
                    Icons.playlist_add,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Delete button (only for video owner)
        if (isVideoOwner)
          SizedBox(
            width: 40,
            child: Material(
              color: AppColors.background.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _deleteVideo(video),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SidebarLayout(
        showBackButton: widget.showBackSidebar && widget.videos != null,
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
                GestureDetector(
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity! < 0) {
                      // Swipe up - go to next video
                      if (_currentVideoIndex < videos.length) {
                        _pageController.animateToPage(
                          _currentVideoIndex + 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    } else if (details.primaryVelocity! > 0) {
                      // Swipe down - go to previous video
                      if (_currentVideoIndex > 0) {
                        _pageController.animateToPage(
                          _currentVideoIndex - 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    }
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: videos.length + 1,
                    onPageChanged: (index) {
                      setState(() {
                        _currentVideoIndex = index;
                        _showComments = false;
                        _showFullInfo = true;
                      });
                      Future.delayed(const Duration(seconds: 3), () {
                        if (mounted && _currentVideoIndex == index) {
                          setState(() => _showFullInfo = false);
                        }
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
                      return Stack(
                        children: [
                          // Video viewer
                          VideoViewer(
                            video: video,
                            autoPlay: index == _currentVideoIndex,
                            showControls: true,
                            isInFeed: true,
                          ),

                          // Video info and actions in a row
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Title card
                                Expanded(
                                  flex: 1,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _showFullInfo = !_showFullInfo);
                                    },
                                    child: AnimatedCrossFade(
                                      firstChild: Container(
                                        width: double.infinity,
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
                                              style: GoogleFonts.jetBrainsMono(
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
                                                return GestureDetector(
                                                  onTap: () {
                                                    HomeScreen.navigateToSearch(context, tag);
                                                  },
                                                  child: Container(
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
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      secondChild: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.background.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          video.title.toLowerCase(),
                                          style: GoogleFonts.jetBrainsMono(
                                            color: AppColors.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      crossFadeState: _showFullInfo ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                      duration: const Duration(milliseconds: 300),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16), // Space between title card and buttons
                                // Column of buttons
                                _buildVideoActions(video),
                              ],
                            ),
                          ),

                          // Comments overlay
                          if (_showComments)
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: MediaQuery.of(context).size.width * 0.6,
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
                                child: Column(
                                  children: [
                                    // Comments header
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                                .doc(video.id)
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              final commentCount = snapshot.hasData
                                                  ? (snapshot.data!.data() as Map<String, dynamic>)['commentCount'] ?? 0
                                                  : video.commentCount;
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
                                    // Comments list
                                    Expanded(
                                      child: CommentList(
                                        videoId: video.id,
                                        showInput: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
} 