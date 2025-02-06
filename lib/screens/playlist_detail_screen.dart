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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SidebarLayout(
        showBackButton: true,
        child: StreamBuilder<Playlist?>(
          stream: _playlistService.getPlaylistById(widget.playlistId),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.hasError) {
              return const Center(child: LoadingIndicator());
            }

            final playlist = snapshot.data;
            if (playlist == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.playlist_remove,
                      size: 64,
                      color: AppColors.accent.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'playlist not found'.toLowerCase(),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }

            return Row(
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
                      
                      // Playlist name
                      if (_isEditing) ...[
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (value) => _updatePlaylistName(playlist.id, value),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                playlist.name.toLowerCase(),
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
                      const SizedBox(height: 8),
                      
                      // Video count
                      Text(
                        '${playlist.videoIds.length} videos'.toLowerCase(),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
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
                  ),
                ),

                // Right side - Video list
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: StreamBuilder<List<Video>>(
                      stream: _playlistService.getPlaylistVideosStream(playlist.id),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'error loading videos'.toLowerCase(),
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(child: LoadingIndicator());
                        }

                        final videos = snapshot.data!;
                        if (videos.isEmpty) {
                          return Center(
                            child: Text(
                              'no videos in playlist'.toLowerCase(),
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          );
                        }

                        return ReorderableListView.builder(
                          itemCount: videos.length,
                          onReorder: (oldIndex, newIndex) async {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            try {
                              final newOrder = List<String>.from(playlist.videoIds);
                              final item = newOrder.removeAt(oldIndex);
                              newOrder.insert(newIndex, item);
                              await _playlistService.reorderVideos(playlist.id, newOrder);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('failed to update playlist'.toLowerCase()),
                                  backgroundColor: Colors.red,
                                ));
                              }
                            }
                          },
                          itemBuilder: (context, index) {
                            final video = videos[index];
                            return Dismissible(
                              key: ValueKey(video.id),
                              direction: DismissDirection.endToStart,
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
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: VideoPreview(
                                  video: video,
                                  showTitle: true,
                                  showCreator: true,
                                  videos: videos,
                                  currentIndex: index,
                                  showTimeAgo: true,
                                  showDuration: true,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
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