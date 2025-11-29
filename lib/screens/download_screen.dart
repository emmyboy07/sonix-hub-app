import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../config/theme.dart';
import '../services/download_queue_manager.dart';
import '../services/download_manager.dart';
import '../models/download_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'player/universal_player_screen.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  late DownloadQueueManager _downloadManager;

  @override
  void initState() {
    super.initState();
    _downloadManager = DownloadQueueManager();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      body: Column(
        children: [
          SafeArea(
            child: Container(
              color: AppTheme.darkBlack,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Downloads',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Sync button removed as sync functionality is deprecated
                ],
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _downloadManager,
              builder: (context, child) {
                final downloads = List<DownloadItem>.from(
                  _downloadManager.downloads,
                )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (downloads.isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.darkBlack,
                          AppTheme.darkBlack.withOpacity(0.95),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryRed.withOpacity(0.2),
                                  AppTheme.primaryRed.withOpacity(0.05),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cloud_download_rounded,
                              color: AppTheme.primaryRed,
                              size: 50,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Downloads Yet',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Download movies and episodes to watch\nthem offline anytime, anywhere',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.lightGray,
                              fontSize: 14,
                              letterSpacing: 0.2,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryRed,
                                  AppTheme.primaryRed.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryRed.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'Start Downloading',
                              style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: downloads.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final download = downloads[index];
                    return _buildDownloadItem(download);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterImage(DownloadItem download) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: (download.posterUrl != null && download.posterUrl!.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: download.posterUrl!,
              width: 56,
              height: 76,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 56,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryRed.withOpacity(0.2),
                      AppTheme.darkBlack.withOpacity(0.5),
                    ],
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 56,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryRed.withOpacity(0.1),
                      AppTheme.darkBlack,
                    ],
                  ),
                ),
                child: Icon(Icons.movie, color: AppTheme.primaryRed, size: 30),
              ),
            )
          : Container(
              width: 56,
              height: 76,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryRed.withOpacity(0.1),
                    AppTheme.darkBlack,
                  ],
                ),
              ),
              child: Icon(Icons.movie, color: AppTheme.primaryRed, size: 30),
            ),
    );
  }

  Widget _buildDownloadItem(DownloadItem download) {
    final subtitleCount = download.subtitles?.length ?? 0;

    return GestureDetector(
      onTap: () {
        if (download.status == DownloadStatus.completed) {
          _playDownloadedFile(download);
        } else if (download.status == DownloadStatus.downloading ||
            download.status == DownloadStatus.paused) {
          _playDownloadingFile(download);
        }
      },
      onLongPress: () {
        // Show cancel/delete options on long press
        if (download.status == DownloadStatus.downloading ||
            download.status == DownloadStatus.paused) {
          _showCancelConfirmation(download);
        } else {
          // For completed, failed, or cancelled items, show delete
          _showDeleteOptions(download);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.mediumBlack,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getStatusColor(download.status).withOpacity(0.16),
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                _buildPosterImage(download),
                if (subtitleCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryRed,
                            AppTheme.primaryRed.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryRed.withOpacity(0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.subtitles_rounded,
                            size: 12,
                            color: AppTheme.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$subtitleCount',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              download.displayTitle,
                              style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      download.status,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _getStatusColor(
                                        download.status,
                                      ).withOpacity(0.5),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    _getStatusText(download),
                                    style: TextStyle(
                                      color: _getStatusColor(download.status),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (download.status == DownloadStatus.downloading ||
                      download.status == DownloadStatus.paused)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: download.progress,
                            minHeight: 6,
                            backgroundColor: AppTheme.darkBlack,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getStatusColor(download.status),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              download.progressPercentage,
                              style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              download.sizeInfoText,
                              style: TextStyle(
                                color: AppTheme.lightGray,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Pause/Resume icon button
            if (download.status == DownloadStatus.downloading)
              _buildIconAction(
                icon: Icons.pause_rounded,
                tooltip: 'Pause',
                onTap: () => _downloadManager.pauseDownload(download.id),
              )
            else if (download.status == DownloadStatus.paused)
              _buildIconAction(
                icon: Icons.play_arrow_rounded,
                tooltip: 'Resume',
                onTap: () => _downloadManager.resumeDownload(download.id),
              )
            else if (download.status == DownloadStatus.failed)
              _buildIconAction(
                icon: Icons.refresh_rounded,
                tooltip: 'Retry',
                onTap: () => _downloadManager.restartDownload(download.id),
              ),
          ],
        ),
      ),
    );
  }

  void _deleteWithProgress(DownloadItem download) async {
    // Show a modal with progress and a hide button; deletion continues if the modal is hidden.
    BuildContext? sheetContext;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: AppTheme.mediumBlack,
      builder: (BuildContext ctx) {
        sheetContext = ctx;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Deleting...',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.visibility_off,
                        color: AppTheme.lightGray,
                      ),
                      onPressed: () {
                        // Hide the progress sheet but keep deletion running
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // For now we show an indeterminate progress while deletion runs
                LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  'This may take a while for large downloads. You can hide this progress and continue using the app.',
                  style: TextStyle(color: AppTheme.lightGray, fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    // Perform deletion in background. Keep waiting for completion even if the sheet is hidden.
    try {
      await _downloadManager.deleteDownload(download.id);

      // Attempt to close sheet if it's still open
      try {
        if (sheetContext != null) Navigator.pop(sheetContext!);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Download deleted'),
            backgroundColor: AppTheme.primaryRed,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      try {
        if (sheetContext != null) Navigator.pop(sheetContext!);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting file: ${e.toString()}'),
            backgroundColor: AppTheme.primaryRed,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildStatusIcon(DownloadItem download) {
    IconData icon;
    Color color;

    switch (download.status) {
      case DownloadStatus.downloading:
        icon = Icons.cloud_download;
        color = AppTheme.primaryRed;
        break;
      case DownloadStatus.paused:
        icon = Icons.pause_circle;
        color = Colors.orange;
        break;
      case DownloadStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case DownloadStatus.failed:
        icon = Icons.error;
        color = AppTheme.primaryRed;
        break;
      case DownloadStatus.queued:
        icon = Icons.schedule;
        color = AppTheme.lightGray;
        break;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              (color ?? AppTheme.primaryRed).withOpacity(0.25),
              (color ?? AppTheme.primaryRed).withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (color ?? AppTheme.primaryRed).withOpacity(0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (color ?? AppTheme.primaryRed).withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? AppTheme.primaryRed, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color ?? AppTheme.primaryRed,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Icon-only circular action used for pause/resume/cancel/retry in compact UI.
  Widget _buildIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    final bg = (color ?? AppTheme.primaryRed).withOpacity(0.12);
    final border = (color ?? AppTheme.primaryRed).withOpacity(0.6);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1.0),
            ),
            child: Icon(icon, color: color ?? AppTheme.primaryRed, size: 18),
          ),
        ),
      ),
    );
  }

  String _getStatusText(DownloadItem download) {
    switch (download.status) {
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return 'Failed: ${download.errorMessage ?? 'Unknown error'}';
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued:
        return AppTheme.lightGray;
      case DownloadStatus.downloading:
        return AppTheme.primaryRed;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return AppTheme.primaryRed;
    }
  }

  void _playDownloadedFile(DownloadItem download) async {
    try {
      String? videoPath;
      final downloadManager = DownloadManager();

      if (download.isMovie) {
        final sanitizedTitle = download.title
            .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
            .replaceAll(' ', '_');

        final downloadsDir = await downloadManager.getAppDownloadDir();
        final movieDir = '${downloadsDir.path}/movies/$sanitizedTitle';
        final dir = Directory(movieDir);
        if (await dir.exists()) {
          // Prefer exact sanitized filename, fall back to any mp4 in dir
          final exact = File('${dir.path}/${sanitizedTitle}.mp4');
          if (await exact.exists()) {
            videoPath = exact.path;
          } else {
            final mp4s = dir
                .listSync(recursive: false)
                .whereType<File>()
                .where((f) => f.path.toLowerCase().endsWith('.mp4'))
                .toList(growable: false);
            if (mp4s.isNotEmpty) {
              // Prefer file containing sanitized title, else pick first
              final match = mp4s.firstWhere(
                (f) => f.path.contains(sanitizedTitle),
                orElse: () => mp4s.first,
              );
              videoPath = match.path;
            }
          }
        }
      } else {
        final sanitizedSeriesName = (download.seriesName ?? '')
            .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
            .replaceAll(' ', '_');

        final downloadsDir = await downloadManager.getAppDownloadDir();
        final episodeDirPath =
            '${downloadsDir.path}/series/$sanitizedSeriesName/season_${download.seasonNumber}/episode_${download.episodeNumber}';
        final dir = Directory(episodeDirPath);
        if (await dir.exists()) {
          final exact = File(
            '${dir.path}/episode_${download.episodeNumber}.mp4',
          );
          if (await exact.exists()) {
            videoPath = exact.path;
          } else {
            final mp4s = dir
                .listSync(recursive: false)
                .whereType<File>()
                .where((f) => f.path.toLowerCase().endsWith('.mp4'))
                .toList(growable: false);
            if (mp4s.isNotEmpty) {
              final paddedSeason = download.seasonNumber.toString().padLeft(
                2,
                '0',
              );
              final paddedEpisode = download.episodeNumber.toString().padLeft(
                2,
                '0',
              );
              final base = 'S${paddedSeason}E${paddedEpisode}';
              final match = mp4s.firstWhere(
                (f) =>
                    f.path.contains(base) ||
                    f.path.contains('episode_${download.episodeNumber}'),
                orElse: () => mp4s.first,
              );
              videoPath = match.path;
            }
          }
        }
      }

      if (videoPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Downloaded file not found'),
              backgroundColor: AppTheme.primaryRed,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Build subtitle sources from downloaded subtitles
      final List<SubtitleSource> subtitleSources = [];
      if (download.subtitles != null && download.subtitles!.isNotEmpty) {
        for (final subtitle in download.subtitles!) {
          final url = subtitle['url'] as String?;
          final language = subtitle['lanName'] ?? subtitle['lan'] ?? 'Unknown';
          final langCode = subtitle['lang'] ?? '';

          if (url != null && url.isNotEmpty) {
            // Check if subtitle file exists locally (if it was downloaded)
            final subtitleFile = File(url);
            if (await subtitleFile.exists()) {
              // Use file:// URI for local subtitle files
              subtitleSources.add(
                SubtitleSource(
                  url: 'file://${subtitleFile.path}',
                  headers: {},
                  label: language,
                  lang: langCode,
                ),
              );
              debugPrint(
                '✅ Added subtitle: $language from ${subtitleFile.path}',
              );
            }
          }
        }
      }

      debugPrint(
        '📺 Playing: ${download.displayTitle} with ${subtitleSources.length} subtitles',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UniversalPlayerScreen(
              title: download.displayTitle,
              streamUrl: 'file://$videoPath',
              headers: {},
              subtitles: subtitleSources.isNotEmpty ? subtitleSources : null,
              movieId: download.isMovie ? null : null,
              seasonEpisode: download.isMovie
                  ? null
                  : 'S${download.seasonNumber}:E${download.episodeNumber}',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error playing downloaded file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing file: ${e.toString()}'),
            backgroundColor: AppTheme.primaryRed,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _playDownloadingFile(DownloadItem download) async {
    try {
      String? videoPath;
      final downloadManager = DownloadManager();

      if (download.isMovie) {
        final sanitizedTitle = download.title
            .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
            .replaceAll(' ', '_');

        final downloadsDir = await downloadManager.getAppDownloadDir();
        final dir = Directory('${downloadsDir.path}/movies/$sanitizedTitle');
        if (await dir.exists()) {
          final exact = File('${dir.path}/${sanitizedTitle}.mp4');
          if (await exact.exists()) {
            videoPath = exact.path;
          } else {
            final mp4s = dir
                .listSync(recursive: false)
                .whereType<File>()
                .where((f) => f.path.toLowerCase().endsWith('.mp4'))
                .toList(growable: false);
            if (mp4s.isNotEmpty) {
              final match = mp4s.firstWhere(
                (f) => f.path.contains(sanitizedTitle),
                orElse: () => mp4s.first,
              );
              videoPath = match.path;
            }
          }
        }
      } else {
        final sanitizedSeriesName = (download.seriesName ?? '')
            .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
            .replaceAll(' ', '_');

        final downloadsDir = await downloadManager.getAppDownloadDir();
        final episodeDirPath =
            '${downloadsDir.path}/series/$sanitizedSeriesName/season_${download.seasonNumber}/episode_${download.episodeNumber}';
        final dir = Directory(episodeDirPath);
        if (await dir.exists()) {
          final exact = File(
            '${dir.path}/episode_${download.episodeNumber}.mp4',
          );
          if (await exact.exists()) {
            videoPath = exact.path;
          } else {
            final mp4s = dir
                .listSync(recursive: false)
                .whereType<File>()
                .where((f) => f.path.toLowerCase().endsWith('.mp4'))
                .toList(growable: false);
            if (mp4s.isNotEmpty) {
              final paddedSeason = download.seasonNumber.toString().padLeft(
                2,
                '0',
              );
              final paddedEpisode = download.episodeNumber.toString().padLeft(
                2,
                '0',
              );
              final base = 'S${paddedSeason}E${paddedEpisode}';
              final match = mp4s.firstWhere(
                (f) =>
                    f.path.contains(base) ||
                    f.path.contains('episode_${download.episodeNumber}'),
                orElse: () => mp4s.first,
              );
              videoPath = match.path;
            }
          }
        }
      }

      if (videoPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('File not ready yet. Please wait...'),
              backgroundColor: AppTheme.primaryRed,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Build subtitle sources from downloaded subtitles
      final List<SubtitleSource> subtitleSources = [];
      if (download.subtitles != null && download.subtitles!.isNotEmpty) {
        for (final subtitle in download.subtitles!) {
          final url = subtitle['url'] as String?;
          final language = subtitle['lanName'] ?? subtitle['lan'] ?? 'Unknown';
          final langCode = subtitle['lang'] ?? '';

          if (url != null && url.isNotEmpty) {
            // Check if subtitle file exists locally (if it was downloaded)
            final subtitleFile = File(url);
            if (await subtitleFile.exists()) {
              // Use file:// URI for local subtitle files
              subtitleSources.add(
                SubtitleSource(
                  url: 'file://${subtitleFile.path}',
                  headers: {},
                  label: language,
                  lang: langCode,
                ),
              );
              debugPrint(
                '✅ Added subtitle: $language from ${subtitleFile.path}',
              );
            }
          }
        }
      }

      debugPrint(
        '📺 Playing (still downloading): ${download.displayTitle} with ${subtitleSources.length} subtitles',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UniversalPlayerScreen(
              title: download.displayTitle,
              streamUrl: 'file://$videoPath',
              headers: {},
              subtitles: subtitleSources.isNotEmpty ? subtitleSources : null,
              movieId: download.isMovie ? null : null,
              seasonEpisode: download.isMovie
                  ? null
                  : 'S${download.seasonNumber}:E${download.episodeNumber}',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error playing downloading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.primaryRed,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showDeleteOptions(DownloadItem download) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.mediumBlack,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  download.status == DownloadStatus.completed
                      ? 'Download Options'
                      : 'Delete Download?',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.grey),
              // Export option - only for completed downloads
              if (download.status == DownloadStatus.completed)
                ListTile(
                  leading: Icon(
                    Icons.file_upload_rounded,
                    color: AppTheme.primaryRed,
                  ),
                  title: Text(
                    'Export',
                    style: TextStyle(color: AppTheme.primaryRed),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportDownloadToGallery(download);
                  },
                ),
              // Delete option
              ListTile(
                leading: Icon(Icons.delete, color: AppTheme.primaryRed),
                title: Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.primaryRed),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  // Use deletion flow that shows a progress sheet with a hide option
                  _deleteWithProgress(download);
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel, color: AppTheme.lightGray),
                title: Text('Cancel', style: TextStyle(color: AppTheme.white)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCancelConfirmation(DownloadItem download) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.mediumBlack,
          title: Text(
            'Cancel Download?',
            style: TextStyle(color: AppTheme.white),
          ),
          content: Text(
            'Are you sure you want to cancel this download?',
            style: TextStyle(color: AppTheme.lightGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('No', style: TextStyle(color: AppTheme.primaryRed)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _downloadManager.cancelDownload(download.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Download cancelled'),
                      backgroundColor: AppTheme.primaryRed,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Text('Yes', style: TextStyle(color: AppTheme.lightGray)),
            ),
          ],
        );
      },
    );
  }

  void deleteDownload(DownloadItem download) async {
    final queueManager = DownloadQueueManager();
    await queueManager.deleteDownload(download.id);
  }

  /// Sync downloads to DCIM/Sonix Hub with progress dialog
  /// Export a single completed download to DCIM/Sonix Hub
  Future<void> _exportDownloadToGallery(DownloadItem download) async {
    try {
      if (download.status != DownloadStatus.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Only completed downloads can be exported'),
            backgroundColor: AppTheme.primaryRed,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildExportProgressDialog(download),
        );
      }

      final downloadManager = DownloadManager();
      await downloadManager.exportDownloadToGallery(download);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${download.displayTitle} exported to DCIM/Sonix Hub',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: AppTheme.primaryRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Build export progress dialog
  Widget _buildExportProgressDialog(DownloadItem download) {
    return Dialog(
      backgroundColor: AppTheme.mediumBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.ios_share_rounded,
                  color: AppTheme.primaryRed,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Exporting to Gallery',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Copying ${download.displayTitle}...',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.lightGray, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// Sync UI and related dialog removed.
