import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../services/playlist_service.dart';
import '../theme/colors.dart';

class AddToPlaylistDialog extends StatefulWidget {
  final String videoId;

  const AddToPlaylistDialog({
    super.key,
    required this.videoId,
  });

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  final _playlistService = PlaylistService();
  final _nameController = TextEditingController();
  bool _isCreatingPlaylist = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createPlaylist() async {
    if (_isLoading) return;

    // Unfocus keyboard
    FocusScope.of(context).unfocus();

    if (_nameController.text.trim().isEmpty) return;

    try {
      final playlist = await _playlistService.createPlaylist(_nameController.text.trim());
      await _playlistService.addVideoToPlaylist(playlist.id, widget.videoId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('added to ${playlist.name}'.toLowerCase()),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed to create playlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleInPlaylist(Playlist playlist) async {
    final isInPlaylist = playlist.videoIds.contains(widget.videoId);
    
    setState(() {
      _isLoading = true;
    });

    try {
      if (isInPlaylist) {
        await _playlistService.removeVideoFromPlaylist(playlist.id, widget.videoId);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('removed from ${playlist.name}'),
              backgroundColor: AppColors.accent,
            ),
          );
        }
      } else {
        await _playlistService.addVideoToPlaylist(playlist.id, widget.videoId);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('added to ${playlist.name}'),
              backgroundColor: AppColors.accent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed to update playlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'add to playlist'.toLowerCase(),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_isCreatingPlaylist) ...[
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'playlist name'.toLowerCase(),
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _createPlaylist,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('create playlist'.toLowerCase()),
                ),
                TextButton(
                  onPressed: () => setState(() => _isCreatingPlaylist = false),
                  child: Text(
                    'cancel'.toLowerCase(),
                    style: TextStyle(color: AppColors.accent),
                  ),
                ),
              ] else ...[
                StreamBuilder<List<Playlist>>(
                  stream: _playlistService.getUserPlaylists(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        'error: ${snapshot.error}'.toLowerCase(),
                        style: TextStyle(color: Colors.red),
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

                    return SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = playlists[index];
                          final isInPlaylist = playlist.videoIds.contains(widget.videoId);
                          return ListTile(
                            title: Text(
                              playlist.name.toLowerCase(),
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                            subtitle: Text(
                              '${playlist.videoIds.length} videos'.toLowerCase(),
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            trailing: Text(
                              (isInPlaylist ? 'remove' : 'add').toLowerCase(),
                              style: TextStyle(
                                color: isInPlaylist ? Colors.red : AppColors.accent,
                              ),
                            ),
                            onTap: () => _toggleInPlaylist(playlist),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => setState(() => _isCreatingPlaylist = true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('create new playlist'.toLowerCase()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 