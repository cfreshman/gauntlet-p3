import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/video.dart';
import '../services/playlist_service.dart';
import '../theme/colors.dart';
import '../widgets/video_preview.dart';
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

  Future<void> _updatePlaylistName() async {
    if (_nameController.text.trim().isEmpty) return;

    try {
      await _playlistService.updatePlaylistName(
        widget.playlistId,
        _nameController.text.trim(),
      );
      setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update playlist name: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeVideo(String videoId) async {
    try {
      await _playlistService.removeVideoFromPlaylist(widget.playlistId, videoId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Video removed from playlist'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePlaylist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Delete Playlist',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this playlist?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _playlistService.deletePlaylist(widget.playlistId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete playlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Playlist>>(
      stream: _playlistService.getUserPlaylists(),
      builder: (context, playlistSnapshot) {
        if (playlistSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Text(
                'Error: ${playlistSnapshot.error}',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!playlistSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final playlist = playlistSnapshot.data!
            .firstWhere((p) => p.id == widget.playlistId);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            title: _isEditing
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          autofocus: true,
                          style: TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Playlist name',
                            hintStyle: TextStyle(color: AppColors.textSecondary),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.check,
                          color: AppColors.accent,
                        ),
                        onPressed: _updatePlaylistName,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _isEditing = false),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          playlist.name,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          color: AppColors.accent,
                        ),
                        onPressed: () {
                          _nameController.text = playlist.name;
                          setState(() => _isEditing = true);
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: _deletePlaylist,
                      ),
                    ],
                  ),
          ),
          body: FutureBuilder<List<Video>>(
            future: _playlistService.getPlaylistVideos(widget.playlistId),
            builder: (context, videoSnapshot) {
              if (videoSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${videoSnapshot.error}',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }

              if (!videoSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final videos = videoSnapshot.data!;
              if (videos.isEmpty) {
                return Center(
                  child: Text(
                    'No videos in this playlist',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: videos.length,
                onReorder: (oldIndex, newIndex) async {
                  // Adjust the index if moving down
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }

                  try {
                    // Create new video order
                    final List<String> newOrder = List.from(playlist.videoIds);
                    final String movedId = newOrder.removeAt(oldIndex);
                    newOrder.insert(newIndex, movedId);

                    // Update the playlist
                    await _playlistService.reorderVideos(widget.playlistId, newOrder);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Playlist order updated'),
                          backgroundColor: AppColors.accent,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to reorder videos: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                itemBuilder: (context, index) {
                  final video = videos[index];
                  return Dismissible(
                    key: Key(video.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: Colors.red,
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (_) => _removeVideo(video.id),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: VideoPreview(
                        key: ValueKey(video.id),
                        video: video,
                        showCreator: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoFeedScreen(
                                videos: videos,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
} 