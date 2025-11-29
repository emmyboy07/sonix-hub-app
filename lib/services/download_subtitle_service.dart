import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/downloaded_content.dart';

/// Service for handling subtitle downloads and management for downloaded content
class DownloadSubtitleService {
  static const String _subtitleApiBaseUrl =
      'https://www.opensubtitles.org/api/v1';
  static const int _maxRetries = 3;

  /// Download subtitles for content based on language preferences
  Future<List<DownloadedSubtitle>> downloadSubtitles({
    required DownloadedContent content,
    required List<String> preferredLanguages,
    required Directory downloadDir,
  }) async {
    final downloadedSubtitles = <DownloadedSubtitle>[];

    try {
      for (final languageCode in preferredLanguages) {
        try {
          final subtitle = await _downloadSingleSubtitle(
            content: content,
            languageCode: languageCode,
            downloadDir: downloadDir,
          );

          if (subtitle != null) {
            downloadedSubtitles.add(subtitle);
            debugPrint(
              '✅ Downloaded subtitle for ${content.displayTitle} - $languageCode',
            );
          }
        } catch (e) {
          debugPrint('⚠️ Failed to download $languageCode subtitle: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Subtitle download batch error: $e');
    }

    return downloadedSubtitles;
  }

  /// Download a single subtitle file
  Future<DownloadedSubtitle?> _downloadSingleSubtitle({
    required DownloadedContent content,
    required String languageCode,
    required Directory downloadDir,
  }) async {
    try {
      // This is a placeholder for actual subtitle fetching logic
      // You would integrate with subtitle APIs (OpenSubtitles, Subscene, etc.)

      // Example structure for storing subtitles
      final subtitleFileName =
          '${_sanitizeFilename(content.fileSystemName)}_$languageCode.srt';
      final subtitlePath = '${downloadDir.path}/subtitles/$subtitleFileName';

      // Ensure directory exists
      await Directory(File(subtitlePath).parent.path).create(recursive: true);

      // Fetch subtitle content (placeholder - implement with actual API)
      final subtitleContent = await _fetchSubtitleContent(
        content: content,
        languageCode: languageCode,
      );

      if (subtitleContent != null && subtitleContent.isNotEmpty) {
        final file = File(subtitlePath);
        await file.writeAsString(subtitleContent);

        return DownloadedSubtitle(
          language: _getLanguageName(languageCode),
          filePath: subtitlePath,
          languageCode: languageCode,
          fileSize: subtitleContent.length,
        );
      }
    } catch (e) {
      debugPrint('❌ Error downloading subtitle: $e');
    }

    return null;
  }

  /// Fetch subtitle content from API or source
  Future<String?> _fetchSubtitleContent({
    required DownloadedContent content,
    required String languageCode,
  }) async {
    try {
      // This should integrate with your actual subtitle provider
      // For production, use: OpenSubtitles API, Subscene, TvSubtitles, etc.

      debugPrint(
        '📥 Fetching subtitle for: ${content.displayTitle} ($languageCode)',
      );

      // Placeholder: return empty for now
      // Actual implementation would query subtitle APIs
      return null;
    } catch (e) {
      debugPrint('❌ Subtitle fetch error: $e');
      return null;
    }
  }

  /// Retry logic for failed subtitle downloads
  Future<DownloadedSubtitle?> _downloadWithRetry({
    required DownloadedContent content,
    required String languageCode,
    required Directory downloadDir,
    int attempt = 1,
  }) async {
    try {
      return await _downloadSingleSubtitle(
        content: content,
        languageCode: languageCode,
        downloadDir: downloadDir,
      );
    } catch (e) {
      if (attempt < _maxRetries) {
        await Future.delayed(Duration(seconds: attempt * 2));
        return _downloadWithRetry(
          content: content,
          languageCode: languageCode,
          downloadDir: downloadDir,
          attempt: attempt + 1,
        );
      }
      debugPrint('❌ Subtitle download failed after $_maxRetries attempts');
      return null;
    }
  }

  /// Get language name from language code
  static String _getLanguageName(String languageCode) {
    const languageMap = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'tr': 'Turkish',
      'pl': 'Polish',
      'nl': 'Dutch',
      'vi': 'Vietnamese',
      'id': 'Indonesian',
    };

    return languageMap[languageCode.toLowerCase()] ??
        languageCode.toUpperCase();
  }

  /// Sanitize filename for file system
  static String _sanitizeFilename(String filename) {
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  /// Delete subtitle file
  static Future<void> deleteSubtitle(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ Deleted subtitle: $filePath');
      }
    } catch (e) {
      debugPrint('❌ Error deleting subtitle: $e');
    }
  }

  /// Delete all subtitles for content
  static Future<void> deleteAllSubtitles(DownloadedContent content) async {
    for (final subtitle in content.subtitles) {
      await deleteSubtitle(subtitle.filePath);
    }
    debugPrint('✅ Deleted all subtitles for: ${content.displayTitle}');
  }

  /// Check if subtitle file exists
  static Future<bool> subtitleExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Get subtitle file size
  static Future<int> getSubtitleSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final stats = await file.stat();
        return stats.size;
      }
    } catch (e) {
      debugPrint('❌ Error getting subtitle size: $e');
    }
    return 0;
  }

  /// Verify all subtitle files exist for content
  static Future<bool> verifySubtitlesExist(DownloadedContent content) async {
    for (final subtitle in content.subtitles) {
      if (!await subtitleExists(subtitle.filePath)) {
        debugPrint('⚠️ Subtitle file missing: ${subtitle.filePath}');
        return false;
      }
    }
    return true;
  }

  /// Clean up missing subtitle references
  static Future<void> cleanupMissingSubtitles(DownloadedContent content) async {
    final toRemove = <DownloadedSubtitle>[];

    for (final subtitle in content.subtitles) {
      if (!await subtitleExists(subtitle.filePath)) {
        toRemove.add(subtitle);
      }
    }

    for (final subtitle in toRemove) {
      content.removeSubtitle(subtitle.languageCode);
    }

    if (toRemove.isNotEmpty) {
      debugPrint(
        '🧹 Cleaned up ${toRemove.length} missing subtitle references',
      );
    }
  }
}
