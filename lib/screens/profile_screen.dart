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
import '../services/minecraft_skin_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  final _minecraftService = MinecraftSkinService();
  bool _showVideos = false;  // Changed to false by default
  bool _showPlaylists = true;  // Changed to true by default
  bool _showLikes = false;
  bool _isLoading = true;
  List<Video> _userVideos = [];
  String _bio = 'new user';
  String _username = 'Anonymous';
  String? _photoUrl;
  String? _minecraftUsername;
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
          _minecraftUsername = data['minecraftUsername'];
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
        // Only show videos tab if there are videos
        _showVideos = videos.isNotEmpty;
        // Show playlists by default if no videos
        _showPlaylists = !_showVideos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading videos: $e');
      setState(() {
        _isLoading = false;
        // Show playlists on error
        _showVideos = false;
        _showPlaylists = true;
      });
    }
  }

  void _refreshProfile() {
    _loadUserData();
    _loadUserVideos();
  }

  Widget _buildToggleButton({
    required String title,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: isSelected ? AppColors.accent : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.background : AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVideosList() {
    if (_userVideos.isEmpty) {
      return Center(
        child: Text(
          'no videos uploaded yet'.toLowerCase(),
          style: TextStyle(color: AppColors.textPrimary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _userVideos.length,
      itemBuilder: (context, index) {
        final video = _userVideos[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            height: 160,
            child: VideoPreview(
              video: video,
              showTitle: true,
              showCreator: false,
              videos: _userVideos,
              currentIndex: index,
              showTimeAgo: true,
              showDuration: true,
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
              'no playlists yet'.toLowerCase(),
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 8),
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

  Widget _buildLikedVideosList() {
    return StreamBuilder<List<Video>>(
      stream: _videoService.getLikedVideos(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}'.toLowerCase(),
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.accent,
            ),
          );
        }

        final likedVideos = snapshot.data!;
        if (likedVideos.isEmpty) {
          return Center(
            child: Text(
              'no liked videos yet'.toLowerCase(),
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: likedVideos.length,
          itemBuilder: (context, index) {
            final video = likedVideos[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 160,
                child: VideoPreview(
                  video: video,
                  showTitle: true,
                  showCreator: true,
                  videos: likedVideos,
                  currentIndex: index,
                  showTimeAgo: true,
                  showDuration: true,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar() {
    if (_minecraftUsername != null) {
      return FutureBuilder<String>(
        future: _minecraftService.getFullBodyUrl(_minecraftUsername!),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: AppColors.background,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 200,
                              child: Image.network(
                                snapshot.data!,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'close'.toLowerCase(),
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                                if (_isCurrentUser)
                                  TextButton(
                                    onPressed: () async {
                                      // Show loading dialog first
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => Dialog(
                                          backgroundColor: AppColors.background,
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const CircularProgressIndicator(),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'villager is thinking...'.toLowerCase(),
                                                  style: TextStyle(
                                                    color: AppColors.textPrimary,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );

                                      try {
                                        final functions = FirebaseFunctions.instance;
                                        final skinUrl = await _minecraftService.getFullBodyUrl(_minecraftUsername!);
                                        
                                        final result = await functions
                                          .httpsCallable('rateSkin')
                                          .call({ 'skinUrl': skinUrl });
                                        
                                        if (mounted) {
                                          // Close loading dialog
                                          Navigator.pop(context);
                                          // Show rating dialog
                                          showDialog(
                                            context: context,
                                            builder: (context) => Dialog(
                                              backgroundColor: AppColors.background,
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    ConstrainedBox(
                                                      constraints: BoxConstraints(
                                                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                                                      ),
                                                      child: SingleChildScrollView(
                                                        child: Text(
                                                          result.data['rating'],
                                                          style: TextStyle(
                                                            color: AppColors.textPrimary,
                                                            fontSize: 16,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: Text(
                                                        'close'.toLowerCase(),
                                                        style: TextStyle(color: AppColors.accent),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'failed to get rating'.toLowerCase(),
                                                style: TextStyle(color: AppColors.background),
                                              ),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Text(
                                      'get rating'.toLowerCase(),
                                      style: TextStyle(color: AppColors.accent),
                                    ),
                                  )
                                else
                                  TextButton(
                                    onPressed: () async {
                                      try {
                                        await _minecraftService.downloadSkin(_minecraftUsername!);
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'downloading skin...'.toLowerCase(),
                                                style: TextStyle(color: AppColors.background),
                                              ),
                                              backgroundColor: AppColors.accent,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'failed to download skin'.toLowerCase(),
                                                style: TextStyle(color: AppColors.background),
                                              ),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Text(
                                      'download'.toLowerCase(),
                                      style: TextStyle(color: AppColors.accent),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: SizedBox(
                height: 100,
                child: Image.network(
                  snapshot.data!,
                  fit: BoxFit.contain,
                ),
              ),
            );
          }
          return _buildProfilePicture();
        },
      );
    }
    
    return _buildProfilePicture();
  }

  Widget _buildProfilePicture() {
    return CircleAvatar(
      radius: 50,
      backgroundColor: AppColors.accent,
      backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
      child: _photoUrl == null ? Icon(
        Icons.person,
        size: 50,
        color: AppColors.textPrimary,
      ) : null,
    );
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
                    _buildAvatar(),
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
                    if (_userVideos.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn('videos', _userVideos.length.toString()),
                          _buildStatColumn('views', _userVideos.fold<int>(0, (sum, video) => sum + video.viewCount).toString()),
                          _buildStatColumn('likes', _userVideos.fold<int>(0, (sum, video) => sum + video.likeCount).toString()),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              onPressed: () => setState(() {
                                _showVideos = true;
                                _showPlaylists = false;
                                _showLikes = false;
                              }),
                            ),
                            const SizedBox(width: 8),
                          ],
                          _buildToggleButton(
                            title: 'Playlists'.lowercase,
                            isSelected: _showPlaylists,
                            onPressed: () => setState(() {
                              _showVideos = false;
                              _showPlaylists = true;
                              _showLikes = false;
                            }),
                          ),
                          if (_isCurrentUser) ...[
                            const SizedBox(width: 8),
                            _buildToggleButton(
                              title: 'Likes'.lowercase,
                              isSelected: _showLikes,
                              onPressed: () => setState(() {
                                _showVideos = false;
                                _showPlaylists = false;
                                _showLikes = true;
                              }),
                            ),
                          ],
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
                              : _showPlaylists
                                  ? _buildPlaylistsList()
                                  : _showLikes
                                      ? _buildLikedVideosList()
                                      : const SizedBox(),
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