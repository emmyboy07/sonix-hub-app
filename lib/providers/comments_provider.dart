import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comment.dart';
import '../services/comment_service.dart';

class CommentsProvider extends ChangeNotifier {
  List<Comment> _comments = [];
  Map<String, LikeStatus> _likeStatuses = {};
  String _userName = 'Anonymous';
  bool _isLoading = false;
  String? _errorMessage;
  int? _currentMediaId;
  bool _currentIsTV = false;

  // Getters
  List<Comment> get comments => _comments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get userName => _userName;
  Map<String, LikeStatus> get likeStatuses => _likeStatuses;

  CommentsProvider() {
    _loadUserName();
  }

  /// Load user's custom name from SharedPreferences
  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('comment_user_name') ?? 'Anonymous';
      notifyListeners();
    } catch (e) {
      // If error, default to Anonymous
      _userName = 'Anonymous';
    }
  }

  /// Save user's custom name to SharedPreferences
  Future<void> setUserName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final finalName = name.trim().isEmpty ? 'Anonymous' : name.trim();
      await prefs.setString('comment_user_name', finalName);
      _userName = finalName;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to save name: $e';
      notifyListeners();
    }
  }

  /// Fetch comments for a movie
  Future<void> fetchMovieComments(int tmdbId) async {
    _currentMediaId = tmdbId;
    _currentIsTV = false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _comments = await CommentService.getMovieComments(tmdbId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch comments for a TV series
  Future<void> fetchTVComments(int tmdbId) async {
    _currentMediaId = tmdbId;
    _currentIsTV = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _comments = await CommentService.getTVComments(tmdbId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Post a comment on a movie
  Future<bool> postMovieComment({
    required int tmdbId,
    required String commentText,
    String? parentCommentId,
  }) async {
    try {
      final newComment = await CommentService.postMovieComment(
        tmdbId: tmdbId,
        userName: _userName,
        commentText: commentText,
        parentCommentId: parentCommentId,
      );

      if (newComment != null) {
        // Refetch all comments to get latest data
        await fetchMovieComments(tmdbId);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Post a comment on a TV series
  Future<bool> postTVComment({
    required int tmdbId,
    required String commentText,
    String? parentCommentId,
  }) async {
    try {
      final newComment = await CommentService.postTVComment(
        tmdbId: tmdbId,
        userName: _userName,
        commentText: commentText,
        parentCommentId: parentCommentId,
      );

      if (newComment != null) {
        // Refetch all comments to get latest data
        await fetchTVComments(tmdbId);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggle like on a comment
  Future<bool> toggleLike(String commentId) async {
    try {
      // Get current like status
      final currentLikeStatus = _likeStatuses[commentId];
      final wasLiked = currentLikeStatus?.userLiked ?? false;
      final currentLikeCount = currentLikeStatus?.likeCount ?? 0;

      // Simple logic: if liked, unlike (-1), if not liked, like (+1)
      final newLikeCount = wasLiked ? currentLikeCount - 1 : currentLikeCount + 1;
      
      // Update state
      _likeStatuses[commentId] = LikeStatus(
        likeCount: newLikeCount,
        userLiked: !wasLiked,
      );
      
      // Update the like count in comments list
      _updateCommentLikeCountInPlace(commentId, newLikeCount);
      notifyListeners();

      debugPrint('❤️ Like toggled: $commentId -> $newLikeCount likes, liked=${!wasLiked}');

      // Make API request in background (fire and forget)
      try {
        await CommentService.toggleLike(
          commentId: commentId,
          userName: _userName,
        );
        debugPrint('✅ API confirmed like toggle for: $commentId');
      } catch (e) {
        // Log error but don't fail - UI already updated
        debugPrint('⚠️ API error (UI already updated): $e');
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('💥 Error in toggleLike: $e');
      notifyListeners();
      return false;
    }
  }

  /// Update like count in comments list in place
  void _updateCommentLikeCountInPlace(String commentId, int newLikeCount) {
    for (int i = 0; i < _comments.length; i++) {
      if (_comments[i].id == commentId) {
        _comments[i] = _comments[i].copyWith(likeCount: newLikeCount);
        return;
      }
      // Check in replies
      _updateLikeCountInReplies(_comments[i].replies, commentId, newLikeCount);
    }
  }

  /// Recursively update like count in replies
  void _updateLikeCountInReplies(
    List<Comment> replies,
    String commentId,
    int newLikeCount,
  ) {
    for (int i = 0; i < replies.length; i++) {
      if (replies[i].id == commentId) {
        replies[i] = replies[i].copyWith(likeCount: newLikeCount);
        return;
      }
      _updateLikeCountInReplies(replies[i].replies, commentId, newLikeCount);
    }
  }

  /// Report a comment
  Future<bool> reportComment({
    required String commentId,
    required String reason,
  }) async {
    try {
      return await CommentService.reportComment(
        commentId: commentId,
        reporterName: _userName,
        reason: reason,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear comments
  void clearComments() {
    _comments = [];
    _likeStatuses = {};
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
