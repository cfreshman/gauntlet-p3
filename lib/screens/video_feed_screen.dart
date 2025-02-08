import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
import '../services/minecraft_skin_service.dart';
import 'package:video_player/video_player.dart';
import '../providers/audio_state_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../services/url_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VideoFeedScreen extends StatefulWidget {
  final List<Video>? videos;  // Optional list of videos to show instead of feed
  final int initialIndex;     // Starting position in the video list
  final bool showBackSidebar; // Whether to show the back sidebar
  final VoidCallback? onBack; // Callback for back button

  const VideoFeedScreen({
    super.key,
    this.videos,
    this.initialIndex = 0,
    this.showBackSidebar = true,
    this.onBack,
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
  List<Video> _videos = [];
  bool _isLoadingMore = false;
  Set<String> _seenVideoIds = {};
  static const String _seenVideosKey = 'seen_videos';
  static const Duration _seenVideoExpiry = Duration(hours: 24);
  static const int _maxSeenVideos = 1000; // Prevent unlimited growth

  // Video controller management
  final Map<int, VideoPlayerController> _controllers = {};
  static const _preloadWindow = 2;  // Load 2 videos ahead
  int? _playingIndex;  // Track which video is currently playing

  @override
  void initState() {
    super.initState();
    
    // Set videos first if provided
    if (widget.videos != null) {
      _videos = widget.videos!;
    }
    
    // Initialize page controller after videos are set
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentVideoIndex = widget.initialIndex;
    _pageController.addListener(_handleScroll);
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showFullInfo = false);
      }
    });
    
    // Initialize controllers for initial window
    _initializeControllersAround(widget.initialIndex);

    // Only load videos from service if none were provided
    if (widget.videos == null) {
      _loadSeenVideos().then((_) {
        _loadVideos();
      });
    }
  }

  Future<void> _loadSeenVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenVideosJson = prefs.getString(_seenVideosKey);
      if (seenVideosJson != null) {
        final List<dynamic> seenVideosList = json.decode(seenVideosJson);
        final now = DateTime.now();
        
        // Filter out entries older than 24 hours and sort by timestamp
        final validEntries = seenVideosList.where((entry) {
          final timestamp = DateTime.parse(entry['timestamp']);
          return now.difference(timestamp) < _seenVideoExpiry;
        }).toList()
          ..sort((a, b) => DateTime.parse(b['timestamp']).compareTo(
              DateTime.parse(a['timestamp'])));

        // Keep only the most recent entries to prevent unlimited growth
        final recentEntries = validEntries.take(_maxSeenVideos)
            .map((entry) => entry['id'] as String).toSet();

        setState(() {
          _seenVideoIds = recentEntries;
        });

        // Save filtered list back to storage if we removed any entries
        if (recentEntries.length != seenVideosList.length) {
          await _saveSeenVideos();
        }
      }
    } catch (e) {
      print('Error loading seen videos: $e');
      // On error, clear the storage to prevent persistence of corrupt data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_seenVideosKey);
      } catch (e) {
        print('Error clearing seen videos: $e');
      }
    }
  }

  Future<void> _saveSeenVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      // Sort by timestamp and limit the number of entries
      final seenVideosList = _seenVideoIds.take(_maxSeenVideos).map((id) => {
        'id': id,
        'timestamp': now.toIso8601String(),
      }).toList();

      // Use transaction-like approach
      final success = await prefs.setString(_seenVideosKey, json.encode(seenVideosList));
      if (!success && kDebugMode) {
        print('Warning: Failed to save seen videos');
      }
    } catch (e) {
      print('Error saving seen videos: $e');
    }
  }

  Future<void> _markVideoAsSeen(String videoId) async {
    if (!_seenVideoIds.contains(videoId)) {
      setState(() {
        // Remove oldest if at limit
        if (_seenVideoIds.length >= _maxSeenVideos) {
          _seenVideoIds.remove(_seenVideoIds.first);
        }
        _seenVideoIds.add(videoId);
      });
      await _saveSeenVideos();
    }
  }

  Future<void> _loadVideos() async {
    // Don't load more videos if we have a fixed list
    if (widget.videos != null || _isLoadingMore) return;
    
    setState(() => _isLoadingMore = true);

    try {
      // Load recommended videos
      final newVideos = await _videoService.getRecommendedVideos(limit: 10);
      if (mounted) {
        setState(() {
          _videos = [..._videos, ...newVideos];
          _isLoadingMore = false;
        });
      }
      print('Total videos in feed: ${_videos.length}');
    } catch (e) {
      print('Error loading videos: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _handleScroll() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentVideoIndex) {
      setState(() => _currentVideoIndex = page);
      _initializeControllersAround(page);
    }
  }

  Future<void> _initializeControllersAround(int index) async {
    // Use _videos instead of fetching new ones
    if (_videos.isEmpty) return;
    
    // First pause any currently playing video
    if (_playingIndex != null) {
      final oldController = _controllers[_playingIndex];
      if (oldController != null) {
        await oldController.pause();
        await oldController.setVolume(0.0);
      }
      _playingIndex = null;
    }
    
    // Calculate window of videos to load
    final start = (index - 1).clamp(0, _videos.length);
    final end = (index + _preloadWindow).clamp(0, _videos.length);
    
    // Remove controllers outside window
    _controllers.removeWhere((i, controller) {
      if (i < start || i >= end) {
        controller.dispose();
        return true;
      }
      return false;
    });
    
    // Initialize new controllers within window
    for (var i = start; i < end; i++) {
      if (!_controllers.containsKey(i)) {
        final controller = VideoPlayerController.network(
          _videos[i].videoUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        
        try {
          await controller.initialize();
          await controller.setVolume(0.0);
          await controller.setLooping(true);
          _controllers[i] = controller;
        } catch (e) {
          print('Error initializing controller for video $i: $e');
          controller.dispose();
        }
      }
    }

    // Play the current video
    if (_controllers.containsKey(index)) {
      final controller = _controllers[index];
      if (controller != null) {
        final audioState = context.read<AudioStateProvider>();
        await controller.setVolume(audioState.isMuted ? 0.0 : 1.0);
        await controller.play();
        _playingIndex = index;
      }
    }
  }

  void _toggleComments() {
    // Check for authentication first
    if (_authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'please login to view comments'.toLowerCase(),
            style: TextStyle(color: AppColors.background),
          ),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _showComments = !_showComments;
    });
  }

  @override
  void dispose() {
    _playingIndex = null;
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _pageController.removeListener(_handleScroll);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final currentUser = _authService.auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please login to upload videos',
              style: TextStyle(color: AppColors.background),
            ),
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
              style: TextStyle(color: AppColors.textPrimary),
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
              style: TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleLike(Video video, bool currentlyLiked) async {
    // Check for authentication first
    if (_authService.currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'please login to like videos'.toLowerCase(),
              style: TextStyle(color: AppColors.background),
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

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
              style: TextStyle(color: AppColors.textPrimary),
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

  Widget _buildActionButton({
    required IconData icon,
    String? label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return SizedBox(
      width: 40,
      child: Material(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: color ?? AppColors.textPrimary,
                  size: 24,
                ),
                if (label != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    label.toLowerCase(),
                    style: TextStyle(
                      color: color ?? AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoActions(Video video) {
    final isVideoOwner = _authService.currentUser?.uid == video.creatorId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Uploader profile
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(video.creatorId)
              .snapshots(),
          builder: (context, snapshot) {
            String? minecraftUsername;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              minecraftUsername = data['minecraftUsername'] as String?;
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(userId: video.creatorId),
                    ),
                  ).then((_) {
                    if (mounted) {
                      _initializeControllersAround(_currentVideoIndex);
                    }
                  });
                  
                  if (_playingIndex != null) {
                    final controller = _controllers[_playingIndex];
                    if (controller != null) {
                      controller.pause();
                      controller.setVolume(0.0);
                    }
                  }
                },
                child: minecraftUsername != null && minecraftUsername.isNotEmpty
                    ? FutureBuilder<String>(
                        future: MinecraftSkinService().getFullBodyUrl(minecraftUsername),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return SizedBox(
                              height: 48,
                              child: Image.network(
                                snapshot.data!,
                                fit: BoxFit.contain,
                              ),
                            );
                          }
                          return Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.person, color: AppColors.accent),
                          );
                        },
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.person, color: AppColors.accent),
                      ),
              ),
            );
          }
        ),

        // Like button
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: StreamBuilder<bool>(
            stream: _videoService.hasLiked(video.id),
            builder: (context, snapshot) {
              final hasLiked = snapshot.data ?? false;
              return _buildActionButton(
                icon: hasLiked ? Icons.favorite : Icons.favorite_border,
                label: '${_localLikeCounts[video.id] ?? video.likeCount}',
                color: hasLiked ? AppColors.accent : null,
                onTap: () => _handleLike(video, hasLiked),
              );
            },
          ),
        ),

        // Comment button
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildActionButton(
            icon: Icons.comment,
            label: '${video.commentCount}',
            onTap: _toggleComments,
          ),
        ),

        // Add to playlist button
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildActionButton(
            icon: Icons.playlist_add,
            onTap: () {
              if (_authService.currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'please login to add to playlist'.toLowerCase(),
                      style: TextStyle(color: AppColors.background),
                    ),
                    backgroundColor: AppColors.accent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              showDialog(
                context: context,
                builder: (context) => AddToPlaylistDialog(videoId: video.id),
              );
            },
          ),
        ),

        // Options/Share button (no bottom padding on last item)
        _buildActionButton(
          icon: isVideoOwner ? Icons.more_vert : Icons.share,
          onTap: () {
            if (isVideoOwner) {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.background,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.share),
                      title: Text(
                        'share'.toLowerCase(),
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _shareVideo(video);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.delete_outline, color: AppColors.error),
                      title: Text(
                        'delete'.toLowerCase(),
                        style: TextStyle(color: AppColors.error),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppColors.background,
                            title: Text(
                              'delete video?'.toLowerCase(),
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                            content: Text(
                              'this action cannot be undone.'.toLowerCase(),
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  'cancel'.toLowerCase(),
                                  style: TextStyle(color: AppColors.textPrimary),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  'delete'.toLowerCase(),
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true) {
                          await _deleteVideo(video);
                        }
                      },
                    ),
                  ],
                ),
              );
            } else {
              _shareVideo(video);
            }
          },
        ),
      ],
    );
  }

  void _shareVideo(Video video) async {
    final origin = kIsWeb ? UrlService.instance.getCurrentOrigin() : null;
    final url = origin != null 
        ? '$origin/video/${video.id}'
        : _videoService.getShareableUrl(video.id);
        
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'link copied'.toLowerCase(),
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
              'failed to copy link'.toLowerCase(),
              style: TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.error,
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
        showBackButton: widget.showBackSidebar && widget.videos != null,
        onBack: widget.onBack,
        child: _videos.isEmpty && _isLoadingMore
            ? const Center(child: LoadingIndicator())
            : RawKeyboardListener(
                focusNode: FocusNode(),
                autofocus: true,
                onKey: (event) {
                  if (event is RawKeyDownEvent) {
                    if (event.logicalKey.keyLabel == 'Arrow Up' || 
                        event.logicalKey.keyLabel.toLowerCase() == 'w') {
                      if (_currentVideoIndex > 0) {
                        _pageController.animateToPage(
                          _currentVideoIndex - 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    } else if (event.logicalKey.keyLabel == 'Arrow Down' || 
                             event.logicalKey.keyLabel.toLowerCase() == 's') {
                      if (_currentVideoIndex < _videos.length) {
                        _pageController.animateToPage(
                          _currentVideoIndex + 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    }
                  }
                },
                child: GestureDetector(
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity! < 0) {
                      // Swipe up - go to next video
                      if (_currentVideoIndex < _videos.length) {
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
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: _videos.length + 1,
                    onPageChanged: (index) {
                      setState(() {
                        _currentVideoIndex = index;
                        _showComments = false;
                        _showFullInfo = true;
                      });
                      
                      // Mark current video as seen
                      if (index < _videos.length) {
                        _markVideoAsSeen(_videos[index].id);
                      }
                      
                      Future.delayed(const Duration(seconds: 3), () {
                        if (mounted && _currentVideoIndex == index) {
                          setState(() => _showFullInfo = false);
                        }
                      });
                      
                      // Load more videos when nearing the end
                      if (index >= _videos.length - 3) {
                        _loadVideos();
                      }
                    },
                    itemBuilder: (context, index) {
                      // Show end screen at the end
                      if (index == _videos.length) {
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
                                onPressed: () {
                                  _pageController.jumpToPage(0);
                                },
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

                      final video = _videos[index];
                      return Stack(
                        children: [
                          // Video viewer
                          VideoViewer(
                            video: video,
                            controller: _controllers[index] ?? VideoPlayerController.network(
                              video.videoUrl,
                              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
                            ),
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
              ),
      ),
    );
  }
} 