enum DownloadStatus { queued, downloading, paused, completed, failed }

class DownloadItem {
  final String id;
  final String title;
  final String? seriesName;
  final String? quality;
  final int? seasonNumber;
  final int? episodeNumber;
  final String videoUrl;
  final String? posterUrl;
  final List<Map<String, dynamic>>? subtitles;
  final bool isMovie;

  DownloadStatus status;
  double progress; // 0.0 to 1.0
  String? errorMessage;
  DateTime createdAt;
  DateTime? completedAt;

  // Download stats
  int bytesReceived = 0;
  int totalBytes = 0;
  int? speedBytesPerSecond; // bytes/sec
  Duration? eta; // estimated time remaining

  DownloadItem({
    required this.id,
    required this.title,
    required this.videoUrl,
    this.quality,
    this.seriesName,
    this.seasonNumber,
    this.episodeNumber,
    this.posterUrl,
    this.subtitles,
    required this.isMovie,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayTitle {
    if (isMovie) {
      return title;
    } else {
      final paddedEpisode = episodeNumber.toString().padLeft(2, '0');
      final paddedSeason = seasonNumber.toString().padLeft(2, '0');
      return '$seriesName S${paddedSeason}E$paddedEpisode${quality != null && quality!.isNotEmpty ? ' ($quality)' : ''}';
    }
  }

  String get progressPercentage => '${(progress * 100).toStringAsFixed(0)}%';

  /// Format speed to human readable format
  String get speedText {
    if (speedBytesPerSecond == null) return '--';
    final speed = speedBytesPerSecond!;
    if (speed < 1024) return '${speed}B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)}KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)}MB/s';
  }

  /// Format ETA to human readable format
  String get etaText {
    if (eta == null) return '--';
    final seconds = eta!.inSeconds;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).toStringAsFixed(0)}m';
    final hours = seconds / 3600;
    final minutes = (seconds % 3600) / 60;
    return '${hours.toStringAsFixed(0)}h ${minutes.toStringAsFixed(0)}m';
  }

  /// Format bytes to readable size
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get downloadedSizeText => formatBytes(bytesReceived);
  String get totalSizeText => formatBytes(totalBytes);
  String get sizeInfoText => '$downloadedSizeText / $totalSizeText';
}
