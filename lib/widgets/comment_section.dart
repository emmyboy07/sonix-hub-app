import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../config/theme.dart';
import '../models/comment.dart';
import '../providers/comments_provider.dart';

class CommentSection extends StatefulWidget {
  final int tmdbId;
  final bool isTV;

  const CommentSection({
    super.key,
    required this.tmdbId,
    required this.isTV,
  });

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  late TextEditingController _commentController;
  late TextEditingController _replyController;
  final ScrollController _scrollController = ScrollController();
  String? _replyingToCommentId;
  String? _replyingToUserName;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _replyController = TextEditingController();
    // Load comments when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<CommentsProvider>();
        if (widget.isTV) {
          provider.fetchTVComments(widget.tmdbId);
        } else {
          provider.fetchMovieComments(widget.tmdbId);
        }
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _postComment(bool isReply) async {
    final text = isReply ? _replyController.text.trim() : _commentController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<CommentsProvider>();
    final success = widget.isTV
        ? await provider.postTVComment(
            tmdbId: widget.tmdbId,
            commentText: text,
            parentCommentId: _replyingToCommentId,
          )
        : await provider.postMovieComment(
            tmdbId: widget.tmdbId,
            commentText: text,
            parentCommentId: _replyingToCommentId,
          );

    if (success) {
      if (isReply) {
        _replyController.clear();
        _replyingToCommentId = null;
        _replyingToUserName = null;
      } else {
        _commentController.clear();
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isReply
                ? 'Reply posted successfully!'
                : 'Comment posted successfully!',
            style: TextStyle(color: AppTheme.white),
          ),
          backgroundColor: Colors.green.withOpacity(0.8),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to post comment',
            style: TextStyle(color: AppTheme.white),
          ),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comments header with icon
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: AppTheme.primaryRed,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_replyingToCommentId != null)
                      Text(
                        'Replying to $_replyingToUserName',
                        style: TextStyle(
                          color: AppTheme.primaryRed,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        'Comments',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (_replyingToCommentId == null)
                      Consumer<CommentsProvider>(
                        builder: (context, provider, _) {
                          return Text(
                            '${provider.comments.length} comments',
                            style: TextStyle(
                              color: AppTheme.lightGray,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
            if (_replyingToCommentId != null)
              GestureDetector(
                onTap: () {
                  _replyController.clear();
                  setState(() {
                    _replyingToCommentId = null;
                    _replyingToUserName = null;
                  });
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppTheme.primaryRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // Comment input section with improved styling (only show when not replying)
        if (_replyingToCommentId == null)
        Container(
          decoration: BoxDecoration(
            color: AppTheme.mediumBlack,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryRed.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryRed.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text input with improved styling
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkBlack.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.lightGray.withOpacity(0.2),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _commentController,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(color: AppTheme.white, fontSize: 14, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(
                      color: AppTheme.lightGray.withOpacity(0.5),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Post button with improved styling
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Consumer<CommentsProvider>(
                    builder: (context, provider, _) {
                      return Text(
                        'As ${provider.userName}',
                        style: TextStyle(
                          color: AppTheme.lightGray,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _postComment(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                    ),
                    icon: Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: AppTheme.white,
                    ),
                    label: Text(
                      'Post',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Comments list
        Consumer<CommentsProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryRed,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading comments...',
                        style: TextStyle(
                          color: AppTheme.lightGray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (provider.comments.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.mediumBlack,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.chat_outlined,
                          color: AppTheme.lightGray,
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No comments yet',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to share your thoughts!',
                        style: TextStyle(
                          color: AppTheme.lightGray,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.comments.length,
              itemBuilder: (context, index) {
                return _CommentTile(
                  comment: provider.comments[index],
                  onReply: (commentId, userName) {
                    setState(() {
                      _replyingToCommentId = commentId;
                      _replyingToUserName = userName;
                    });
                    // Scroll to input
                    Scrollable.ensureVisible(
                      context,
                      alignment: 0.1,
                      duration: const Duration(milliseconds: 300),
                    );
                  },
                  isTV: widget.isTV,
                  tmdbId: widget.tmdbId,
                );
              },
            );
          },
        ),

        // Reply input section (appears inline when replying)
        if (_replyingToCommentId != null) ...[
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.mediumBlack,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryRed.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryRed.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your reply to $_replyingToUserName:',
                  style: TextStyle(
                    color: AppTheme.lightGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkBlack.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.lightGray.withOpacity(0.2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: TextField(
                    controller: _replyController,
                    maxLines: 3,
                    minLines: 1,
                    style: TextStyle(color: AppTheme.white, fontSize: 14, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'Write your reply...',
                      hintStyle: TextStyle(
                        color: AppTheme.lightGray.withOpacity(0.5),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Consumer<CommentsProvider>(
                      builder: (context, provider, _) {
                        return Text(
                          'As ${provider.userName}',
                          style: TextStyle(
                            color: AppTheme.lightGray,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _postComment(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 4,
                      ),
                      icon: Icon(
                        Icons.send_rounded,
                        size: 16,
                        color: AppTheme.white,
                      ),
                      label: Text(
                        'Reply',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
  final Function(String commentId, String userName) onReply;
  final bool isTV;
  final int tmdbId;

  const _CommentTile({
    required this.comment,
    required this.onReply,
    required this.isTV,
    required this.tmdbId,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _showReplies = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkBlack.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightGray.withOpacity(0.1),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User name and time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.comment.userName,
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatTime(widget.comment.createdAt),
                      style: TextStyle(
                        color: AppTheme.lightGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Comment text
                Text(
                  widget.comment.commentText,
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Like and Reply buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Like button
                    _LikeButton(
                      commentId: widget.comment.id,
                      initialLikeCount: widget.comment.likeCount,
                    ),

                    // Reply button
                    GestureDetector(
                      onTap: () {
                        widget.onReply(
                          widget.comment.id,
                          widget.comment.userName,
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply,
                            color: AppTheme.lightGray,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Reply',
                            style: TextStyle(
                              color: AppTheme.lightGray,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Report button
                    GestureDetector(
                      onTap: () {
                        _showReportDialog(context);
                      },
                      child: Tooltip(
                        message: 'Report comment',
                        child: Icon(
                          Icons.flag_outlined,
                          color: AppTheme.lightGray,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),

                // Show replies button
                if (widget.comment.replies.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showReplies = !_showReplies;
                      });
                    },
                    child: Text(
                      _showReplies
                          ? 'Hide ${widget.comment.replies.length} ${widget.comment.replies.length == 1 ? 'reply' : 'replies'}'
                          : 'Show ${widget.comment.replies.length} ${widget.comment.replies.length == 1 ? 'reply' : 'replies'}',
                      style: TextStyle(
                        color: AppTheme.primaryRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Replies
          if (_showReplies && widget.comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.comment.replies
                    .map(
                      (reply) => _ReplyTile(
                        reply: reply,
                        onReply: widget.onReply,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        String selectedReason = 'spam';
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.mediumBlack,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryRed.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryRed.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: AppTheme.primaryRed,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Report Comment',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Help us keep the community safe',
                  style: TextStyle(
                    color: AppTheme.lightGray,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Select a reason:',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...[
                  ('spam', 'Spam'),
                  ('harassment', 'Harassment'),
                  ('inappropriate', 'Inappropriate Content'),
                  ('other', 'Other'),
                ].map((option) {
                  return GestureDetector(
                    onTap: () {
                      selectedReason = option.$1;
                      Navigator.pop(dialogContext);
                      _submitReport(context, selectedReason);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBlack.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.lightGray.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.radio_button_unchecked,
                            color: AppTheme.primaryRed,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            option.$2,
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppTheme.lightGray,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitReport(BuildContext context, String reason) async {
    final provider = context.read<CommentsProvider>();
    final success = await provider.reportComment(
      commentId: widget.comment.id,
      reason: reason,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Comment reported successfully' : 'Failed to report comment',
            style: TextStyle(color: AppTheme.white),
          ),
          backgroundColor: success ? Colors.green.withOpacity(0.8) : AppTheme.primaryRed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class _ReplyTile extends StatelessWidget {
  final Comment reply;
  final Function(String commentId, String userName) onReply;

  const _ReplyTile({
    required this.reply,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
            decoration: BoxDecoration(
          color: AppTheme.darkBlack.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.lightGray.withOpacity(0.08),
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User name and time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  reply.userName,
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatTime(reply.createdAt),
                  style: TextStyle(
                    color: AppTheme.lightGray,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Reply text
            Text(
              reply.commentText,
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),

            // Like and Reply buttons (compact)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LikeButton(
                  commentId: reply.id,
                  initialLikeCount: reply.likeCount,
                  isReply: true,
                ),
                GestureDetector(
                  onTap: () {
                    onReply(reply.id, reply.userName);
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.reply,
                        color: AppTheme.lightGray,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reply',
                        style: TextStyle(
                          color: AppTheme.lightGray,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class _LikeButton extends StatefulWidget {
  final String commentId;
  final int initialLikeCount;
  final bool isReply;

  const _LikeButton({
    required this.commentId,
    required this.initialLikeCount,
    this.isReply = false,
  });

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;

    final provider = context.read<CommentsProvider>();

    _isLoading = true;
    debugPrint('🔵 Toggling like for comment: ${widget.commentId}');
    
    // Start animation immediately (don't wait)
    unawaited(_scaleController.forward().then((_) {
      _scaleController.reverse();
    }));

    // Call API in background (don't wait for response before returning)
    final success = await provider.toggleLike(widget.commentId);

    if (!success) {
      debugPrint('❌ Like toggle failed for: ${widget.commentId}');
      if (mounted) {
        _showErrorSnackbar();
      }
    } else {
      debugPrint('✅ Like toggle successful for: ${widget.commentId}');
    }
    
    _isLoading = false;
  }

  void _showErrorSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.white, size: 18),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Failed to update like'),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryRed.withOpacity(0.8),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommentsProvider>(
      builder: (context, provider, _) {
        // Get the current like status from provider
        final likeStatus = provider.likeStatuses[widget.commentId];
        final isLiked = likeStatus?.userLiked ?? false;
        final likeCount = likeStatus?.likeCount ?? widget.initialLikeCount;

        return GestureDetector(
          onTap: _toggleLike,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.15).animate(
              CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
            ),
            child: Row(
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: isLiked ? 1.2 : 1.0,
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? AppTheme.primaryRed : AppTheme.lightGray,
                    size: widget.isReply ? 14 : 16,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isLiked ? AppTheme.primaryRed : AppTheme.lightGray,
                    fontSize: widget.isReply ? 11 : 12,
                    fontWeight: isLiked ? FontWeight.w700 : FontWeight.w400,
                  ),
                  child: Text(likeCount.toString()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
