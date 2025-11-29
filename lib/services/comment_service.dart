import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/comment.dart';

class CommentService {
  static const String baseUrl = 'https://sonix-comment-system.vercel.app';
  static const String apiKey = 'sonixhubcomments'; // TODO: Store securely in app config

  /// Get all comments for a movie
  static Future<List<Comment>> getMovieComments(int tmdbId) async {
    try {
      final url = Uri.parse('$baseUrl/api/comments/movie/$tmdbId');
      final response = await http.get(
        url,
        headers: {
          'x-mobile-api-key': apiKey,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> commentsList = data['comments'] ?? [];
        return commentsList
            .map((comment) => Comment.fromJson(comment as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 404) {
        // No comments yet for this movie
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to fetch comments: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get all comments for a TV series
  static Future<List<Comment>> getTVComments(int tmdbId) async {
    try {
      final url = Uri.parse('$baseUrl/api/comments/tv/$tmdbId');
      final response = await http.get(
        url,
        headers: {
          'x-mobile-api-key': apiKey,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> commentsList = data['comments'] ?? [];
        return commentsList
            .map((comment) => Comment.fromJson(comment as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 404) {
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to fetch comments: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Post a new comment on a movie
  static Future<Comment?> postMovieComment({
    required int tmdbId,
    required String userName,
    required String commentText,
    String? parentCommentId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/comments/movie/$tmdbId');
      final body = {
        'user_name': userName,
        'comment_text': commentText,
        if (parentCommentId != null) 'parent_comment_id': parentCommentId,
      };

      final response = await http.post(
        url,
        headers: {
          'x-mobile-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Comment.fromJson(data as Map<String, dynamic>);
      } else if (response.statusCode == 400) {
        throw Exception('Bad request: Invalid parameters');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to post comment: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Post a new comment on a TV series
  static Future<Comment?> postTVComment({
    required int tmdbId,
    required String userName,
    required String commentText,
    String? parentCommentId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/comments/tv/$tmdbId');
      final body = {
        'user_name': userName,
        'comment_text': commentText,
        if (parentCommentId != null) 'parent_comment_id': parentCommentId,
      };

      final response = await http.post(
        url,
        headers: {
          'x-mobile-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Comment.fromJson(data as Map<String, dynamic>);
      } else if (response.statusCode == 400) {
        throw Exception('Bad request: Invalid parameters');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to post comment: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Like or unlike a comment (toggle)
  static Future<Map<String, dynamic>> toggleLike({
    required String commentId,
    required String userName,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/likes');
      final body = {
        'comment_id': commentId,
        'user_name': userName,
      };

      final response = await http.post(
        url,
        headers: {
          'x-mobile-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 400) {
        throw Exception('Bad request: Invalid parameters');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to toggle like: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get like status for a comment
  static Future<LikeStatus> getLikeStatus({
    required String commentId,
    required String userName,
  }) async {
    try {
      final url = Uri.parse(
        '$baseUrl/api/likes/$commentId?user_name=${Uri.encodeComponent(userName)}',
      );
      final response = await http.get(
        url,
        headers: {
          'x-mobile-api-key': apiKey,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LikeStatus.fromJson(data as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        return LikeStatus(likeCount: 0, userLiked: false);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to get like status: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Report a comment
  static Future<bool> reportComment({
    required String commentId,
    required String reporterName,
    required String reason, // spam, harassment, inappropriate, other
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/reports');
      final body = {
        'comment_id': commentId,
        'reporter_name': reporterName,
        'reason': reason,
      };

      final response = await http.post(
        url,
        headers: {
          'x-mobile-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else if (response.statusCode == 400) {
        throw Exception('Bad request: Invalid parameters');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to report comment: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
