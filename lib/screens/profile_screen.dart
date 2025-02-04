import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/colors.dart';
import '../services/video_service.dart';
import '../models/video.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _videoService = VideoService();
  final _auth = FirebaseAuth.instance;
  bool _showVideos = false;
  bool _isLoading = true;
  List<Video> _userVideos = [];
  
  String get _username => _auth.currentUser?.displayName ?? 'Anonymous';
  String? get _photoUrl => _auth.currentUser?.photoURL;
  
  @override
  void initState() {
    super.initState();
    _loadUserVideos();
  }
  
  Future<void> _loadUserVideos() async {
    if (_auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final videos = await _videoService.getUserVideos();
      setState(() {
        _userVideos = videos;
        _showVideos = videos.isNotEmpty; // Default to videos if user has any
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading videos: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Center(
        child: Text('Please log in to view your profile'),
      );
    }

    return Row(
      children: [
        // Left side - User info
        Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: AppColors.background.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.accent,
                backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                child: _photoUrl == null ? Icon(
                  Icons.person,
                  size: 50,
                  color: AppColors.textPrimary,
                ) : null,
              ),
              const SizedBox(height: 16),
              // Username
              Text(
                '@$_username',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // Bio
              Text(
                'Video creator',
                style: TextStyle(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('Videos', _userVideos.length.toString()),
                  _buildStatColumn('Views', _userVideos.fold<int>(0, (sum, video) => sum + video.viewCount).toString()),
                  _buildStatColumn('Likes', _userVideos.fold<int>(0, (sum, video) => sum + video.likeCount).toString()),
                ],
              ),
              const SizedBox(height: 16),
              // Edit Profile Button
              FilledButton.tonal(
                onPressed: () {
                  // TODO: Implement edit profile
                },
                child: const Text('Edit Profile'),
              ),
            ],
          ),
        ),

        // Right side - Content
        Expanded(
          child: Column(
            children: [
              // Toggle bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.background.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (_userVideos.isNotEmpty) ...[
                      _buildToggleButton(
                        title: 'Videos',
                        isSelected: _showVideos,
                        onPressed: () => setState(() => _showVideos = true),
                      ),
                      const SizedBox(width: 16),
                    ],
                    _buildToggleButton(
                      title: 'Playlists',
                      isSelected: !_showVideos,
                      onPressed: () => setState(() => _showVideos = false),
                    ),
                  ],
                ),
              ),
              // Content list
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      )
                    : _showVideos
                        ? _buildVideosList()
                        : _buildPlaylistsList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String title,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: isSelected
            ? AppColors.accent.withOpacity(0.1)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.accent : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildVideosList() {
    if (_userVideos.isEmpty) {
      return Center(
        child: Text(
          'No videos uploaded yet',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userVideos.length,
      itemBuilder: (context, index) {
        final video = _userVideos[index];
        return Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Video thumbnail
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.2),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8),
                    ),
                    image: video.thumbnailUrl != null
                        ? DecorationImage(
                            image: NetworkImage(video.thumbnailUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: video.thumbnailUrl == null
                      ? Icon(
                          Icons.play_circle_outline,
                          size: 32,
                          color: AppColors.accent,
                        )
                      : null,
                ),
              ),
              // Video info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${video.viewCount} views',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
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
  }

  Widget _buildPlaylistsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Playlist thumbnail
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.2),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8),
                    ),
                  ),
                  child: Icon(
                    Icons.playlist_play,
                    size: 32,
                    color: AppColors.accent,
                  ),
                ),
              ),
              // Playlist info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Playlist ${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(index + 1) * 5} videos',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
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
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
} 