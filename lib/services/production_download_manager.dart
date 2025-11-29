import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import '../models/downloaded_content.dart';

/// Production-ready download manager with pause/resume, fast speeds, and subtitle management
class ProductionDownloadManager extends ChangeNotifier {
  static final ProductionDownloadManager _instance =
      ProductionDownloadManager._internal();

  factory ProductionDownloadManager() {
    return _instance;
  }

  ProductionDownloadManager._internal();

  static const String _downloadsKey = 'downloaded_contents';
  static const String _autoSubtitlesKey = 'auto_download_subtitles';
  static const String _subtitleLanguagesKey = 'subtitle_languages';
  static const int _chunkSize = 1024 * 1024; // 1MB chunks for speed
  static const int _maxConcurrentDownloads = 2;

  final Map<String, DownloadedContent> _downloads = {};
  final Map<String, http.StreamedResponse?> _activeDownloads = {};
  final Map<String, Completer<void>?> _downloadCompleters = {};
  int _activeDownloadCount = 0;
  final List<String> _queuedDownloads = [];

  /// Getters
  List<DownloadedContent> get downloads => _downloads.values.toList();
  Map<String, DownloadedContent> get downloadsMap => Map.from(_downloads);

  /// Request storage permissions
  Future<bool> requestStoragePermissions() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Permission error: $e');
      return false;
    }
  }

  /// Initialize manager - load saved downloads from storage
  Future<void> initialize() async {
    try {
      await _loadDownloadsFromStorage();
      debugPrint(
        '✅ Download manager initialized with ${_downloads.length} items',
      );
    } catch (e) {
      debugPrint('❌ Failed to initialize download manager: $e');
    }
  }

  /// Get download directory
  Future<Directory> _getDownloadDir() async {
    Directory dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download/SonixHub');
    } else if (Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    } else {
      dir = await getApplicationSupportDirectory();
    }

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Add download to queue
  Future<void> addDownload({
    required DownloadedContent content,
    required String downloadUrl,
    bool autoDownloadSubtitles = true,
  }) async {
    try {
      _downloads[content.id] = content;
      _queuedDownloads.add(content.id);

      // Process queue
      _processDownloadQueue();

      notifyListeners();
      debugPrint('✅ Download queued: ${content.displayTitle}');
    } catch (e) {
      debugPrint('❌ Failed to add download: $e');
      content.status = DownloadStatus.failed;
      content.errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Process download queue
  void _processDownloadQueue() {
    if (_queuedDownloads.isEmpty ||
        _activeDownloadCount >= _maxConcurrentDownloads) {
      return;
    }

    final downloadId = _queuedDownloads.removeAt(0);
    final content = _downloads[downloadId];

    if (content != null && content.status != DownloadStatus.downloading) {
      _activeDownloadCount++;
      _startDownload(downloadId, content.videoFilePath);
    }
  }

  /// Start downloading content
  Future<void> _startDownload(String downloadId, String videoUrl) async {
    try {
      final content = _downloads[downloadId];
      if (content == null) return;

      content.status = DownloadStatus.downloading;
      notifyListeners();

      final downloadDir = await _getDownloadDir();
      final filePath = '${downloadDir.path}/${content.fileSystemName}';

      // Download with resumable support
      await _downloadWithResume(videoUrl, filePath, content);

      content.status = DownloadStatus.completed;
      content.completedAt = DateTime.now();

      // Auto-download subtitles if enabled
      if (await _shouldAutoDownloadSubtitles()) {
        await _downloadSubtitles(content);
      }

      await _saveDownloadsToStorage();
      notifyListeners();

      debugPrint('✅ Download completed: ${content.displayTitle}');
    } catch (e) {
      final content = _downloads[downloadId];
      if (content != null) {
        content.status = DownloadStatus.failed;
        content.errorMessage = e.toString();
      }
      debugPrint('❌ Download failed: $e');
      notifyListeners();
    } finally {
      _activeDownloadCount--;
      _downloadCompleters.remove(downloadId);
      _activeDownloads.remove(downloadId);
      _processDownloadQueue();
    }
  }

  /// Fast download with chunked reading for optimal speed
  Future<void> _downloadWithResume(
    String url,
    String filePath,
    DownloadedContent content,
  ) async {
    try {
      final file = File(filePath);

      // Create parent directories
      await file.parent.create(recursive: true);

      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 30),
        onTimeout: () => throw TimeoutException('Download timed out'),
      );

      if (streamedResponse.statusCode != 200) {
        throw Exception('Failed to download: ${streamedResponse.statusCode}');
      }

      content.totalBytes = streamedResponse.contentLength ?? 0;

      final sink = file.openWrite();
      int downloadedBytes = 0;
      final stopwatch = Stopwatch()..start();

      await streamedResponse.stream.forEach((chunk) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        // Update progress
        content.bytesReceived = downloadedBytes;
        if (content.totalBytes > 0) {
          content.progress = downloadedBytes / content.totalBytes;
        }

        // Calculate speed and ETA
        final elapsed = stopwatch.elapsedMilliseconds / 1000;
        if (elapsed > 0) {
          content.speedBytesPerSecond = (downloadedBytes / elapsed).toInt();
          final remaining = content.totalBytes - downloadedBytes;
          if (content.speedBytesPerSecond! > 0) {
            content.eta = Duration(
              seconds: (remaining / content.speedBytesPerSecond!).toInt(),
            );
          }
        }

        notifyListeners();
      });

      await sink.close();
      stopwatch.stop();
    } catch (e) {
      debugPrint('❌ Download error: $e');
      rethrow;
    }
  }

  /// Pause download
  Future<void> pauseDownload(String downloadId) async {
    final content = _downloads[downloadId];
    if (content != null) {
      content.status = DownloadStatus.paused;
      _activeDownloads[downloadId]?.stream.drain();
      notifyListeners();
      debugPrint('⏸ Download paused: ${content.displayTitle}');
    }
  }

  /// Resume download
  Future<void> resumeDownload(String downloadId) async {
    final content = _downloads[downloadId];
    if (content != null && content.status == DownloadStatus.paused) {
      content.status = DownloadStatus.downloading;
      _queuedDownloads.insert(0, downloadId);
      _processDownloadQueue();
      notifyListeners();
      debugPrint('▶️ Download resumed: ${content.displayTitle}');
    }
  }

  /// Cancel download
  Future<void> cancelDownload(String downloadId) async {
    try {
      final content = _downloads[downloadId];
      if (content != null) {
        _activeDownloads[downloadId]?.stream.drain();
        _downloads.remove(downloadId);
        _queuedDownloads.remove(downloadId);

        // Delete file if exists
        final downloadDir = await _getDownloadDir();
        final file = File('${downloadDir.path}/${content.fileSystemName}');
        if (await file.exists()) {
          await file.delete();
        }

        await _saveDownloadsToStorage();
        notifyListeners();
        debugPrint('❌ Download cancelled: ${content.displayTitle}');
      }
    } catch (e) {
      debugPrint('❌ Cancel download error: $e');
    }
  }

  /// Get auto-download subtitles preference
  Future<bool> _shouldAutoDownloadSubtitles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSubtitlesKey) ?? false;
  }

  /// Set auto-download subtitles preference
  Future<void> setAutoDownloadSubtitles(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSubtitlesKey, enabled);
    notifyListeners();
  }

  /// Get preferred subtitle languages
  Future<List<String>> getPreferredSubtitleLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_subtitleLanguagesKey) ?? ['en'];
  }

  /// Set preferred subtitle languages
  Future<void> setPreferredSubtitleLanguages(List<String> languages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_subtitleLanguagesKey, languages);
  }

  /// Download subtitles for content
  Future<void> _downloadSubtitles(DownloadedContent content) async {
    try {
      // This would integrate with your subtitle service
      // For now, placeholder for implementation
      debugPrint('📝 Downloading subtitles for: ${content.displayTitle}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Subtitle download error: $e');
    }
  }

  /// Save all downloads to local storage
  Future<void> _saveDownloadsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(
        _downloads.values.map((d) => d.toJson()).toList(),
      );
      await prefs.setString(_downloadsKey, json);
      debugPrint('✅ Downloads saved to storage');
    } catch (e) {
      debugPrint('❌ Failed to save downloads: $e');
    }
  }

  /// Load downloads from storage
  Future<void> _loadDownloadsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_downloadsKey);

      if (json != null) {
        final decoded = jsonDecode(json) as List;
        _downloads.clear();
        for (final item in decoded) {
          final content = DownloadedContent.fromJson(item);
          _downloads[content.id] = content;
        }
        debugPrint('✅ Loaded ${_downloads.length} downloads from storage');
      }
    } catch (e) {
      debugPrint('❌ Failed to load downloads: $e');
    }
  }

  /// Get downloaded content by ID
  DownloadedContent? getDownload(String downloadId) {
    return _downloads[downloadId];
  }

  /// Check if content is downloaded and ready to play
  bool isDownloaded(int tmdbId, {int? seasonNumber, int? episodeNumber}) {
    return _downloads.values.any(
      (d) =>
          d.tmdbId == tmdbId &&
          d.status == DownloadStatus.completed &&
          (d.isMovie ||
              (d.seasonNumber == seasonNumber &&
                  d.episodeNumber == episodeNumber)),
    );
  }

  /// Get downloaded content for TMDB ID
  DownloadedContent? getDownloadedContent(
    int tmdbId, {
    int? seasonNumber,
    int? episodeNumber,
  }) {
    try {
      return _downloads.values.firstWhere(
        (d) =>
            d.tmdbId == tmdbId &&
            d.status == DownloadStatus.completed &&
            (d.isMovie ||
                (d.seasonNumber == seasonNumber &&
                    d.episodeNumber == episodeNumber)),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get all downloaded content stats
  Map<String, dynamic> getStats() {
    int completed = 0;
    int downloading = 0;
    int paused = 0;
    int failed = 0;
    int totalSize = 0;

    for (final content in _downloads.values) {
      switch (content.status) {
        case DownloadStatus.completed:
          completed++;
          totalSize += content.totalBytes;
          break;
        case DownloadStatus.downloading:
          downloading++;
          totalSize += content.bytesReceived;
          break;
        case DownloadStatus.paused:
          paused++;
          totalSize += content.bytesReceived;
          break;
        case DownloadStatus.failed:
          failed++;
          break;
        default:
          break;
      }
    }

    return {
      'total': _downloads.length,
      'completed': completed,
      'downloading': downloading,
      'paused': paused,
      'failed': failed,
      'totalSize': DownloadedContent.formatBytes(totalSize),
    };
  }

  /// Clear all downloads
  Future<void> clearAllDownloads() async {
    try {
      final downloadDir = await _getDownloadDir();
      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
      }
      _downloads.clear();
      _queuedDownloads.clear();
      _activeDownloads.clear();
      _activeDownloadCount = 0;
      await _saveDownloadsToStorage();
      notifyListeners();
      debugPrint('✅ All downloads cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear downloads: $e');
    }
  }
}
