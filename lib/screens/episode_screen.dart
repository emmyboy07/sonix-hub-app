import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../models/tv_show_details.dart';
import '../models/download_item.dart';
import '../services/tmdb_service.dart';
import '../services/download_service.dart';
import '../services/download_queue_manager.dart';
import '../services/watch_history_service.dart';
import '../services/release_reminder_service.dart';
import 'player/stream_resolver_screen.dart';

class EpisodeScreen extends StatefulWidget {
  final int showId;
  final int seasonNumber;
  final String showTitle;
  final String? posterPath; // Series poster path for history tracking

  const EpisodeScreen({
    super.key,
    required this.showId,
    required this.seasonNumber,
    required this.showTitle,
    this.posterPath,
  });

  @override
  State<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen> {
  late Future<Season> _seasonFuture;
  final Map<int, WatchHistoryItem?> _episodeHistory = {};
  final ReleaseReminderService _reminderService = ReleaseReminderService();
  final Map<int, bool> _episodeReminders = {};

  @override
  void initState() {
    super.initState();
    _seasonFuture = TMDBService.getSeason(widget.showId, widget.seasonNumber);
  }

  Future<WatchHistoryItem?> _getEpisodeHistory(int episodeNumber) async {
    if (_episodeHistory.containsKey(episodeNumber)) {
      return _episodeHistory[episodeNumber];
    }

    final seasonEpisode = 'S${widget.seasonNumber}:E$episodeNumber';
    final history = await WatchHistoryService.getHistory(
      movieId: widget.showId,
      seasonEpisode: seasonEpisode,
    );
    _episodeHistory[episodeNumber] = history;
    return history;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkBlack,
        title: Text('${widget.showTitle} - Season ${widget.seasonNumber}'),
      ),
      backgroundColor: AppTheme.darkBlack,
      body: FutureBuilder<Season>(
        future: _seasonFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRed),
            );
          }
          if (snapshot.hasError ||
              snapshot.data == null ||
              snapshot.data!.episodes == null ||
              snapshot.data!.episodes!.isEmpty) {
            return Center(
              child: Text(
                'No episodes found',
                style: TextStyle(color: AppTheme.lightGray),
              ),
            );
          }
          final episodes = snapshot.data!.episodes!;
          final seasonPosterPath = snapshot.data?.posterPath;
          return ListView.separated(
            padding: EdgeInsets.all(16),
            itemCount: episodes.length,
            separatorBuilder: (context, idx) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(
                color: AppTheme.lightGray,
                thickness: 1,
                height: 1,
              ),
            ),
            itemBuilder: (context, idx) {
              final ep = episodes[idx];
              final epImage = ep.stillPath != null && ep.stillPath!.isNotEmpty
                  ? '${AppConfig.tmdbImageBaseUrl}${ep.stillPath}'
                  : null;
              final airDate = ep.airDate ?? '';
              final seasonEpisodeFormat =
                  'S${widget.seasonNumber.toString().padLeft(2, '0')}:E${ep.episodeNumber.toString().padLeft(2, '0')}';

              return FutureBuilder<WatchHistoryItem?>(
                future: _getEpisodeHistory(ep.episodeNumber),
                builder: (context, historySnapshot) {
                  final history = historySnapshot.data;
                  final isResumeAvailable =
                      history != null && history.progressPercentage < 95;

                  return InkWell(
                    onTap: () {
                      // Check if episode is unreleased
                      if (_reminderService.isUnreleased(ep.airDate ?? '')) {
                        _showUnreleasedToast(
                          '${widget.showTitle} S${widget.seasonNumber}E${ep.episodeNumber}',
                          ep.airDate ?? '',
                        );
                        return;
                      }

                      print(
                        '[EpisodeScreen] Tapped episode: S${widget.seasonNumber}E${ep.episodeNumber}',
                      );
                      print(
                        '[EpisodeScreen] Passing posterPath: ${widget.posterPath}',
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StreamResolverScreen(
                            title:
                                '${widget.showTitle} S${widget.seasonNumber}E${ep.episodeNumber}',
                            embedUrl:
                                'https://vidfast.pro/tv/${widget.showId}/${widget.seasonNumber}/${ep.episodeNumber}',
                            isTV: true,
                            showId: widget.showId,
                            seasonEpisode: seasonEpisodeFormat,
                            posterPath: widget.posterPath,
                          ),
                        ),
                      );
                    },
                    child: Card(
                      color: AppTheme.mediumBlack,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            epImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: epImage,
                                      width: 120,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 120,
                                        height: 80,
                                        color: AppTheme.mediumBlack,
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Icon(
                                            Icons.tv,
                                            color: AppTheme.lightGray,
                                            size: 60,
                                          ),
                                      memCacheHeight: 160,
                                      memCacheWidth: 240,
                                    ),
                                  )
                                : Container(
                                    width: 120,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppTheme.mediumBlack,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.tv,
                                      color: AppTheme.lightGray,
                                      size: 60,
                                    ),
                                  ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${ep.episodeNumber}. ${ep.name}',
                                          style: TextStyle(
                                            color: AppTheme.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isResumeAvailable)
                                        Container(
                                          margin: EdgeInsets.only(left: 8),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryRed
                                                .withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'Resume ${history.progressPercentage.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              color: AppTheme.primaryRed,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    ep.overview.isNotEmpty ? ep.overview : '',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppTheme.lightGray,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Air Date: $airDate',
                                    style: TextStyle(
                                      color: AppTheme.lightGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                  // Show unreleased badge
                                  if (_reminderService.isUnreleased(
                                    ep.airDate ?? '',
                                  ))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        _reminderService.getCountdownMessage(
                                          ep.airDate ?? '',
                                        ),
                                        style: TextStyle(
                                          color: AppTheme.primaryRed,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(width: 12),
                            // Notification reminder button (only for unreleased episodes)
                            if (_reminderService.isUnreleased(ep.airDate ?? ''))
                              GestureDetector(
                                onTap: () async {
                                  await _toggleEpisodeReminder(
                                    ep.episodeNumber,
                                    '${widget.showTitle} S${widget.seasonNumber}E${ep.episodeNumber}',
                                    ep.airDate ?? '',
                                  );
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppTheme.mediumBlack,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    _episodeReminders[ep.episodeNumber] == true
                                        ? Icons.notifications_active
                                        : Icons.notifications_none,
                                    color:
                                        _episodeReminders[ep.episodeNumber] ==
                                            true
                                        ? AppTheme.primaryRed
                                        : AppTheme.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            if (_reminderService.isUnreleased(ep.airDate ?? ''))
                              SizedBox(width: 12),
                            // Download button
                            GestureDetector(
                              onTap: () {
                                // Check if episode is unreleased
                                if (_reminderService.isUnreleased(
                                  ep.airDate ?? '',
                                )) {
                                  _showUnreleasedToast(
                                    '${widget.showTitle} S${widget.seasonNumber}E${ep.episodeNumber}',
                                    ep.airDate ?? '',
                                  );
                                  return;
                                }

                                _showDownloadOverlay(
                                  context,
                                  widget.showId,
                                  widget.seasonNumber,
                                  ep.episodeNumber,
                                  '${widget.showTitle} S${widget.seasonNumber.toString().padLeft(2, '0')}E${ep.episodeNumber.toString().padLeft(2, '0')}',
                                  seasonPosterPath,
                                );
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.mediumBlack,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.download,
                                  color: AppTheme.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showDownloadOverlay(
    BuildContext context,
    int showId,
    int seasonNumber,
    int episodeNumber,
    String episodeTitle,
    String? posterPath,
  ) {
    final downloadService = DownloadService();
    downloadService.clearLogs();
    bool hasStarted = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Trigger the download only ONCE
            if (!hasStarted) {
              hasStarted = true;

              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final result = await downloadService.fetchDownloadLink(
                  showId,
                  episodeTitle,
                  seasonNumber: seasonNumber,
                  episodeNumber: episodeNumber,
                  isTV: true,
                );

                setState(() {});

                // If successful, close and show formatted result
                if (result != null && result['success'] == true) {
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (mounted && dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    _showDownloadResultModal(
                      context,
                      result,
                      episodeNumber,
                      posterPath,
                    );
                  }
                } else {
                  // Show error/unavailable message
                  if (mounted && dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    _showDownloadUnavailableToast();
                  }
                }
              });
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Center(
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.mediumBlack,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 20,
                      ),
                      width: 220,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryRed,
                            ),
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Fetching Downloads...',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.mediumBlack,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: AppTheme.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDownloadResultModal(
    BuildContext context,
    Map<String, dynamic> result,
    int actualEpisodeNumber,
    String? seasonPosterPath,
  ) {
    final downloadData = result['downloadData'] as Map<String, dynamic>?;
    final downloads = (downloadData?['data']?['downloads'] as List?) ?? [];
    final captions = (downloadData?['data']?['captions'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.mediumBlack,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Indicator
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.lightGray.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  result['title'] ?? 'Download',
                                  style: TextStyle(
                                    color: AppTheme.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (result['year'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryRed.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${result['year']}',
                                    style: TextStyle(
                                      color: AppTheme.primaryRed,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.grey),
                    // Quality Section
                    if (downloads.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Available Quality',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: downloads.length >= 3
                                    ? 3
                                    : downloads.length,
                                childAspectRatio: 1.2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                          itemCount: downloads.length,
                          itemBuilder: (context, index) {
                            final item =
                                downloads[index] as Map<String, dynamic>;
                            final resolution = item['resolution'] ?? 'Unknown';

                            // Handle size as either int or string
                            int? sizeBytes;
                            final sizeValue = item['size'];
                            if (sizeValue is int) {
                              sizeBytes = sizeValue;
                            } else if (sizeValue is String) {
                              sizeBytes = int.tryParse(sizeValue);
                            }
                            final size = _formatBytes(sizeBytes);

                            return GestureDetector(
                              onTap: () {
                                // Start episode download with all new features
                                // Generate a poster URL from TMDB with actual posterPath
                                final posterUrl =
                                    seasonPosterPath != null &&
                                        seasonPosterPath.isNotEmpty
                                    ? 'https://image.tmdb.org/t/p/w500$seasonPosterPath'
                                    : null;
                                _startEpisodeDownload(
                                  url: item['url'] as String? ?? '',
                                  resolution: resolution.toString(),
                                  captions: captions,
                                  episodeTitle:
                                      '${widget.showTitle} S${widget.seasonNumber}E${actualEpisodeNumber.toString().padLeft(2, '0')}',
                                  seasonNumber: widget.seasonNumber,
                                  episodeNumber: actualEpisodeNumber,
                                  posterUrl: posterUrl,
                                );
                                Navigator.pop(sheetContext);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.darkBlack,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.primaryRed.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${resolution}p',
                                      style: TextStyle(
                                        color: AppTheme.primaryRed,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Text(
                                        size,
                                        style: TextStyle(
                                          color: AppTheme.lightGray,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    // Subtitles Section
                    if (captions.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Available Subtitles',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: captions.length >= 3
                                    ? 3
                                    : captions.length,
                                childAspectRatio: 1.2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                          itemCount: captions.length,
                          itemBuilder: (context, index) {
                            final item =
                                captions[index] as Map<String, dynamic>;
                            final language =
                                item['lanName'] ?? item['lan'] ?? 'Unknown';

                            // Handle subtitle size as either int or string
                            int? sizeBytes;
                            final sizeValue = item['size'];
                            if (sizeValue is int) {
                              sizeBytes = sizeValue;
                            } else if (sizeValue is String) {
                              sizeBytes = int.tryParse(sizeValue);
                            }
                            final size = _formatBytes(sizeBytes);

                            return GestureDetector(
                              onTap: () {
                                // Handle subtitle selection
                                Navigator.pop(sheetContext);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.darkBlack,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.primaryRed.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Text(
                                        language,
                                        style: TextStyle(
                                          color: AppTheme.primaryRed,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      size,
                                      style: TextStyle(
                                        color: AppTheme.lightGray,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (downloads.isEmpty && captions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No downloads or subtitles available',
                          style: TextStyle(color: AppTheme.lightGray),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return 'Unknown';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _showDownloadUnavailableToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This episode is not available for download',
                style: TextStyle(color: AppTheme.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryRed.withOpacity(0.8),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _startEpisodeDownload({
    required String url,
    required String resolution,
    required List<dynamic> captions,
    required String episodeTitle,
    required int seasonNumber,
    required int episodeNumber,
    String? posterUrl,
  }) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download link not available'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }

    debugPrint('📥 Starting episode download: $episodeTitle ($resolution)p');

    final queueManager = DownloadQueueManager();

    // Generate unique ID for download
    final downloadId =
        '${episodeTitle}_${DateTime.now().millisecondsSinceEpoch}';

    // Show toast that download has started (BEFORE adding to queue)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.download, color: AppTheme.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('Download started: $episodeTitle')),
          ],
        ),
        backgroundColor: AppTheme.primaryRed.withOpacity(0.8),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    // Add to queue - this will start the download and show notifications
    queueManager.addDownload(
      id: downloadId,
      title: episodeTitle,
      videoUrl: url,
      isMovie: false,
      posterUrl: posterUrl,
      seriesName: widget.showTitle,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      subtitles: captions.isNotEmpty
          ? List<Map<String, dynamic>>.from(captions)
          : null,
      quality: resolution,
    );

    debugPrint('✅ Episode download queued: $episodeTitle with ID: $downloadId');
  }

  /// Show live download notification with updates
  void _showLiveDownloadNotification(
    String downloadId,
    String episodeTitle,
    DownloadQueueManager queueManager,
  ) {
    if (!mounted) return;
    _showDownloadNotificationDialog(downloadId, episodeTitle, queueManager);
  }

  /// Build a live updating download notification
  void _showDownloadNotificationDialog(
    String downloadId,
    String episodeTitle,
    DownloadQueueManager queueManager,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext notificationContext) {
        return ListenableBuilder(
          listenable: queueManager,
          builder: (context, _) {
            final download = queueManager.getDownload(downloadId);

            if (download == null) {
              return SizedBox.shrink();
            }

            // Close when completed
            if (download.status == DownloadStatus.completed ||
                download.status == DownloadStatus.failed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (notificationContext.mounted) {
                  Navigator.pop(notificationContext);
                }
              });
            }

            return Dialog(
              backgroundColor: AppTheme.mediumBlack,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'Downloading',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: download.progress,
                        minHeight: 8,
                        backgroundColor: AppTheme.darkBlack,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          download.progressPercentage,
                          style: TextStyle(
                            color: AppTheme.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          download.sizeInfoText,
                          style: TextStyle(
                            color: AppTheme.lightGray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Speed and ETA row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.speed,
                              size: 16,
                              color: AppTheme.lightGray,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              download.speedText,
                              style: TextStyle(
                                color: AppTheme.lightGray,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: AppTheme.lightGray,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ETA: ${download.etaText}',
                              style: TextStyle(
                                color: AppTheme.lightGray,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Show modern notification for unreleased episodes
  void _showUnreleasedToast(String episodeTitle, String airDate) {
    final countdownMsg = _reminderService.getCountdownMessage(airDate);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryRed.withOpacity(0.95),
                AppTheme.primaryRed.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Poster thumbnail
              if (widget.posterPath != null)
                Container(
                  width: 48,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    image: DecorationImage(
                      image: NetworkImage(
                        '${AppConfig.tmdbImageBaseUrl}${widget.posterPath}',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 48,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: AppTheme.mediumBlack,
                  ),
                  child: Icon(
                    Icons.tv_rounded,
                    color: AppTheme.lightGray,
                    size: 24,
                  ),
                ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Episode Coming Soon',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      episodeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      countdownMsg,
                      style: TextStyle(
                        color: AppTheme.white.withOpacity(0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Icon
              Icon(
                Icons.access_time_rounded,
                color: AppTheme.white.withOpacity(0.7),
                size: 18,
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
      ),
    );
  }

  /// Toggle reminder for a specific episode
  Future<void> _toggleEpisodeReminder(
    int episodeNumber,
    String episodeTitle,
    String airDate,
  ) async {
    final reminderId = '${widget.showId}_${widget.seasonNumber}_$episodeNumber'
        .hashCode
        .abs();

    final hasReminder = _episodeReminders[episodeNumber] ?? false;

    if (hasReminder) {
      await _reminderService.removeReminder(reminderId);
      _episodeReminders[episodeNumber] = false;
    } else {
      if (airDate.isNotEmpty) {
        final posterUrl = widget.posterPath != null
            ? '${AppConfig.tmdbImageBaseUrl}${widget.posterPath}'
            : null;

        await _reminderService.addReminder(
          ReleaseReminder(
            id: reminderId,
            title: episodeTitle,
            releaseDate: airDate,
            isMovie: false,
            seasonEpisode: 'S${widget.seasonNumber}:E$episodeNumber',
            posterUrl: posterUrl,
          ),
        );
        _episodeReminders[episodeNumber] = true;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }
}
