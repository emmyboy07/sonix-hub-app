import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/download_item.dart';
import 'download_manager.dart';
import 'notification_service.dart';

class DownloadQueueManager extends ChangeNotifier {
  static final DownloadQueueManager _instance =
      DownloadQueueManager._internal();

  factory DownloadQueueManager() {
    return _instance;
  }

  DownloadQueueManager._internal() {
    _loadDownloadsFromPrefs();
  }

  static const String _downloadsStorageKey = 'sonix_downloads';
  static const int _maxConcurrentDownloads = 3; // Allow 3 concurrent downloads
  final List<DownloadItem> _downloads = [];
  final DownloadManager _downloadManager = DownloadManager();
  final Map<String, Future<bool>> _downloadTasks =
      {}; // Track active download tasks
  final Map<String, bool> _cancelTokens = {}; // Track cancellation requests

  List<DownloadItem> get downloads => _downloads;

  /// Load downloads from SharedPreferences
  Future<void> _loadDownloadsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadsJson = prefs.getStringList(_downloadsStorageKey) ?? [];
      _downloads.clear();

      for (final json in downloadsJson) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          String? loadedQuality = map['quality'] as String?;
          if (loadedQuality != null && loadedQuality.isNotEmpty) {
            final digits = loadedQuality.replaceAll(RegExp(r'[^0-9]'), '');
            if (digits.isNotEmpty) {
              loadedQuality = '${digits}p';
            } else if (!loadedQuality.toLowerCase().endsWith('p')) {
              // leave as-is if it already contains non-digit quality label
              loadedQuality = loadedQuality;
            }
          }

          final download = DownloadItem(
            id: map['id'] as String,
            title: map['title'] as String,
            videoUrl: map['videoUrl'] as String,
            quality: loadedQuality,
            isMovie: map['isMovie'] as bool,
            posterUrl: map['posterUrl'] as String?,
            seriesName: map['seriesName'] as String?,
            seasonNumber: map['seasonNumber'] as int?,
            episodeNumber: map['episodeNumber'] as int?,
            subtitles: (map['subtitles'] as List?)
                ?.cast<Map<String, dynamic>>(),
          );
          // Restore the status and progress from saved data
          download.status = DownloadStatus.values.firstWhere(
            (e) => e.toString() == map['status'],
            orElse: () => DownloadStatus.queued,
          );
          download.progress = (map['progress'] as num?)?.toDouble() ?? 0.0;
          download.bytesReceived = map['bytesReceived'] as int? ?? 0;
          download.totalBytes = map['totalBytes'] as int? ?? 0;
          download.speedBytesPerSecond = map['speedBytesPerSecond'] as int?;

          if (map['completedAt'] != null) {
            download.completedAt = DateTime.parse(map['completedAt'] as String);
          }
          if (map['createdAt'] != null) {
            download.createdAt = DateTime.parse(map['createdAt'] as String);
          }
          download.errorMessage = map['errorMessage'] as String?;

