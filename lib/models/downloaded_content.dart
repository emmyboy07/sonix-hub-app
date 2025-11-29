import 'dart:convert';

enum DownloadStatus { queued, downloading, paused, completed, failed }

/// Represents a downloaded subtitle file
class DownloadedSubtitle {
  final String language;
  final String filePath;
  final String languageCode;
  final int fileSize;

  DownloadedSubtitle({
    required this.language,
    required this.filePath,
    required this.languageCode,
    required this.fileSize,
  });

  Map<String, dynamic> toJson() => {
    'language': language,
    'filePath': filePath,
    'languageCode': languageCode,
    'fileSize': fileSize,
  };

  factory DownloadedSubtitle.fromJson(Map<String, dynamic> json) =>
      DownloadedSubtitle(
        language: json['language'] as String,
        filePath: json['filePath'] as String,
        languageCode: json['languageCode'] as String,
        fileSize: json['fileSize'] as int? ?? 0,
      );
}

/// Production-ready model for downloaded movies/episodes with subtitle management
class DownloadedContent {
  final String id;
  final String title;
  final String? seriesName;
  final int? seasonNumber;
  final int? episodeNumber;
  final String videoFilePath;
  final String? posterPath;
  final String? backdropPath;
  final int tmdbId;
  final bool isMovie;

  DownloadStatus status;
  double progress;
  String? errorMessage;
  DateTime createdAt;
  DateTime? completedAt;

  // Subtitles management
  final List<DownloadedSubtitle> subtitles;

  // Download statistics
  int bytesReceived = 0;
  int totalBytes = 0;
  int? speedBytesPerSecond;
  Duration? eta;

  // Metadata
  String? quality; // 480p, 720p, 1080p, etc.
  int? duration; // in milliseconds
  String? videoCodec;
  String? audioCodec;

  DownloadedContent({
    required this.id,
    required this.title,
    required this.videoFilePath,
    required this.tmdbId,
    required this.isMovie,
    this.seriesName,
    this.seasonNumber,
    this.episodeNumber,
    this.posterPath,
    this.backdropPath,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.subtitles = const [],
    DateTime? createdAt,
    this.quality,
    this.duration,
    this.videoCodec,
    this.audioCodec,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Display title - shows S##E## for episodes
  String get displayTitle {
    if (isMovie) {
      return title;
    } else {
      final s = seasonNumber.toString().padLeft(2, '0');
      final e = episodeNumber.toString().padLeft(2, '0');
      return '$seriesName S${s}E$e';
    }
  }

  /// Unique display name for file system
  String get fileSystemName {
    if (isMovie) {
      return '$title.mkv';
    } else {
      final s = seasonNumber.toString().padLeft(2, '0');
      final e = episodeNumber.toString().padLeft(2, '0');
      return '${seriesName}_S${s}E$e.mkv';
    }
  }

  /// Progress as percentage
  String get progressPercentage => '${(progress * 100).toStringAsFixed(0)}%';

  /// Speed in human-readable format
  String get speedText {
    if (speedBytesPerSecond == null || speedBytesPerSecond == 0) return '--';
    final speed = speedBytesPerSecond!;
    if (speed < 1024) return '${speed}B/s';
    if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)}KB/s';
    }
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)}MB/s';
  }

  /// ETA in human-readable format
  String get etaText {
    if (eta == null) return '--';
    final seconds = eta!.inSeconds;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).toStringAsFixed(0)}m';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  /// Format bytes to readable size
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get downloadedSizeText => formatBytes(bytesReceived);
  String get totalSizeText => formatBytes(totalBytes);
  String get sizeInfoText => '$downloadedSizeText / $totalSizeText';

  /// Add or update a subtitle
  void addSubtitle(DownloadedSubtitle subtitle) {
    // Remove existing subtitle with same language code
    subtitles.removeWhere((s) => s.languageCode == subtitle.languageCode);
    subtitles.add(subtitle);
  }

  /// Remove subtitle by language code
  void removeSubtitle(String languageCode) {
    subtitles.removeWhere((s) => s.languageCode == languageCode);
  }

  /// Get subtitle by language code
  DownloadedSubtitle? getSubtitle(String languageCode) {
    try {
      return subtitles.firstWhere(
        (s) => s.languageCode.toLowerCase() == languageCode.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// JSON serialization for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'seriesName': seriesName,
    'seasonNumber': seasonNumber,
    'episodeNumber': episodeNumber,
    'videoFilePath': videoFilePath,
    'posterPath': posterPath,
    'backdropPath': backdropPath,
    'tmdbId': tmdbId,
    'isMovie': isMovie,
    'status': status.toString(),
    'progress': progress,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'subtitles': subtitles.map((s) => s.toJson()).toList(),
    'quality': quality,
    'duration': duration,
    'videoCodec': videoCodec,
    'audioCodec': audioCodec,
  };

  /// JSON deserialization from storage
  factory DownloadedContent.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] as String).split('.').last;
    final status = DownloadStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => DownloadStatus.completed,
    );

    final subtitlesList =
        (json['subtitles'] as List<dynamic>?)?.map((s) {
          return DownloadedSubtitle.fromJson(s as Map<String, dynamic>);
        }).toList() ??
        [];

    return DownloadedContent(
      id: json['id'] as String,
      title: json['title'] as String,
      seriesName: json['seriesName'] as String?,
      seasonNumber: json['seasonNumber'] as int?,
      episodeNumber: json['episodeNumber'] as int?,
      videoFilePath: json['videoFilePath'] as String,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      tmdbId: json['tmdbId'] as int,
      isMovie: json['isMovie'] as bool,
      status: status,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      quality: json['quality'] as String?,
      duration: json['duration'] as int?,
      videoCodec: json['videoCodec'] as String?,
      audioCodec: json['audioCodec'] as String?,
      subtitles: subtitlesList,
    );
  }
}
