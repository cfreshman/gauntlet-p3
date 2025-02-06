import 'package:flutter/material.dart';
import '../models/video.dart';
import '../services/playlist_service.dart';
import '../theme/colors.dart';
import 'video_preview.dart';

class PlaylistVideoList extends StatefulWidget {
  final List<Video> videos;
  final List<String> initialOrder;
  final String playlistId;
  final bool isOwner;

  const PlaylistVideoList({
    super.key,
    required this.videos,
    required this.initialOrder,
    required this.playlistId,
    required this.isOwner,
  });

  @override
  State<PlaylistVideoList> createState() => _PlaylistVideoListState();
}

class _PlaylistVideoListState extends State<PlaylistVideoList> {
  late List<String> _currentOrder;
  final _playlistService = PlaylistService();

  @override
  void initState() {
    super.initState();
    _currentOrder = List<String>.from(widget.initialOrder);
  }

  void _handleReorder(int oldIndex, int newIndex) {
    if (!widget.isOwner) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _currentOrder.removeAt(oldIndex);
      _currentOrder.insert(newIndex, item);
    });

    _playlistService.reorderVideos(widget.playlistId, _currentOrder).catchError((e) {
      setState(() {
        _currentOrder = List<String>.from(widget.initialOrder);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('failed to update playlist'.toLowerCase()),
        backgroundColor: Colors.red,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedVideos = List<Video>.from(widget.videos)
      ..sort((a, b) => _currentOrder.indexOf(a.id)
          .compareTo(_currentOrder.indexOf(b.id)));

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedVideos.length,
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => child,
      onReorderStart: (_) {
        if (!widget.isOwner) return;
      },
      onReorder: _handleReorder,
      itemBuilder: (context, index) {
        final video = sortedVideos[index];
        return Container(
          key: ValueKey('dismissible-${video.id}'),
          margin: const EdgeInsets.only(bottom: 16),
          child: Dismissible(
            key: ValueKey('dismissible-${video.id}'),
            direction: widget.isOwner 
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
            onDismissed: (_) => _playlistService.removeVideoFromPlaylist(widget.playlistId, video.id),
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
                  if (widget.isOwner)
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
  }
} 