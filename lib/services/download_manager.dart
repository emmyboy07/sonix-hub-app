import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'download_proxy_server.dart';
import '../models/download_item.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();

  factory DownloadManager() {
    return _instance;
  }

  DownloadManager._internal();

  static const String _autoDownloadSubtitlesKey = 'auto_download_subtitles';
  static const String _downloadedItemsKey = 'downloaded_items';
  static const platform = MethodChannel('com.sonixhub.app/gallery');
  static const syncChannel = MethodChannel('com.sonixhub.app/sync');
  static const syncEventChannel = EventChannel('com.sonixhub.app/sync');
  StreamController<SyncProgress>? _localSyncController;

  /// Request storage permissions
  Future<bool> requestStoragePermissions() async {
    try {
      debugPrint('📋 Requesting storage permissions...');

      // For Android 11+, request MANAGE_EXTERNAL_STORAGE
      final status = await Permission.manageExternalStorage.request();

      debugPrint('📋 Permission status: $status');

      if (status.isDenied) {
        debugPrint('❌ Storage permission denied');
        return false;
      } else if (status.isPermanentlyDenied) {
        debugPrint(
          '❌ Storage permission permanently denied, opening settings...',
        );
        openAppSettings();
        return false;
      } else if (status.isGranted) {
        debugPrint('✅ Storage permission granted');
        return true;
      } else if (status.isLimited) {
        debugPrint('❌ Storage permission limited - not enough access');
        return false;
      }

      debugPrint('❌ Storage permission unknown status');
      return false;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Get auto-download subtitles preference (default: true)
  Future<bool> getAutoDownloadSubtitles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoDownloadSubtitlesKey) ?? true;
  }

  /// Set auto-download subtitles preference
  Future<void> setAutoDownloadSubtitles(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoDownloadSubtitlesKey, enabled);
  }

  /// Get storage directory for downloads - uses Android/media folder
  /// Path: /storage/emulated/0/Android/media/com.sonixhub.app/
  Future<Directory> getAppDownloadDir() async {
    try {
      // Get the base external storage directory
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('External storage not available');
      }

      // Replace /Android/data/ with /Android/media/
      final basePath = externalDir.path;
      final mediaPath = basePath.replaceAll(
        '/Android/data/',
        '/Android/media/',
      );

      // Create downloads directory in the media folder
      final downloadDir = Directory('$mediaPath/downloads');

      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
        debugPrint('✅ Created download directory: ${downloadDir.path}');
      }

      return downloadDir;
    } catch (e) {
      debugPrint('❌ Error accessing download directory: $e');
      rethrow;
    }
  }

  /// Private method for internal use
  Future<Directory> _getAppDownloadDir() async => getAppDownloadDir();

  /// Sync downloads with DCIM/Sonix Hub folder with progress tracking
  /// Returns a stream of sync progress events
  Stream<SyncProgress> syncDownloadsWithProgress() {
    if (_localSyncController != null) {
      return _localSyncController!.stream;
    }

    return syncEventChannel.receiveBroadcastStream().map((dynamic event) {
      final map = Map<String, dynamic>.from(event as Map);
      return SyncProgress(
        progress: (map['progress'] as num).toDouble(),
        copiedFiles: map['copiedFiles'] as int,
        totalFiles: map['totalFiles'] as int,
        copiedBytes: map['copiedBytes'] as int,
        totalBytes: map['totalBytes'] as int,
        isCompleted: map['completed'] as bool? ?? false,
      );
    });
  }

  /// Start the sync process - copies files to DCIM/Sonix Hub
  Future<bool> startSync() async {
    try {
      debugPrint('📱 Starting sync to DCIM/Sonix Hub...');

      final downloadDir = await getAppDownloadDir();
      final path = downloadDir.path;

      debugPrint('📁 Syncing from: $path');

      try {
        final result = await syncChannel.invokeMethod<bool>(
          'syncWithProgress',
          {'sourcePath': path},
        );

        if (result == true) {
          debugPrint('✅ Sync initiated successfully');
          return true;
        }
      } on PlatformException catch (e) {
        debugPrint('❌ Platform exception during sync: ${e.message}');
      } on MissingPluginException catch (e) {
        debugPrint('❌ Missing plugin during sync: ${e.message}');
      }

      // If platform channel is not implemented, fall back to local Dart-based copy
      try {
        // start local sync
        _startLocalSync(path);
        return true;
      } catch (e) {
        debugPrint('❌ Local sync failed: $e');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error starting sync: $e');
      return false;
    }
  }

  void _startLocalSync(String sourcePath) {
    // create controller
    _localSyncController = StreamController<SyncProgress>();

    () async {
      try {
        final sourceDir = Directory(sourcePath);
        if (!await sourceDir.exists()) {
          _localSyncController?.add(
            SyncProgress(
              progress: 0.0,
              copiedFiles: 0,
              totalFiles: 0,
              copiedBytes: 0,
              totalBytes: 0,
              isCompleted: false,
            ),
          );
          _localSyncController?.close();
          return;
        }

        final dcimDir = Directory('/storage/emulated/0/DCIM/Sonix Hub');
        if (!await dcimDir.exists()) {
          await dcimDir.create(recursive: true);
        }

        final allFiles = sourceDir
            .listSync(recursive: true)
            .whereType<File>()
            .toList(growable: false);

        final totalBytes = allFiles.fold<int>(0, (s, f) => s + f.lengthSync());
        var copiedBytes = 0;
        var copiedFiles = 0;

        for (final file in allFiles) {
          try {
            final relative = file.path.replaceFirst(sourceDir.path, '');
            final dest = File('${dcimDir.path}$relative');
            await dest.parent.create(recursive: true);
            await file.copy(dest.path);
            copiedFiles++;
            copiedBytes += file.lengthSync();

            final progress = totalBytes > 0 ? copiedBytes / totalBytes : 0.0;
            _localSyncController?.add(
              SyncProgress(
                progress: progress,
                copiedFiles: copiedFiles,
                totalFiles: allFiles.length,
                copiedBytes: copiedBytes,
                totalBytes: totalBytes,
                isCompleted: false,
              ),
            );
          } catch (e) {
            debugPrint('⚠️ Local copy failed for ${file.path}: $e');
          }
        }

        // final event
        _localSyncController?.add(
          SyncProgress(
            progress: 1.0,
            copiedFiles: copiedFiles,
            totalFiles: allFiles.length,
            copiedBytes: copiedBytes,
            totalBytes: totalBytes,
            isCompleted: true,
          ),
        );

        // attempt to scan gallery via platform channel too
        try {
          await platform.invokeMethod<bool>('scanGallery', {
            'path': dcimDir.path,
          });
        } catch (_) {}

        await _localSyncController?.close();
        _localSyncController = null;
      } catch (e) {
        debugPrint('❌ Local sync error: $e');
        _localSyncController?.add(
          SyncProgress(
            progress: 0.0,
            copiedFiles: 0,
            totalFiles: 0,
            copiedBytes: 0,
            totalBytes: 0,
            isCompleted: false,
          ),
        );
        await _localSyncController?.close();
        _localSyncController = null;
      }
    }();
  }

  /// Export a single completed download to DCIM/Sonix Hub
  Future<bool> exportDownloadToGallery(DownloadItem download) async {
    try {
      debugPrint('📤 Exporting: ${download.displayTitle}');

      // Ensure we have storage permissions
      final hasPermission = await requestStoragePermissions();
      if (!hasPermission) {
        debugPrint('❌ Cannot export: storage permission denied');
        return false;
      }

      // Get destination directory
      final dcimDir = Directory('/storage/emulated/0/DCIM/Sonix Hub');
      if (!await dcimDir.exists()) {
        await dcimDir.create(recursive: true);
      }

      // Determine source path based on movie or episode
      Directory sourceDir;
      if (download.isMovie) {
        sourceDir = await getMovieDownloadDir(
          download.title ?? download.displayTitle,
        );
      } else {
        sourceDir = await getSeriesDownloadDir(
          download.seriesName ?? download.displayTitle,
          download.seasonNumber ?? 1,
          download.episodeNumber ?? 1,
        );
      }

      if (!await sourceDir.exists()) {
        debugPrint('❌ Source directory not found: ${sourceDir.path}');
        return false;
      }

      // Determine destination base directory:
      // - For movies: DCIM/Sonix Hub/<MovieFolder>/...
      // - For episodes: DCIM/Sonix Hub/<SeriesName>/season_<N>/episode_<M>/...
      Directory destBase;

      if (download.isMovie) {
        // Use the source folder name (movie folder) as destination folder
        final movieFolderName = sourceDir.path
            .split(Platform.pathSeparator)
            .last;
        destBase = Directory(
          '${dcimDir.path}${Platform.pathSeparator}$movieFolderName',
        );
      } else {
        // Build sanitized series folder and episode path
        final sanitizedSeriesName =
            (download.seriesName ?? download.displayTitle)
                .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
                .replaceAll(' ', '_');
        final seasonFolder = 'season_${download.seasonNumber ?? 1}';
        final episodeFolder = 'episode_${download.episodeNumber ?? 1}';

        destBase = Directory(
          '${dcimDir.path}${Platform.pathSeparator}$sanitizedSeriesName${Platform.pathSeparator}$seasonFolder${Platform.pathSeparator}$episodeFolder',
        );
      }

      if (!await destBase.exists()) {
        await destBase.create(recursive: true);
      }

      // Copy all files from sourceDir into destBase preserving relative paths
      final files = sourceDir.listSync(recursive: true);
      for (var file in files) {
        if (file is File) {
          try {
            var relativePath = file.path.substring(sourceDir.path.length);
            // Remove leading path separator if present
            if (relativePath.startsWith(Platform.pathSeparator)) {
              relativePath = relativePath.substring(1);
            }

            final destFile = File(
              '${destBase.path}${Platform.pathSeparator}$relativePath',
            );

            // Create parent directories
            await destFile.parent.create(recursive: true);

            // Copy file
            await file.copy(destFile.path);
            debugPrint('✅ Copied: ${file.path} -> ${destFile.path}');
          } catch (e) {
            debugPrint('⚠️ Failed to copy file: $e');
          }
        }
      }

      // Trigger gallery scan
      try {
        await platform.invokeMethod<bool>('scanGallery', {
          'path': dcimDir.path,
        });
      } catch (e) {
        debugPrint('⚠️ Gallery scan failed: $e');
      }

      debugPrint('✅ Export completed: ${download.displayTitle}');
      return true;
    } catch (e) {
      debugPrint('❌ Error exporting: $e');
      return false;
    }
  }

  /// Legacy method - kept for backward compatibility
  Future<bool> syncDownloadsWithGallery() async {
    try {
      debugPrint('📱 Syncing downloads with gallery...');

      final downloadDir = await getAppDownloadDir();
      final path = downloadDir.path;

      debugPrint('📁 Scanning directory: $path');

      try {
        // Call Android platform channel to trigger MediaStore scan
        final result = await platform.invokeMethod<bool>('scanGallery', {
          'path': path,
        });

        if (result == true) {
          debugPrint('✅ Gallery sync completed successfully');
          return true;
        }
      } on PlatformException catch (e) {
        debugPrint('❌ Platform exception during gallery sync: ${e.message}');
      }

      // Fallback: If platform channel fails, still consider it a success
      // as the directory exists and MediaStore will eventually scan it
      debugPrint(
        '⚠️ Platform channel unavailable, but downloads are in gallery-accessible location',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error syncing gallery: $e');
      return false;
    }
  }

  /// Get movie download directory
  Future<Directory> getMovieDownloadDir(String movieTitle) async {
    final appDir = await _getAppDownloadDir();

    // Sanitize movie title for folder name
    final sanitizedTitle = movieTitle
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(' ', '_');

    final movieDir = Directory('${appDir.path}/movies/$sanitizedTitle');

    if (!await movieDir.exists()) {
      await movieDir.create(recursive: true);
    }

    return movieDir;
  }

  /// Get series download directory
  Future<Directory> getSeriesDownloadDir(
    String seriesName,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final appDir = await _getAppDownloadDir();
    // Sanitize series name for folder
    final sanitizedSeriesName = seriesName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(' ', '_');

    final seriesDir = Directory(
      '${appDir.path}/series/$sanitizedSeriesName/season_$seasonNumber/episode_$episodeNumber',
    );

    if (!await seriesDir.exists()) {
      await seriesDir.create(recursive: true);
    }

    return seriesDir;
  }

  /// Download a file from URL using proxy with browser headers
  Future<bool> downloadFile({
    required String url,
    required String filePath,
    required Function(
      double progress,
      int bytesReceived,
      int totalBytes,
      int speedBytesPerSecond,
      Duration eta,
    )
    onProgress,
  }) async {
    try {
      // Use direct proxy download with browser headers
      return await proxyDownload(
        videoUrl: url,
        filePath: filePath,
        onProgress: onProgress,
      );
    } catch (e) {
      debugPrint('❌ Download error: $e');
      return false;
    }
  }

  /// Download movie with optional subtitles
  Future<bool> downloadMovie({
    required String movieTitle,
    required String videoUrl,
    required List<Map<String, dynamic>>? subtitles,
    String? quality,
    required Function(
      String message,
      double progress,
      int bytesReceived,
      int totalBytes,
      int speedBytesPerSecond,
      Duration eta,
    )
    onProgress,
  }) async {
    try {
      // Request permissions first
      final hasPermission = await requestStoragePermissions();
      if (!hasPermission) {
        onProgress(
          'Storage permission denied. Please enable it in settings.',
          1.0,
          0,
          0,
          0,
          Duration.zero,
        );
        debugPrint('❌ Cannot download: storage permission denied');
        return false;
      }

      onProgress(
        'Preparing download directory...',
        0.0,
        0,
        0,
        0,
        Duration.zero,
      );
      final movieDir = await getMovieDownloadDir(movieTitle);

      // Sanitize movie title for filename
      final sanitizedTitle = movieTitle
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
          .replaceAll(' ', '_');

      // Build quality label
      String? qualityLabel;
      if (quality != null && quality.isNotEmpty) {
        final digits = quality.replaceAll(RegExp(r'[^0-9]'), '');
        qualityLabel = digits.isNotEmpty ? '${digits}p' : quality;
      }

      final videoFileName = qualityLabel != null
          ? '${sanitizedTitle} (${qualityLabel}).mp4'
          : '$sanitizedTitle.mp4';
      final videoPath =
          '${movieDir.path}${Platform.pathSeparator}$videoFileName';

      debugPrint('📁 Movie download path: $videoPath');

      // Download video
      onProgress('Downloading video...', 0.1, 0, 0, 0, Duration.zero);
      final videoDownloaded = await downloadFile(
        url: videoUrl,
        filePath: videoPath,
        onProgress: (progress, bytesReceived, totalBytes, speed, eta) =>
            onProgress(
              'Downloading video...',
              0.1 + (progress * 0.7),
              bytesReceived,
              totalBytes,
              speed,
              eta,
            ),
      );

      if (!videoDownloaded) {
        onProgress('Video download failed', 1.0, 0, 0, 0, Duration.zero);
        return false;
      }

      // Download subtitles if available and enabled
      if (subtitles != null && subtitles.isNotEmpty) {
        final autoDownload = await getAutoDownloadSubtitles();
        if (autoDownload) {
          onProgress('Downloading subtitles...', 0.8, 0, 0, 0, Duration.zero);
          for (final subtitle in subtitles) {
            final url = subtitle['url'] as String?;
            final language =
                subtitle['lanName'] ?? subtitle['lan'] ?? 'unknown';

            if (url != null && url.isNotEmpty) {
              // Download to a temporary file first so we can detect format
              final tmpPath =
                  '${movieDir.path}/${sanitizedTitle}_${language.toLowerCase()}.tmp';
              final success = await downloadFile(
                url: url,
                filePath: tmpPath,
                onProgress: (_, __, ___, ____, _____) {},
              );

              if (success) {
                try {
                  final tmpFile = File(tmpPath);
                  final bytes = await tmpFile.readAsBytes();
                  final content = utf8.decode(bytes, allowMalformed: true);
                  final looksVtt =
                      content.trimLeft().toUpperCase().startsWith('WEBVTT') ||
                      RegExp(r"\d{2}:\d{2}:\d{2}\.\d{3}").hasMatch(content);
                  final finalExt = looksVtt
                      ? '.srt'
                      : '.srt'; // always save as .srt for compatibility
                  final subtitleFileName =
                      '${sanitizedTitle}_${language.toLowerCase()}$finalExt';
                  final subtitlePath = '${movieDir.path}/$subtitleFileName';

                  // Move/rename tmp file to final path
                  await tmpFile.rename(subtitlePath);
                  subtitle['url'] = subtitlePath;
                  debugPrint(
                    '✅ Subtitle saved: $subtitlePath (detected VTT: $looksVtt)',
                  );
                } catch (e) {
                  debugPrint('❌ Error handling subtitle file: $e');
                }
              }
            }
          }
          onProgress('Subtitles downloaded', 0.9, 0, 0, 0, Duration.zero);
        }
      }

      onProgress('Download completed!', 1.0, 0, 0, 0, Duration.zero);
      await _saveDownloadedItem(movieTitle, null, null, null);
      return true;
    } catch (e) {
      debugPrint('❌ Movie download error: $e');
      onProgress('Download failed: $e', 1.0, 0, 0, 0, Duration.zero);
      return false;
    }
  }

  /// Download series episode with optional subtitles
  Future<bool> downloadEpisode({
    required String seriesName,
    required int seasonNumber,
    required int episodeNumber,
    required String videoUrl,
    required List<Map<String, dynamic>>? subtitles,
    String? quality,
    required Function(
      String message,
      double progress,
      int bytesReceived,
      int totalBytes,
      int speedBytesPerSecond,
      Duration eta,
    )
    onProgress,
  }) async {
    try {
      // Request permissions first
      final hasPermission = await requestStoragePermissions();
      if (!hasPermission) {
        onProgress(
          'Storage permission denied. Please enable it in settings.',
          1.0,
          0,
          0,
          0,
          Duration.zero,
        );
        debugPrint('❌ Cannot download: storage permission denied');
        return false;
      }

      onProgress(
        'Preparing download directory...',
        0.0,
        0,
        0,
        0,
        Duration.zero,
      );
      final episodeDir = await getSeriesDownloadDir(
        seriesName,
        seasonNumber,
        episodeNumber,
      );

      // Sanitize series name for filename
      final sanitizedSeriesName = seriesName
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
          .replaceAll(' ', '_');

      String? qualityLabel;
      if (quality != null && quality.isNotEmpty) {
        final digits = quality.replaceAll(RegExp(r'[^0-9]'), '');
        qualityLabel = digits.isNotEmpty ? '${digits}p' : quality;
      }

      final paddedSeason = seasonNumber.toString().padLeft(2, '0');
      final paddedEpisode = episodeNumber.toString().padLeft(2, '0');

      final fileNameBase =
          '${sanitizedSeriesName}_S${paddedSeason}E${paddedEpisode}';
      final videoFileName = qualityLabel != null
          ? '$fileNameBase (${qualityLabel}).mp4'
          : '$fileNameBase.mp4';
      final videoPath =
          '${episodeDir.path}${Platform.pathSeparator}$videoFileName';

      debugPrint('📁 Episode download path: $videoPath');

      // Download video
      onProgress('Downloading episode...', 0.1, 0, 0, 0, Duration.zero);
      final videoDownloaded = await downloadFile(
        url: videoUrl,
        filePath: videoPath,
        onProgress: (progress, bytesReceived, totalBytes, speed, eta) =>
            onProgress(
              'Downloading episode...',
              0.1 + (progress * 0.7),
              bytesReceived,
              totalBytes,
              speed,
              eta,
            ),
      );

      if (!videoDownloaded) {
        onProgress('Episode download failed', 1.0, 0, 0, 0, Duration.zero);
        return false;
      }

      // Download subtitles if available and enabled
      if (subtitles != null && subtitles.isNotEmpty) {
        final autoDownload = await getAutoDownloadSubtitles();
        if (autoDownload) {
          onProgress('Downloading subtitles...', 0.8, 0, 0, 0, Duration.zero);
          for (final subtitle in subtitles) {
            final url = subtitle['url'] as String?;
            final language =
                subtitle['lanName'] ?? subtitle['lan'] ?? 'unknown';

            if (url != null && url.isNotEmpty) {
              // Download to temporary file then detect and save as .srt
              final tmpPath =
                  '${episodeDir.path}/episode_${episodeNumber}_${language.toLowerCase()}.tmp';
              final success = await downloadFile(
                url: url,
                filePath: tmpPath,
                onProgress: (_, __, ___, ____, _____) {},
              );

              if (success) {
                try {
                  final tmpFile = File(tmpPath);
                  final bytes = await tmpFile.readAsBytes();
                  final content = utf8.decode(bytes, allowMalformed: true);
                  final looksVtt =
                      content.trimLeft().toUpperCase().startsWith('WEBVTT') ||
                      RegExp(r"\d{2}:\d{2}:\d{2}\.\d{3}").hasMatch(content);
                  final finalExt = looksVtt ? '.srt' : '.srt';
                  final subtitleFileName =
                      'episode_${episodeNumber}_${language.toLowerCase()}$finalExt';
                  final subtitlePath = '${episodeDir.path}/$subtitleFileName';
                  await tmpFile.rename(subtitlePath);
                  subtitle['url'] = subtitlePath;
                  debugPrint(
                    '✅ Subtitle saved: $subtitlePath (detected VTT: $looksVtt)',
                  );
                } catch (e) {
                  debugPrint('❌ Error handling subtitle file: $e');
                }
              }
            }
          }
          onProgress('Subtitles downloaded', 0.9, 0, 0, 0, Duration.zero);
        }
      }

      onProgress('Download completed!', 1.0, 0, 0, 0, Duration.zero);
      await _saveDownloadedItem(seriesName, seasonNumber, episodeNumber, null);
      return true;
    } catch (e) {
      debugPrint('❌ Episode download error: $e');
      onProgress('Download failed: $e', 1.0, 0, 0, 0, Duration.zero);
      return false;
    }
  }

  /// Save downloaded item metadata
  Future<void> _saveDownloadedItem(
    String title,
    int? seasonNumber,
    int? episodeNumber,
    String? filePath,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = prefs.getStringList(_downloadedItemsKey) ?? [];

      final item = {
        'title': title,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        'downloadedAt': DateTime.now().toIso8601String(),
        'filePath': filePath,
      };

      items.add(jsonEncode(item));
      await prefs.setStringList(_downloadedItemsKey, items);
    } catch (e) {
      debugPrint('❌ Error saving download metadata: $e');
    }
  }

  /// Get list of downloaded items
  Future<List<Map<String, dynamic>>> getDownloadedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = prefs.getStringList(_downloadedItemsKey) ?? [];

      return items
          .map((item) => jsonDecode(item) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading downloaded items: $e');
      return [];
    }
  }

  /// Check if movie is already downloaded
  Future<bool> isMovieDownloaded(String movieTitle) async {
    try {
      final movieDir = await getMovieDownloadDir(movieTitle);
      final sanitizedTitle = movieTitle
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
          .replaceAll(' ', '_');
      if (!await movieDir.exists()) return false;

      final mp4Files = movieDir
          .listSync(recursive: false)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.mp4'))
          .toList(growable: false);

      if (mp4Files.isEmpty) return false;

      // Prefer files that contain the sanitized title
      final match = mp4Files.firstWhere(
        (f) => f.path.contains(sanitizedTitle),
        orElse: () => mp4Files.first,
      );
      return await match.exists();
    } catch (e) {
      return false;
    }
  }

  /// Check if episode is already downloaded
  Future<bool> isEpisodeDownloaded(
    String seriesName,
    int seasonNumber,
    int episodeNumber,
  ) async {
    try {
      final episodeDir = await getSeriesDownloadDir(
        seriesName,
        seasonNumber,
        episodeNumber,
      );
      if (!await episodeDir.exists()) return false;

      final mp4Files = episodeDir
          .listSync(recursive: false)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.mp4'))
          .toList(growable: false);

      if (mp4Files.isEmpty) return false;

      final paddedSeason = seasonNumber.toString().padLeft(2, '0');
      final paddedEpisode = episodeNumber.toString().padLeft(2, '0');
      final baseName = 'S${paddedSeason}E${paddedEpisode}';

      final match = mp4Files.firstWhere(
        (f) =>
            f.path.contains(baseName) ||
            f.path.contains('episode_$episodeNumber'),
        orElse: () => mp4Files.first,
      );
      return await match.exists();
    } catch (e) {
      return false;
    }
  }

  /// Delete downloaded movie
  Future<bool> deleteDownloadedMovie(String movieTitle) async {
    try {
      final movieDir = await getMovieDownloadDir(movieTitle);
      if (await movieDir.exists()) {
        await movieDir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting movie: $e');
      return false;
    }
  }

  /// Delete downloaded episode
  Future<bool> deleteDownloadedEpisode(
    String seriesName,
    int seasonNumber,
    int episodeNumber,
  ) async {
    try {
      final episodeDir = await getSeriesDownloadDir(
        seriesName,
        seasonNumber,
        episodeNumber,
      );
      if (await episodeDir.exists()) {
        await episodeDir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting episode: $e');
      return false;
    }
  }

  /// Get total downloaded size
  Future<int> getTotalDownloadedSize() async {
    try {
      final appDir = await _getAppDownloadDir();
      int totalSize = 0;

      if (await appDir.exists()) {
        final files = appDir.listSync(recursive: true);
        for (final file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Format bytes to readable size
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Sync progress data model
class SyncProgress {
  final double progress; // 0.0 to 1.0
  final int copiedFiles;
  final int totalFiles;
  final int copiedBytes;
  final int totalBytes;
  final bool isCompleted;

  SyncProgress({
    required this.progress,
    required this.copiedFiles,
    required this.totalFiles,
    required this.copiedBytes,
    required this.totalBytes,
    required this.isCompleted,
  });

  String get formattedProgress => '${(progress * 100).toStringAsFixed(1)}%';
  String get formattedCopiedBytes => _formatBytes(copiedBytes);
  String get formattedTotalBytes => _formatBytes(totalBytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
