import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/video.dart';
import '../services/playlist_service.dart';
import '../theme/colors.dart';
import '../widgets/video_preview.dart';
import '../widgets/sidebar_layout.dart';
import '../widgets/loading_indicator.dart';
import '../extensions/string_extensions.dart';
import 'video_feed_screen.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final _playlistService = PlaylistService();
  final _nameController = TextEditingController();
  bool _isEditing = false;
  final _auth = AuthService();
  final _firestore = FirebaseFirestore.instance;
  List<String> _currentVideoOrder = [];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get isCurrentUserPlaylist => 
      _auth.currentUser?.uid == _playlistService.getPlaylistById(widget.playlistId).first;

  Future<void> _updatePlaylistName(String playlistId, String newName) async {
    if (newName.trim().isEmpty) return;

    try {
      await _playlistService.updatePlaylistName(playlistId, newName.trim());
      setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('failed to update playlist name: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _deletePlaylist(String playlistId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'delete playlist'.toLowerCase(),
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'are you sure you want to delete this playlist?'.toLowerCase(),
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'cancel'.toLowerCase(),
              style: TextStyle(color: AppColors.accent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'delete'.toLowerCase(),
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _playlistService.deletePlaylist(playlistId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('failed to delete playlist'.toLowerCase()),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _removeVideo(String playlistId, String videoId) async {
    try {
      await _playlistService.removeVideoFromPlaylist(playlistId, videoId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('video removed'.toLowerCase()),
          backgroundColor: AppColors.accent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('failed to remove video'.toLowerCase()),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _handleReorder(int oldIndex, int newIndex, List<Video> videos, Playlist playlist, bool isOwner) {
    if (!isOwner) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final newOrder = List<String>.from(_currentVideoOrder.isEmpty ? playlist.videoIds : _currentVideoOrder);
      final item = newOrder.removeAt(oldIndex);
      newOrder.insert(newIndex, item);
      _currentVideoOrder = newOrder;
    });

    _playlistService.reorderVideos(playlist.id, _currentVideoOrder).catchError((e) {
      setState(() {
        _currentVideoOrder = List<String>.from(playlist.videoIds);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('failed to update playlist'.toLowerCase()),
          backgroundColor: Colors.red,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Playlist?>(
      stream: _playlistService.getPlaylistById(widget.playlistId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return const Center(child: LoadingIndicator());
        }

        final playlist = snapshot.data!;
        final isCurrentUserPlaylist = _auth.currentUser?.uid == playlist.userId;

        if (_currentVideoOrder.isEmpty) {
          _currentVideoOrder = List<String>.from(playlist.videoIds);
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SidebarLayout(
            showBackButton: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Playlist info
                Container(
                  width: 300,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: AppColors.accent.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Playlist thumbnail
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.background.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
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
                                  size: 48,
                                  color: AppColors.accent,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Playlist name and edit controls
                      if (_isEditing && isCurrentUserPlaylist) ...[
                        TextField(
                          controller: _nameController,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.accent),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.accent, width: 2),
                            ),
                          ),
                          onSubmitted: (value) => _updatePlaylistName(playlist.id, value),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    playlist.name.toLowerCase(),
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  FutureBuilder<DocumentSnapshot>(
                                    future: _firestore.collection('users').doc(playlist.userId).get(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) return const SizedBox();
                                      final username = snapshot.data?.get('username') as String? ?? '';
                                      return Text(
                                        '@$username'.toLowerCase(),
                                        style: TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 14,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrentUserPlaylist)
                              IconButton(
                                icon: Icon(Icons.edit, color: AppColors.accent),
                                onPressed: () {
                                  _nameController.text = playlist.name;
                                  setState(() => _isEditing = true);
                                },
                              ),
                          ],
                        ),
                      ],

                      // Video count
                      Text(
                        '${playlist.videoIds.length} videos'.toLowerCase(),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),

                      if (isCurrentUserPlaylist) ...[
                        const SizedBox(height: 24),
                        // Delete button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                            onPressed: () => _deletePlaylist(playlist.id),
                            child: Text('delete playlist'.toLowerCase()),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Right side - Video list
                Expanded(
                  child: StreamBuilder<List<Video>>(
                    stream: _playlistService.getPlaylistVideosStream(playlist.id),
                    builder: (context, videoSnapshot) {
                      if (!videoSnapshot.hasData) {
                        return const Center(child: LoadingIndicator());
                      }

                      final videos = videoSnapshot.data!;
                      final sortedVideos = List<Video>.from(videos)
                        ..sort((a, b) => _currentVideoOrder.indexOf(a.id)
                            .compareTo(_currentVideoOrder.indexOf(b.id)));

                      if (sortedVideos.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.playlist_play,
                                size: 64,
                                color: AppColors.accent.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'no videos in playlist'.toLowerCase(),
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      }

                      return ReorderableListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sortedVideos.length,
                        buildDefaultDragHandles: false,
                        proxyDecorator: (child, index, animation) => child,
                        onReorderStart: (_) {
                          if (!isCurrentUserPlaylist) return;
                        },
                        onReorder: (oldIndex, newIndex) => 
                            _handleReorder(oldIndex, newIndex, sortedVideos, playlist, isCurrentUserPlaylist),
                        itemBuilder: (context, index) {
                          final video = sortedVideos[index];
                          return Container(
                            key: ValueKey('dismissible-${video.id}'),
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Dismissible(
                              key: ValueKey('dismissible-${video.id}'),
                              direction: isCurrentUserPlaylist 
                                  ? DismissDirection.endToStart 
                                  : DismissDirection.none,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) => _removeVideo(playlist.id, video.id),
                              child: Material(
                                color: Colors.transparent,
                                child: Stack(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      height: 180,
                                      child: VideoPreview(
                                        video: video,
                                        showTitle: true,
                                        showCreator: true,
                                        videos: sortedVideos,
                                        currentIndex: index,
                                        showTimeAgo: true,
                                        showDuration: true,
                                      ),
                                    ),
                                    if (isCurrentUserPlaylist)
                                      Positioned(
                                        right: 8,
                                        top: 0,
                                        bottom: 0,
                                        child: Center(
                                          child: ReorderableDragStartListener(
                                            index: index,
                                            child: Icon(
                                              Icons.drag_handle,
                                              color: AppColors.textPrimary,
                                            ),
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 