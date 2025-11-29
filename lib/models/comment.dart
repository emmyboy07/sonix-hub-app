class Comment {
  final String id;
  final String userName;
  final String commentText;
  final int likeCount;
  final DateTime createdAt;
  final List<Comment> replies;
  final String? parentCommentId;

  Comment({
    required this.id,
    required this.userName,
    required this.commentText,
    required this.likeCount,
    required this.createdAt,
    this.replies = const [],
    this.parentCommentId,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Anonymous',
      commentText: json['comment_text'] as String? ?? '',
      likeCount: json['like_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      replies: json['replies'] != null
          ? (json['replies'] as List)
              .map((reply) => Comment.fromJson(reply as Map<String, dynamic>))
              .toList()
          : [],
      parentCommentId: json['parent_comment_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_name': userName,
      'comment_text': commentText,
      'like_count': likeCount,
      'created_at': createdAt.toIso8601String(),
      'replies': replies.map((r) => r.toJson()).toList(),
      if (parentCommentId != null) 'parent_comment_id': parentCommentId,
    };
  }

  Comment copyWith({
    String? id,
    String? userName,
    String? commentText,
    int? likeCount,
    DateTime? createdAt,
    List<Comment>? replies,
    String? parentCommentId,
  }) {
    return Comment(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      commentText: commentText ?? this.commentText,
      likeCount: likeCount ?? this.likeCount,
      createdAt: createdAt ?? this.createdAt,
      replies: replies ?? this.replies,
      parentCommentId: parentCommentId ?? this.parentCommentId,
    );
  }
}

class LikeStatus {
  final int likeCount;
  final bool userLiked;

  LikeStatus({
    required this.likeCount,
    required this.userLiked,
  });

  factory LikeStatus.fromJson(Map<String, dynamic> json) {
    return LikeStatus(
      likeCount: json['like_count'] as int? ?? 0,
      userLiked: json['user_liked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'like_count': likeCount,
      'user_liked': userLiked,
    };
  }
}
