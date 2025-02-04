import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/video_service.dart';
import '../theme/colors.dart';
import '../extensions/string_extensions.dart';

class CommentList extends StatefulWidget {
  final String videoId;
  final bool showInput;

  const CommentList({
    super.key,
    required this.videoId,
    this.showInput = true,
  });

  @override
  State<CommentList> createState() => _CommentListState();
}

class _CommentListState extends State<CommentList> {
  final _videoService = VideoService();
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  List<Comment> _currentComments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _videoService.firestore
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();
      
      if (mounted) {
        setState(() {
          _currentComments = snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final newComment = await _videoService.addComment(
        widget.videoId,
        _commentController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _currentComments.insert(0, newComment);
          _commentController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString(),
              style: TextStyle(color: AppColors.background),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Comment list
        Expanded(
          child: _isLoading 
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                ),
              )
            : _currentComments.isEmpty && !_isSubmitting
              ? Center(
                  child: Text(
                    'no comments yet'.toLowerCase(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _currentComments.length,
                  itemBuilder: (context, index) {
                    final comment = _currentComments[index];
                    return _CommentTile(
                      comment: comment,
                      videoId: widget.videoId,
                    );
                  },
                ),
        ),

        // Comment input
        if (widget.showInput) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'add a comment...'.toLowerCase(),
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting ? null : _submitComment,
                  icon: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          Icons.send,
                          color: AppColors.accent,
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CommentTile extends StatefulWidget {
  final Comment comment;
  final String videoId;

  const _CommentTile({
    required this.comment,
    required this.videoId,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  final _videoService = VideoService();
  bool _hasLiked = false;
  int _likeCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.comment.likeCount;
    // Check initial like state
    _videoService.hasLikedComment(widget.videoId, widget.comment.id)
        .first
        .then((liked) {
          if (mounted) {
            setState(() => _hasLiked = liked);
          }
        });
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      // Optimistically update UI
      _hasLiked = !_hasLiked;
      _likeCount += _hasLiked ? 1 : -1;
    });

    try {
      await _videoService.toggleCommentLike(widget.videoId, widget.comment.id);
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _hasLiked = !_hasLiked;
          _likeCount += _hasLiked ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString(),
              style: TextStyle(color: AppColors.background),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.accent,
            backgroundImage: widget.comment.userPhotoUrl != null
                ? NetworkImage(widget.comment.userPhotoUrl!)
                : null,
            child: widget.comment.userPhotoUrl == null
                ? Icon(
                    Icons.person,
                    color: AppColors.background,
                    size: 20,
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and timestamp
                Row(
                  children: [
                    Text(
                      '@${widget.comment.username}'.toLowerCase(),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTimeAgo(widget.comment.createdAt),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Comment text
                Text(
                  widget.comment.text.toLowerCase(),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),

                // Like button
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: AppColors.accent,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _hasLiked ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: _hasLiked ? AppColors.accent : AppColors.textSecondary,
                            ),
                      const SizedBox(width: 4),
                      Text(
                        _likeCount.toString(),
                        style: TextStyle(
                          color: _hasLiked ? AppColors.accent : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
} 