          _downloads.add(download);
        } catch (e) {
          debugPrint('❌ Error parsing download: $e');
        }
      }

      notifyListeners();
      debugPrint('✅ Loaded ${_downloads.length} downloads from storage');
    } catch (e) {
      debugPrint('❌ Error loading downloads: $e');
    }
  }

  /// Save downloads to SharedPreferences
  Future<void> _saveDownloadsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadsJson = _downloads
          .map(
            (d) => jsonEncode({
              'id': d.id,
              'title': d.title,
              'videoUrl': d.videoUrl,
              'quality': d.quality,
              'isMovie': d.isMovie,
              'posterUrl': d.posterUrl,
              'seriesName': d.seriesName,
              'seasonNumber': d.seasonNumber,
              'episodeNumber': d.episodeNumber,
              'subtitles': d.subtitles,
              'status': d.status.toString(),
              'progress': d.progress,
              'bytesReceived': d.bytesReceived,
              'totalBytes': d.totalBytes,
              'speedBytesPerSecond': d.speedBytesPerSecond,
              'errorMessage': d.errorMessage,
              'completedAt': d.completedAt?.toIso8601String(),
              'createdAt': d.createdAt.toIso8601String(),
            }),
          )
          .toList();

      await prefs.setStringList(_downloadsStorageKey, downloadsJson);
      debugPrint('✅ Saved ${_downloads.length} downloads to storage');
    } catch (e) {
      debugPrint('❌ Error saving downloads: $e');
    }
  }

  /// Add a new download to the queue
  void addDownload({
    required String id,
    required String title,
    required String videoUrl,
    required bool isMovie,
    String? posterUrl,
    String? seriesName,
    int? seasonNumber,
    int? episodeNumber,
    List<Map<String, dynamic>>? subtitles,
    String? quality,
  }) {
    // Normalize quality to include 'p' when it's numeric (e.g. '720' -> '720p')
    String? normalizedQuality = quality;
    if (normalizedQuality != null && normalizedQuality.isNotEmpty) {
      final digits = normalizedQuality.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        normalizedQuality = '${digits}p';
      } else if (!normalizedQuality.toLowerCase().endsWith('p')) {
        normalizedQuality = normalizedQuality;
      }
    }

    final download = DownloadItem(
      id: id,
      title: title,
      videoUrl: videoUrl,
      quality: normalizedQuality,
      isMovie: isMovie,
      posterUrl: posterUrl,
      seriesName: seriesName,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      subtitles: subtitles,
    );

    _downloads.add(download);
    _saveDownloadsToPrefs(); // Persist immediately
    notifyListeners();

    // Start downloads if we have capacity
    _processDownloadQueue();
  }

  /// Process the download queue - start up to 3 concurrent downloads
  void _processDownloadQueue() {
    // Count currently downloading
    final downloadingCount = _downloads
        .where((d) => d.status == DownloadStatus.downloading)
        .length;

    debugPrint(
      '📊 Download queue: $downloadingCount/$_maxConcurrentDownloads active',
    );

    // If we have capacity, start queued downloads
    if (downloadingCount < _maxConcurrentDownloads) {
      try {
        final queuedDownloads = _downloads
            .where((d) => d.status == DownloadStatus.queued)
            .toList();

        // Start as many as we can fit
        final slotsAvailable = _maxConcurrentDownloads - downloadingCount;
        for (int i = 0; i < queuedDownloads.length && i < slotsAvailable; i++) {
          _startDownload(queuedDownloads[i]);
        }
      } catch (e) {
        debugPrint('Error processing download queue: $e');
      }
    }
  }

  /// Start downloading the next queued item
  void _startNextDownload() {
    // This is now called _processDownloadQueue but kept for compatibility
    _processDownloadQueue();
  }

  /// Start a specific download
  Future<void> _startDownload(DownloadItem download) async {
    try {
      download.status = DownloadStatus.downloading;
      _cancelTokens[download.id] =
          false; // Initialize cancel token as not cancelled
      notifyListeners();

      // Check if auto-download subtitles is enabled (default: true)
      final autoDownloadSubtitles = await _downloadManager
          .getAutoDownloadSubtitles();

      // If no subtitles provided but auto-download is enabled, this will be handled during download
      // If subtitles are provided and auto-download enabled, they will be downloaded
      if (autoDownloadSubtitles &&
          (download.subtitles == null || download.subtitles!.isEmpty)) {
        debugPrint(
          '✅ Auto-download subtitles is enabled but no subtitles were provided',
        );
      }

      // Show notification that download started (include poster if available)
      final notificationService = NotificationService();
      await notificationService.showDownloadStarted(
        download.displayTitle,
        posterUrl: download.posterUrl,
      );

      if (download.isMovie) {
        final task = _downloadManager.downloadMovie(
          movieTitle: download.title,
          videoUrl: download.videoUrl,
          subtitles: download.subtitles,
          quality: download.quality,
          onProgress:
              (message, progress, bytesReceived, totalBytes, speed, eta) {
                // Skip updates if paused or not downloading
                if (_cancelTokens[download.id] == true ||
                    download.status != DownloadStatus.downloading) {
                  return;
                }
                download.progress = progress;
                download.bytesReceived = bytesReceived;
                download.totalBytes = totalBytes;
                download.speedBytesPerSecond = speed;
                download.eta = eta;
                notifyListeners();
                // Update live progress notification (include poster)
                notificationService.showDownloadProgress(
                  download.displayTitle,
                  bytesReceived,
                  totalBytes,
                  progress * 100,
                  posterUrl: download.posterUrl,
                );
              },
        );
        _downloadTasks[download.id] = task;
        await task;
      } else {
        final task = _downloadManager.downloadEpisode(
          seriesName: download.seriesName!,
          seasonNumber: download.seasonNumber!,
          episodeNumber: download.episodeNumber!,
          videoUrl: download.videoUrl,
          subtitles: download.subtitles,
          quality: download.quality,
          onProgress:
              (message, progress, bytesReceived, totalBytes, speed, eta) {
                // Skip updates if paused or not downloading
                if (_cancelTokens[download.id] == true ||
                    download.status != DownloadStatus.downloading) {
                  return;
                }
                download.progress = progress;
                download.bytesReceived = bytesReceived;
                download.totalBytes = totalBytes;
                download.speedBytesPerSecond = speed;
                download.eta = eta;
                notifyListeners();
                // Update live progress notification (include poster)
                notificationService.showDownloadProgress(
                  download.displayTitle,
                  bytesReceived,
                  totalBytes,
                  progress * 100,
                  posterUrl: download.posterUrl,
                );
              },
        );
        _downloadTasks[download.id] = task;
        await task;
      }

      // Only mark as completed if not paused/cancelled
      if (_cancelTokens[download.id] != true &&
          download.status == DownloadStatus.downloading) {
        download.status = DownloadStatus.completed;
        download.completedAt = DateTime.now();
        notifyListeners();
        // Persist completed state so it survives app restarts
        _saveDownloadsToPrefs();
        // Show completion notification (include poster)
        final notificationService = NotificationService();
        await notificationService.showDownloadComplete(
          download.displayTitle,
          posterUrl: download.posterUrl,
        );

        _downloadTasks.remove(download.id);
        _cancelTokens.remove(download.id);
        _startNextDownload();
      } else if (download.status == DownloadStatus.paused) {
        // Download was paused - don't mark as completed, just clean up task
        _downloadTasks.remove(download.id);
        debugPrint('⏸️ Download remains paused: ${download.id}');
      }
    } catch (e) {
      if (download.status != DownloadStatus.paused) {
        download.status = DownloadStatus.failed;
        download.errorMessage = e.toString();
        notifyListeners();
        // Persist failed state
        _saveDownloadsToPrefs();
        // Show failure notification (include poster)
        final notificationService = NotificationService();
        await notificationService.showDownloadFailed(
          download.displayTitle,
          e.toString(),
          posterUrl: download.posterUrl,
        );

        _downloadTasks.remove(download.id);
        _cancelTokens.remove(download.id);
        _startNextDownload();
      } else {
        // If paused when error occurs, just log and keep paused state
        _downloadTasks.remove(download.id);
        debugPrint(
          '⏸️ Download remains paused (error occurred): ${download.id}',
        );
      }
    }
  }

  /// Pause a download
  void pauseDownload(String id) {
    try {
      final download = _downloads.firstWhere((d) => d.id == id);
      if (download.status == DownloadStatus.downloading) {
        download.status = DownloadStatus.paused;
        _cancelTokens[id] = true; // Signal pause
        notifyListeners();
        _saveDownloadsToPrefs(); // Persist pause state
        debugPrint('⏸️ Download paused: $id');
      }
    } catch (e) {
      debugPrint('Download not found: $id');
    }
  }

  /// Resume a paused download
  void resumeDownload(String id) {
    try {
      final download = _downloads.firstWhere((d) => d.id == id);
      if (download.status == DownloadStatus.paused) {
        // Resume from paused state - clear the pause token to let callback continue
        _cancelTokens[id] = false;
        download.status = DownloadStatus.downloading;
        notifyListeners();
        // Persist resumed state
        _saveDownloadsToPrefs();
        debugPrint('▶️ Download resumed: $id');
      }
    } catch (e) {
      debugPrint('Download not found: $id');
    }
  }

  /// Cancel a download
  Future<void> cancelDownload(String id) async {
    try {
      final download = _downloads.firstWhere((d) => d.id == id);
      // Mark as cancelled instead of removing
      download.status = DownloadStatus.failed;
      download.errorMessage = 'Cancelled by user';
      _downloadTasks.remove(id);
      _cancelTokens[id] = true; // Signal cancellation
      notifyListeners();
      // Persist cancellation state
      _saveDownloadsToPrefs();

      // Process the queue for remaining downloads
      debugPrint('❌ Download cancelled: $id');
      _processDownloadQueue();
    } catch (e) {
      debugPrint('Download not found: $id');
    }
  }

  /// Delete any download (completed, failed, or cancelled)
  Future<bool> deleteDownload(String id) async {
    try {
      final download = _downloads.firstWhere((d) => d.id == id);
      try {
        // Delete the downloaded file if it exists
        if (download.isMovie) {
          await _downloadManager.deleteDownloadedMovie(download.title);
        } else {
          await _downloadManager.deleteDownloadedEpisode(
            download.seriesName!,
            download.seasonNumber!,
            download.episodeNumber!,
          );
        }
      } catch (e) {
        debugPrint('⚠️ File deletion error (may already be deleted): $e');
        // Continue with removing from list even if file deletion fails
      }

      // Remove from downloads list and persist
      _downloads.removeWhere((d) => d.id == id);
      notifyListeners();
      // Persist deletion so it does not reappear after restart
      _saveDownloadsToPrefs();
      debugPrint('✅ Download removed from list: $id');
      return true;
    } catch (e) {
      debugPrint('Download not found: $id');
      return false;
    }
  }

  /// Restart a failed/cancelled download
  void restartDownload(String id) {
    try {
      final download = _downloads.firstWhere((d) => d.id == id);
      // Reset progress for a fresh start
      download.progress = 0.0;
      download.bytesReceived = 0;
      download.totalBytes = 0;
      download.speedBytesPerSecond = null;
      download.errorMessage = null;
      download.status = DownloadStatus.queued;
      _cancelTokens[id] = false;
      notifyListeners();
      _saveDownloadsToPrefs();
      debugPrint('🔄 Download restarted: $id');

      // Process queue to start this download
      _processDownloadQueue();
    } catch (e) {
      debugPrint('Download not found: $id');
    }
  }

  /// Get download by ID
  DownloadItem? getDownload(String id) {
    try {
      return _downloads.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Clear all completed downloads
  void clearCompleted() {
    _downloads.removeWhere((d) => d.status == DownloadStatus.completed);
    notifyListeners();
  }
}
