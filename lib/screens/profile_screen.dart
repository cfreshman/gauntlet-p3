import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/colors.dart';
import '../services/video_service.dart';
import '../models/video.dart';
import '../models/playlist.dart';
import '../extensions/string_extensions.dart';
import '../widgets/video_preview.dart';
import '../services/playlist_service.dart';
import '../screens/playlist_detail_screen.dart';
import '../widgets/sidebar_layout.dart';
import 'edit_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;  // If null, show current user's profile

  const ProfileScreen({
    super.key,
    this.userId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _videoService = VideoService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _playlistService = PlaylistService();
  bool _showVideos = false;
  bool _isLoading = true;
  List<Video> _userVideos = [];
  String _bio = 'new user';
  String _username = 'Anonymous';
  String? _photoUrl;
  bool _isCurrentUser = false;
  
  @override
  void initState() {
    super.initState();
    _isCurrentUser = widget.userId == null || widget.userId == _auth.currentUser?.uid;
    _loadUserData();
    _loadUserVideos();
  }

  Future<void> _loadUserData() async {
    final userId = widget.userId ?? _auth.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;
        setState(() {
          _username = data['displayName'] ?? 'Anonymous';
          _bio = data['bio'] ?? 'new user';
          _photoUrl = data['photoUrl'];
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }
  
  Future<void> _loadUserVideos() async {
    final userId = widget.userId ?? _auth.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final videos = await _videoService.getUserVideos(userId: userId);
      setState(() {
        _userVideos = videos;
        _showVideos = videos.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading videos: $e');
      setState(() => _isLoading = false);
    }
  }

  void _refreshProfile() {
    _loadUserData();
    _loadUserVideos();
  }

  @override
  Widget build(BuildContext context) {
    // Check if we're navigating from another screen (not main nav)
    final bool showBackButton = !_isCurrentUser || Navigator.of(context).canPop();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
      ),
      child: SidebarLayout(
        showBackButton: showBackButton,
        child: Scaffold(
          body: Row(
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
                      '@$_username'.lowercase,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Follow button - only show for other users
                    if (!_isCurrentUser)
                      StreamBuilder<DocumentSnapshot>(
                        stream: _firestore
                            .collection('users')
                            .doc(_auth.currentUser?.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          
                          final currentUserDoc = snapshot.data!;
                          final data = currentUserDoc.data() as Map<String, dynamic>;
                          final following = List<String>.from(data['following'] ?? []);
                          final isFollowing = following.contains(widget.userId);

                          return FilledButton.tonal(
                            onPressed: () async {
                              try {
                                if (isFollowing) {
                                  // Unfollow
                                  await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
                                    'following': FieldValue.arrayRemove([widget.userId]),
                                    'followingCount': FieldValue.increment(-1),
                                  });
                                  await _firestore.collection('users').doc(widget.userId).update({
                                    'followers': FieldValue.arrayRemove([_auth.currentUser!.uid]),
                                    'followerCount': FieldValue.increment(-1),
                                  });
                                } else {
                                  // Follow
                                  await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
                                    'following': FieldValue.arrayUnion([widget.userId]),
                                    'followingCount': FieldValue.increment(1),
                                  });
                                  await _firestore.collection('users').doc(widget.userId).update({
                                    'followers': FieldValue.arrayUnion([_auth.currentUser!.uid]),
                                    'followerCount': FieldValue.increment(1),
                                  });
                                }
                              } catch (e) {
                                print('Error toggling follow: $e');
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: isFollowing ? AppColors.background : AppColors.accent,
                              foregroundColor: isFollowing ? AppColors.accent : AppColors.background,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: AppColors.accent,
                                  width: isFollowing ? 1 : 0,
                                ),
                              ),
                            ),
                            child: Text(
                              (isFollowing ? 'following' : 'follow').lowercase,
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    // Bio
                    Text(
                      _bio.lowercase,
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
                    // Edit Profile Button - only show for current user
                    if (_isCurrentUser)
                      FilledButton.tonal(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
                          _refreshProfile();
                        },
                        child: Text('edit profile'.lowercase),
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
                              title: 'Videos'.lowercase,
                              isSelected: _showVideos,
                              onPressed: () => setState(() => _showVideos = true),
                            ),
                            const SizedBox(width: 16),
                          ],
                          _buildToggleButton(
                            title: 'Playlists'.lowercase,
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
          ),
        ),
      ),
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
          'No videos uploaded yet'.lowercase,
          style: TextStyle(color: AppColors.textPrimary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userVideos.length,
      itemBuilder: (context, index) {
        final video = _userVideos[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SizedBox(
            height: 180,
            child: VideoPreview(
              video: video,
              showTitle: true,
              showCreator: false,
              videos: _userVideos,
              currentIndex: index,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistsList() {
    final userId = widget.userId ?? _auth.currentUser?.uid;
    if (userId == null) return const SizedBox();
    
    return StreamBuilder<List<Playlist>>(
      stream: _playlistService.getUserPlaylists(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final playlists = snapshot.data!;
        if (playlists.isEmpty) {
          return Center(
            child: Text(
              'No playlists yet',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return Container(
              height: 100,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlaylistDetailScreen(
                          playlistId: playlist.id,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
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
                            image: playlist.firstVideoThumbnail != null
                                ? DecorationImage(
                                    image: NetworkImage(playlist.firstVideoThumbnail!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: playlist.firstVideoThumbnail == null
                              ? Icon(
                                  Icons.playlist_play,
                                  size: 32,
                                  color: AppColors.accent,
                                )
                              : null,
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
                                playlist.name.lowercase,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${playlist.videoIds.length} videos'.lowercase,
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
                ),
              ),
            );
          },
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