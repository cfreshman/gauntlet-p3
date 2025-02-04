import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video.dart';
import '../theme/colors.dart';
import '../extensions/string_extensions.dart';
import '../services/video_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Video video;
  final int initialIndex;
  final List<Video>? playlist;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    this.initialIndex = 0,
    this.playlist,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  final _videoService = VideoService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(widget.video.videoUrl);
    
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.play();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
      // Increment view count when video starts playing
      await _videoService.incrementViewCount(widget.video.id);
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            // Left side navigation rail
            NavigationRail(
              backgroundColor: AppColors.background,
              selectedIndex: 1, // Video index
              onDestinationSelected: (index) {
                if (index != 1) {
                  Navigator.pop(context);
                }
              },
              labelType: NavigationRailLabelType.all,
              useIndicator: true,
              indicatorColor: AppColors.accent,
              selectedIconTheme: IconThemeData(
                color: AppColors.background,
              ),
              unselectedIconTheme: IconThemeData(
                color: AppColors.accent.withOpacity(0.7),
              ),
              selectedLabelTextStyle: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: AppColors.textPrimary.withOpacity(0.7),
              ),
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.upload_outlined),
                  selectedIcon: Icon(Icons.upload),
                  label: Text('upload'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.play_circle_outline),
                  selectedIcon: Icon(Icons.play_circle_fill),
                  label: Text('watch'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search),
                  label: Text('search'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('profile'),
                ),
              ],
            ),

            // Vertical divider
            VerticalDivider(
              thickness: 1,
              width: 1,
              color: AppColors.accent.withOpacity(0.2),
            ),

            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video player
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isInitialized)
                          VideoPlayer(_controller)
                        else
                          Container(
                            color: AppColors.background,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        if (_isInitialized)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_controller.value.isPlaying) {
                                  _controller.pause();
                                } else {
                                  _controller.play();
                                }
                              });
                            },
                            child: Container(
                              color: Colors.transparent,
                              child: Center(
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
                                      _controller.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      size: 50,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_isInitialized)
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
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Video info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.video.title.lowercase,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              widget.video.creatorUsername.lowercase,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.video.viewCount} views'.lowercase,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        if (widget.video.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            widget.video.description.lowercase,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.video.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '#$tag'.lowercase,
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Up next
                  if (widget.playlist != null) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Up Next'.lowercase,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: widget.playlist!.length,
                        itemBuilder: (context, index) {
                          final video = widget.playlist![index];
                          if (index == widget.initialIndex) return const SizedBox.shrink();
                          
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                image: DecorationImage(
                                  image: NetworkImage(video.thumbnailUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            title: Text(
                              video.title.lowercase,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${video.viewCount} views'.lowercase,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VideoPlayerScreen(
                                    video: video,
                                    initialIndex: index,
                                    playlist: widget.playlist,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 