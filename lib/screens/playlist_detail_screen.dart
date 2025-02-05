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
        child: StreamBuilder<List<Playlist>>(
          stream: _playlistService.getUserPlaylists(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'error loading playlist'.toLowerCase(),
                  style: TextStyle(color: Colors.red),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: LoadingIndicator());
            }

            final playlist = snapshot.data!.firstWhere(
              (p) => p.id == widget.playlistId,
              orElse: () {
                // If playlist not found, go back
                Future.microtask(() => Navigator.pop(context));
                return Playlist(
                  id: '',
                  name: '',
                  userId: '',
                  videoIds: [],
                  updatedAt: DateTime.now(),
                  createdAt: DateTime.now(),
                  firstVideoThumbnail: null,
                );
              },
            );

            if (playlist.id.isEmpty) {
              return const SizedBox.shrink();
            }

            return Row(
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
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                autofocus: true,
                                style: TextStyle(color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'playlist name'.toLowerCase(),
                                  hintStyle: TextStyle(color: AppColors.textSecondary),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.check, color: AppColors.accent),
                              onPressed: () => _updatePlaylistName(playlist.id, _nameController.text),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: AppColors.textSecondary),
                              onPressed: () => setState(() => _isEditing = false),
                            ),
                          ],
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
                      OutlinedButton.icon(
                        onPressed: () => _deletePlaylist(playlist.id),
                        icon: Icon(Icons.delete_outline, color: Colors.red),
                        label: Text(
                          'delete playlist'.toLowerCase(),
                          style: const TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right side - Video list
                Expanded(
                  child: FutureBuilder<List<Video>>(
                    future: _playlistService.getPlaylistVideos(playlist.id),
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
                        padding: const EdgeInsets.all(16),
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
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('playlist updated'.toLowerCase()),
                                backgroundColor: AppColors.accent,
                              ));
                            }
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
                              ),
                            ),
                          );
                        },
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