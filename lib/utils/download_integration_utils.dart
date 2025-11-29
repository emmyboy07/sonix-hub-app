import '../models/downloaded_content.dart';
import 'dart:io';
import '../services/production_download_manager.dart';
import '../services/download_subtitle_service.dart';

/// Utility class for download system integration across the app
class DownloadIntegrationUtils {
  /// Check if content is available as download
  static Future<DownloadedContent?> getDownloadedContent(
    int tmdbId, {
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    final manager = ProductionDownloadManager();
    return manager.getDownloadedContent(
      tmdbId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
  }

  /// Check if content is downloaded and completed
  static bool isContentDownloaded(
    int tmdbId, {
    int? seasonNumber,
    int? episodeNumber,
  }) {
    final manager = ProductionDownloadManager();
    return manager.isDownloaded(
      tmdbId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
  }

  /// Get download status for a specific content
  static DownloadStatus? getDownloadStatus(String downloadId) {
    final manager = ProductionDownloadManager();
    final content = manager.getDownload(downloadId);
    return content?.status;
  }

  /// Format subtitle list for UI
  static String formatSubtitleInfo(List<DownloadedSubtitle> subtitles) {
    if (subtitles.isEmpty) return 'No subtitles';
    if (subtitles.length == 1) return 'English';

    final languages = subtitles.map((s) => s.language).join(', ');
    return '$languages (${subtitles.length})';
  }

  /// Get human readable download status
  static String getStatusLabel(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return 'Downloaded';
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.queued:
        return 'Queued';
    }
  }

  /// Format download size for display
  static String formatDownloadSize(int bytes) {
    return DownloadedContent.formatBytes(bytes);
  }

  /// Get subtitle file for player
  static String? getSubtitlePath(
    List<DownloadedSubtitle> subtitles,
    String languageCode,
  ) {
    try {
      return subtitles
          .firstWhere(
            (s) => s.languageCode.toLowerCase() == languageCode.toLowerCase(),
          )
          .filePath;
    } catch (e) {
      return null;
    }
  }

  /// Verify downloaded content integrity
  static Future<bool> verifyDownloadIntegrity(DownloadedContent content) async {
    try {
      // Verify video file exists
      final videoExists = await _fileExists(content.videoFilePath);
      if (!videoExists) {
        return false;
      }

      // Verify all subtitles exist
      final subtitlesValid = await DownloadSubtitleService.verifySubtitlesExist(
        content,
      );

      return subtitlesValid;
    } catch (e) {
      return false;
    }
  }

  /// Cleanup corrupted download
  static Future<void> cleanupCorruptedDownload(
    DownloadedContent content,
  ) async {
    try {
      // Delete video file
      await _deleteFile(content.videoFilePath);

      // Delete subtitle files
      await DownloadSubtitleService.deleteAllSubtitles(content);

      // Remove from manager
      final manager = ProductionDownloadManager();
      await manager.cancelDownload(content.id);
    } catch (e) {
      // Silent fail
    }
  }

  /// Private helpers
  static Future<bool> _fileExists(String path) async {
    try {
      final file = await File(path).exists();
      return file;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Silent fail
    }
  }
}

// Import File from dart:io
