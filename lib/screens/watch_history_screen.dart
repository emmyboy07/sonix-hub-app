import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../services/watch_history_service.dart';
import 'details_screen.dart';
import 'youtube_details_screen.dart';
import '../models/youtube_video.dart';
import '../models/movie.dart';
import '../utils/page_transitions.dart';

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({super.key});

  @override
  State<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> {
  late Future<List<WatchHistoryItem>> _historyFuture;
  String _sortBy = 'recent'; // recent, oldest, alphabetical, progress

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    _historyFuture = WatchHistoryService.getAllHistory();
  }

  List<WatchHistoryItem> _sortHistory(List<WatchHistoryItem> history) {
    final List<WatchHistoryItem> sorted = List.from(history);

    switch (_sortBy) {
      case 'recent':
        sorted.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
        break;
      case 'oldest':
        sorted.sort((a, b) => a.lastWatched.compareTo(b.lastWatched));
        break;
      case 'alphabetical':
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'progress':
        sorted.sort(
          (a, b) => b.progressPercentage.compareTo(a.progressPercentage),
        );
        break;
    }

    return sorted;
  }

  Future<void> _removeFromHistory(int movieId, String? seasonEpisode) async {
    await WatchHistoryService.removeFromHistory(
      movieId: movieId,
      seasonEpisode: seasonEpisode,
    );
    setState(() {
      _loadHistory();
    });
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.mediumBlack,
        title: Text(
          'Clear All History?',
          style: TextStyle(color: AppTheme.white),
        ),
        content: Text(
          'This action cannot be undone.',
          style: TextStyle(color: AppTheme.lightGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.primaryRed)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear', style: TextStyle(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await WatchHistoryService.clearHistory();

      if (mounted) {
        setState(() {
          _loadHistory();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Watch history cleared'),
            backgroundColor: AppTheme.primaryRed,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBlack,
        title: const Text('Watch History'),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            color: AppTheme.mediumBlack,
            onSelected: (value) {
              if (value == 'clear') {
                _clearAllHistory();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppTheme.primaryRed),
                    const SizedBox(width: 12),
                    Text('Clear All', style: TextStyle(color: AppTheme.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<WatchHistoryItem>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading history',
                style: TextStyle(color: AppTheme.lightGray),
              ),
            );
          }

          final history = snapshot.data ?? [];

          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: AppTheme.lightGray, size: 80),
                  const SizedBox(height: 20),
                  Text(
                    'No watch history yet',
                    style: TextStyle(
                      color: AppTheme.lightGray,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start watching to build your history',
                    style: TextStyle(color: AppTheme.lightGray, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final sortedHistory = _sortHistory(history);

          return Column(
            children: [
              // Sort options
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('Recent', 'recent'),
                      const SizedBox(width: 8),
                      _buildSortChip('Oldest', 'oldest'),
                      const SizedBox(width: 8),
                      _buildSortChip('A-Z', 'alphabetical'),
                      const SizedBox(width: 8),
                      _buildSortChip('Progress', 'progress'),
                    ],
                  ),
                ),
              ),
              // History list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: sortedHistory.length,
                  itemBuilder: (context, index) {
                    final item = sortedHistory[index];
                    return _buildHistoryCard(context, item, index);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryRed
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: AppTheme.primaryRed) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppTheme.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    WatchHistoryItem item,
    int index,
  ) {
    final progressPercent = item.progressPercentage;
    final isCompleted = progressPercent >= 95;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () {
          // Navigate to appropriate details screen based on stored source/externalId
          if (item.source != null &&
              item.source == 'youtube' &&
              item.externalId != null) {
            final v = YouTubeVideo(
              id: item.externalId!,
              title: item.title,
              channelName: '',
              channelId: '',
              thumbnailUrl: item.posterPath ?? '',
              duration: Duration.zero,
              viewCount: 0,
              uploadDate: null,
              description: '',
            );
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => YouTubeDetailsScreen(video: v)),
            );
            return;
          }

          // For TMDB items: if seasonEpisode present -> TV show, else movie
          final mediaType = item.seasonEpisode != null ? 'tv' : 'movie';
          final movie = Movie(
            id: item.movieId,
            title: item.title,
            posterPath: item.posterPath ?? '',
            overview: '',
            voteAverage: 0.0,
            mediaType: mediaType,
            releaseDate: '',
            backdropPath: '',
            genreIds: [],
          );
          navigateWithTransition(context, DetailsScreen(movie: movie));
        },
        onLongPress: () {
          _showItemOptions(context, item);
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.mediumBlack,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCompleted
                  ? Colors.green.withOpacity(0.4)
                  : Colors.transparent,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster Image
                Container(
                  width: 90,
                  height: 130,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBlack,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: item.posterPath != null && item.posterPath!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl:
                                    (item.posterPath != null &&
                                        (item.posterPath!.startsWith(
                                              'http://',
                                            ) ||
                                            item.posterPath!.startsWith(
                                              'https://',
                                            )))
                                    ? item.posterPath!
                                    : '${AppConfig.tmdbImageBaseUrl}${item.posterPath}',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppTheme.darkBlack,
                                  child: Icon(
                                    Icons.image,
                                    color: AppTheme.primaryRed.withOpacity(0.3),
                                    size: 30,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppTheme.darkBlack,
                                  child: Icon(
                                    Icons.broken_image,
                                    color: AppTheme.primaryRed,
                                    size: 30,
                                  ),
                                ),
                              ),
                              if (isCompleted)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.5),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryRed.withOpacity(0.2),
                                AppTheme.darkBlack,
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.video_library,
                            color: AppTheme.primaryRed,
                            size: 35,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with completion badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (isCompleted)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  border: Border.all(
                                    color: Colors.green,
                                    width: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Completed',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Season/Episode info
                      if (item.seasonEpisode != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.seasonEpisode!,
                          style: TextStyle(
                            color: AppTheme.primaryRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Progress section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${progressPercent.toStringAsFixed(0)}% watched',
                                style: TextStyle(
                                  color: AppTheme.primaryRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatDuration(item.position),
                                style: TextStyle(
                                  color: AppTheme.lightGray,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progressPercent / 100,
                              minHeight: 4,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isCompleted
                                    ? Colors.green
                                    : AppTheme.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      // Last watched
                      Text(
                        'Last watched: ${_formatLastWatched(item.lastWatched)}',
                        style: TextStyle(
                          color: AppTheme.lightGray,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Options button
                GestureDetector(
                  onTap: () {
                    _showItemOptions(context, item);
                  },
                  child: Icon(
                    Icons.more_vert,
                    color: AppTheme.lightGray,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatLastWatched(DateTime lastWatched) {
    final now = DateTime.now();
    final difference = now.difference(lastWatched);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    }
  }

  void _showItemOptions(BuildContext context, WatchHistoryItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.mediumBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppTheme.primaryRed),
              title: Text(
                'Remove from History',
                style: TextStyle(color: AppTheme.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _removeFromHistory(item.movieId, item.seasonEpisode);
              },
            ),
          ],
        ),
      ),
    );
  }
}
