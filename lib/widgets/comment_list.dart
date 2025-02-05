import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/video_service.dart';
import '../theme/colors.dart';
import '../extensions/string_extensions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  void removeComment(Comment comment) {
    setState(() {
      _currentComments.removeWhere((c) => c.id == comment.id);
    });
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
                  padding: const EdgeInsets.symmetric(vertical: 4),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _hasLiked = false;
  int _likeCount = 0;
  bool _isLoading = false;
  String _username = '';
  String? _userPhotoUrl;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.comment.likeCount;
    _loadUserInfo();
    _checkLikeState();
  }

  @override
  void didUpdateWidget(_CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.userId != widget.comment.userId) {
      // Reset user info and reload if the comment changed
      setState(() {
        _username = '';
        _userPhotoUrl = null;
      });
      _loadUserInfo();
    }
    if (oldWidget.comment.id != widget.comment.id) {
      _checkLikeState();
    }
  }

  Future<void> _checkLikeState() async {
    final liked = await _videoService.hasLikedComment(widget.videoId, widget.comment.id).first;
    if (mounted) {
      setState(() => _hasLiked = liked);
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final userDoc = await _firestore.collection('users').doc(widget.comment.userId).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _username = userDoc.data()?['displayName'] ?? '';
          _userPhotoUrl = userDoc.data()?['photoUrl'];
        });
      }
    } catch (e) {
      print('Error loading user info: $e');
    }
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

  Future<void> _deleteComment() async {
    try {
      await _videoService.deleteComment(widget.videoId, widget.comment.id);
      if (mounted) {
        // Remove comment from parent list
        final commentList = context.findAncestorStateOfType<_CommentListState>();
        commentList?.removeComment(widget.comment);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: TextStyle(color: AppColors.background),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCommentOwner = _auth.currentUser?.uid == widget.comment.userId;

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: widget.comment.userId),
            ),
          );
        },
        child: CircleAvatar(
          backgroundColor: AppColors.accent,
          backgroundImage: _userPhotoUrl != null ? NetworkImage(_userPhotoUrl!) : null,
          child: _userPhotoUrl == null
            ? Text(
                _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                style: TextStyle(color: AppColors.background),
              )
            : null,
        ),
      ),
      title: Row(
        children: [
          Text(
            _username.toLowerCase(),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeago.format(widget.comment.createdAt).toLowerCase(),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
      subtitle: Text(
        widget.comment.text.toLowerCase(),
        style: TextStyle(
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Like button
          IconButton(
            onPressed: _toggleLike,
            icon: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  _hasLiked ? Icons.favorite : Icons.favorite_border,
                  color: _hasLiked ? AppColors.accent : AppColors.textSecondary,
                  size: 20,
                ),
          ),
          Text(
            '$_likeCount',
            style: TextStyle(
              color: _hasLiked ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
          if (isCommentOwner) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.background,
                    title: Text(
                      'delete comment?'.toLowerCase(),
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    content: Text(
                      'this action cannot be undone.'.toLowerCase(),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'cancel'.toLowerCase(),
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteComment();
                        },
                        child: Text(
                          'delete'.toLowerCase(),
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
} 