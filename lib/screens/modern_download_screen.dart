import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/sonix_header.dart';
import '../services/production_download_manager.dart';
import '../models/downloaded_content.dart';
import '../utils/page_transitions.dart';
import 'search_screen.dart';
import 'player/universal_player_screen.dart';

class ModernDownloadScreen extends StatefulWidget {
  const ModernDownloadScreen({super.key});

  @override
  State<ModernDownloadScreen> createState() => _ModernDownloadScreenState();
}

class _ModernDownloadScreenState extends State<ModernDownloadScreen> {
  late ProductionDownloadManager _downloadManager;

  @override
  void initState() {
    super.initState();
    _downloadManager = ProductionDownloadManager();
    _downloadManager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      body: Column(
        children: [
          SonixHeader(
            onSearchPressed: () {
              navigateWithTransition(context, const SearchScreen());
            },
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _downloadManager,
              builder: (context, child) {
                final downloads = _downloadManager.downloads;

                if (downloads.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: [
                    _buildStatsBar(downloads),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: downloads.length,
                        itemBuilder: (context, index) {
                          return _buildDownloadCard(downloads[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_download_outlined,
              size: 80,
              color: AppTheme.primaryRed,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Downloads Yet',
            style: TextStyle(
              color: AppTheme.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Download movies and episodes to watch offline',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.lightGray,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(List<DownloadedContent> downloads) {
    final stats = _downloadManager.getStats();

    return Container(
      color: AppTheme.darkBlack,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.check_circle_outline,
            label: 'Complete',
            value: '${stats['completed']}',
            color: Colors.green,
          ),
          _buildStatItem(
            icon: Icons.download_outlined,
            label: 'Downloading',
            value: '${stats['downloading']}',
            color: AppTheme.primaryRed,
          ),
          _buildStatItem(
            icon: Icons.storage,
            label: 'Storage',
            value: stats['totalSize'] ?? '0 B',
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: AppTheme.lightGray, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadCard(DownloadedContent content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightGray.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header with title and actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getStatusColor(content.status).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getStatusColor(content.status).withOpacity(0.3),
                    ),
                  ),
                  child: Center(child: _getStatusIcon(content.status)),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (content.quality != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryRed.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                content.quality!,
                                style: TextStyle(
                                  color: AppTheme.primaryRed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (content.subtitles.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${content.subtitles.length} subs',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Action menu
                _buildActionMenu(content),
              ],
            ),
          ),
          // Progress bar and details
          if (content.status == DownloadStatus.downloading ||
              content.status == DownloadStatus.paused)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: content.progress,
                      minHeight: 6,
                      backgroundColor: AppTheme.lightGray.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getStatusColor(content.status),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        content.progressPercentage,
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        content.sizeInfoText,
                        style: TextStyle(
                          color: AppTheme.lightGray,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Speed: ${content.speedText}',
                        style: TextStyle(
                          color: AppTheme.lightGray,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'ETA: ${content.etaText}',
                        style: TextStyle(
                          color: AppTheme.lightGray,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            )
          else if (content.status == DownloadStatus.completed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Downloaded: ${content.downloadedSizeText}',
                    style: TextStyle(color: AppTheme.lightGray, fontSize: 12),
                  ),
                  Text(
                    'Downloaded on ${_formatDate(content.completedAt)}',
                    style: TextStyle(color: AppTheme.lightGray, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionMenu(DownloadedContent content) {
    return PopupMenuButton(
      color: AppTheme.darkGray,
      itemBuilder: (context) => [
        if (content.status == DownloadStatus.completed)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.play_arrow, color: AppTheme.primaryRed, size: 18),
                const SizedBox(width: 8),
                Text('Play', style: TextStyle(color: AppTheme.white)),
              ],
            ),
            onTap: () => _playDownload(content),
          )
        else if (content.status == DownloadStatus.downloading)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.pause, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Text('Pause', style: TextStyle(color: AppTheme.white)),
              ],
            ),
            onTap: () => _downloadManager.pauseDownload(content.id),
          )
        else if (content.status == DownloadStatus.paused)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.download, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Text('Resume', style: TextStyle(color: AppTheme.white)),
              ],
            ),
            onTap: () => _downloadManager.resumeDownload(content.id),
          ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Text('Remove', style: TextStyle(color: AppTheme.white)),
            ],
          ),
          onTap: () => _downloadManager.cancelDownload(content.id),
        ),
      ],
      child: Icon(Icons.more_vert, color: AppTheme.lightGray, size: 20),
    );
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.downloading:
        return AppTheme.primaryRed;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.queued:
        return AppTheme.lightGray;
    }
  }

  Widget _getStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return Icon(Icons.check_circle, color: Colors.green, size: 20);
      case DownloadStatus.downloading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
          ),
        );
      case DownloadStatus.paused:
        return Icon(Icons.pause_circle, color: Colors.orange, size: 20);
      case DownloadStatus.failed:
        return Icon(Icons.error_circle, color: Colors.red, size: 20);
      case DownloadStatus.queued:
        return Icon(Icons.schedule, color: AppTheme.lightGray, size: 20);
    }
  }

  void _playDownload(DownloadedContent content) {
    // Navigate to player with downloaded content
    navigateWithTransition(
      context,
      UniversalPlayerScreen(
        movieId: content.tmdbId,
        mediaType: content.isMovie ? 'movie' : 'tv',
        fromDownloads: true,
        downloadedContent: content,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.month}/${date.day}/${date.year}';
  }
}
