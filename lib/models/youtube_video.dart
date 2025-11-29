class YouTubeVideo {
  final String id;
  final String title;
  final String channelName;
  final String channelId;
  final String thumbnailUrl;
  final Duration duration;
  final int viewCount;
  final DateTime? uploadDate;
  final String description;

  YouTubeVideo({
    required this.id,
    required this.title,
    required this.channelName,
    required this.channelId,
    required this.thumbnailUrl,
    required this.duration,
    required this.viewCount,
    this.uploadDate,
    required this.description,
  });

  String get formattedDuration {
    final d = duration;
    if (d.inHours > 0) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
