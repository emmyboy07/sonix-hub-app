import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../models/movie.dart';
import '../models/cast.dart';
import '../models/tv_show_details.dart';
import '../models/download_item.dart';
import '../providers/movies_provider.dart';
import '../services/tmdb_service.dart';
import '../services/download_service.dart';
import '../services/clipsave_service.dart';
import '../services/download_manager.dart';
import '../services/download_queue_manager.dart';
import '../services/watch_history_service.dart';
import '../services/release_reminder_service.dart';
import '../widgets/movie_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/download_progress_dialog.dart';
import 'package:sonix_hub/screens/episode_screen.dart';
import 'package:sonix_hub/screens/player/stream_resolver_screen.dart';
import 'package:sonix_hub/screens/trailer_player_screen.dart';
import '../widgets/comment_section.dart';
import '../providers/comments_provider.dart';
import '../config/genre_constants.dart';
import 'cast_screen.dart';

class DetailsScreen extends StatefulWidget {
  final Movie movie;

  const DetailsScreen({super.key, required this.movie});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  late bool _isFavorite;
  late Future<List<Cast>> _castFuture;
  late Future<List<Movie>> _similarFuture;
  late Future<List<Movie>> _recommendedFuture;
  late Future<TVShowDetails>? _tvShowDetailsFuture;
  late Future<void> _allDataFuture;
  late Future<Movie> _movieDetailsFuture;
  WatchHistoryItem? _watchHistory;
  final ReleaseReminderService _reminderService = ReleaseReminderService();
  bool _hasReminder = false;
  late Movie _currentMovie;

  @override
  void initState() {
    super.initState();
    _currentMovie = widget.movie;
    _isFavorite = context.read<MoviesProvider>().isFavourite(widget.movie.id);
    _loadWatchHistory();
    _checkReminder();

    // Auto-fetch full movie/show details
    final isTV = widget.movie.mediaType == 'tv';

    if (isTV) {
      // For TV shows, fetch complete details from API
      _tvShowDetailsFuture = TMDBService.getTVShowDetails(widget.movie.id);
      _movieDetailsFuture = _tvShowDetailsFuture!.then((tvShowDetails) {
        // Convert TVShowDetails to Movie for consistent display
        final movieFromTV = Movie(
          id: tvShowDetails.id,
          title: tvShowDetails.name,
          posterPath: tvShowDetails.posterPath ?? '',
          backdropPath: tvShowDetails.backdropPath ?? '',
          overview: tvShowDetails.overview,
          voteAverage: tvShowDetails.voteAverage,
          releaseDate: tvShowDetails.firstAirDate ?? '',
          genreIds: tvShowDetails.genreIds,
          mediaType: 'tv',
          originalLanguage: tvShowDetails.originalLanguage,
        );
        if (mounted) {
          setState(() {
            _currentMovie = movieFromTV;
          });
        }
        return movieFromTV;
      });
      _castFuture = TMDBService.getTVShowCast(widget.movie.id);
      _similarFuture = TMDBService.getSimilarTVShows(widget.movie.id);
      _recommendedFuture = TMDBService.getRecommendedTVShows(widget.movie.id);
    } else {
      // For movies, fetch complete details from API
      _movieDetailsFuture = TMDBService.getMovieDetails(widget.movie.id).then((
        movie,
      ) {
        if (mounted) {
          setState(() {
            _currentMovie = movie;
          });
        }
        return movie;
      });
      _castFuture = TMDBService.getMovieCast(widget.movie.id);
      _similarFuture = TMDBService.getSimilarMovies(widget.movie.id);
      _recommendedFuture = TMDBService.getRecommendedMovies(widget.movie.id);
      _tvShowDetailsFuture = null;
    }

    // Combine all futures - waits for all data to be fetched
    _allDataFuture = Future.wait<dynamic>([
      _movieDetailsFuture,
      _castFuture,
      _similarFuture,
      _recommendedFuture,
      if (_tvShowDetailsFuture != null) _tvShowDetailsFuture!,
    ]).then((_) {});
  }

  Future<void> _loadWatchHistory() async {
    final isTV = widget.movie.mediaType == 'tv';

    if (isTV) {
      // For TV shows, get all watch history and find the most recent episode
      final allHistory = await WatchHistoryService.getAllHistory();

      // Filter for this show's episodes
      final showHistory = allHistory
          .where(
            (item) =>
                item.movieId == widget.movie.id && item.seasonEpisode != null,
          )
          .toList();

      if (showHistory.isNotEmpty && showHistory.first.progressPercentage < 95) {
        if (mounted) {
          setState(() {
            _watchHistory =
                showHistory.first; // Most recent first due to sorting
          });
        }
      }
    } else {
      // For movies, get specific watch history
      final history = await WatchHistoryService.getHistory(
        movieId: widget.movie.id,
      );
      if (mounted && history != null && history.progressPercentage < 95) {
        setState(() {
          _watchHistory = history;
        });
      }
    }
  }

  Future<void> _checkReminder() async {
    final hasReminder = await _reminderService.hasReminder(widget.movie.id);
    if (mounted) {
      setState(() {
        _hasReminder = hasReminder;
      });
    }
  }

  Future<void> _toggleReminder() async {
    if (_hasReminder) {
      await _reminderService.removeReminder(widget.movie.id);
    } else {
      final posterUrl =
          '${AppConfig.tmdbImageBaseUrl}${widget.movie.posterPath}';
      await _reminderService.addReminder(
        ReleaseReminder(
          id: widget.movie.id,
          title: widget.movie.title,
          releaseDate: widget.movie.releaseDate,
          isMovie: widget.movie.mediaType != 'tv',
          posterUrl: posterUrl,
        ),
      );
    }
    await _checkReminder();
  }

  @override
  void didUpdateWidget(DetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload watch history if the movie changed
    if (oldWidget.movie.id != widget.movie.id) {
      _loadWatchHistory();
      _checkReminder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final movie = _currentMovie;
    final backdropUrl = '${AppConfig.tmdbImageBaseUrl}${movie.backdropPath}';
    final posterUrl = '${AppConfig.tmdbImageBaseUrl}${movie.posterPath}';
    final year = _formatReleaseDate(movie.releaseDate);

    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          // Reload watch history when returning to this screen
          _loadWatchHistory();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.darkBlack,
        body: FutureBuilder<void>(
          future: _allDataFuture,
          builder: (context, snapshot) {
            // Show loading spinner while fetching data
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryRed,
                      ),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            }

            // Show error state if any
            if (snapshot.hasError) {
              return SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppTheme.primaryRed,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading details',
                        style: TextStyle(color: AppTheme.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Show full content when all data is loaded
            return SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header section with backdrop, poster, and info
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Backdrop image
                        CachedNetworkImage(
                          imageUrl: backdropUrl,
                          width: double.infinity,
                          height: 360,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 360,
                            color: AppTheme.mediumBlack,
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 360,
                            color: AppTheme.mediumBlack,
                            child: Icon(
                              Icons.movie,
                              color: AppTheme.lightGray,
                              size: 80,
                            ),
                          ),
                          memCacheHeight: 720,
                          memCacheWidth: 1280,
                        ),
                        // Gradient overlay on backdrop
                        Container(
                          width: double.infinity,
                          height: 360,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.9),
                              ],
                            ),
                          ),
                        ),
                        // Back button
                        Positioned(
                          top: 12,
                          left: 12,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_back,
                                color: AppTheme.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        // Trailer play button
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TrailerPlayerScreen(
                                    title: widget.movie.title,
                                    movieId: widget.movie.id,
                                    mediaType: widget.movie.mediaType,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                color: AppTheme.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        // Poster + Info section positioned at bottom of backdrop
                        Positioned(
                          bottom: 20,
                          left: 16,
                          right: 16,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Overlapping Poster
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 20,
                                        offset: Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: posterUrl,
                                    width: 110,
                                    height: 165,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 110,
                                      height: 165,
                                      color: AppTheme.mediumBlack,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          width: 110,
                                          height: 165,
                                          color: AppTheme.mediumBlack,
                                          child: Icon(
                                            Icons.movie,
                                            color: AppTheme.lightGray,
                                          ),
                                        ),
                                    memCacheHeight: 330,
                                    memCacheWidth: 220,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              // Info column (title, date, duration, rating)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Title
                                    Text(
                                      movie.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppTheme.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    // Date and duration
                                    Text(
                                      '$year • 120 min',
                                      style: TextStyle(
                                        color: AppTheme.lightGray,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    // Language
                                    if (movie.originalLanguage.isNotEmpty)
                                      Text(
                                        _getLanguageName(
                                          movie.originalLanguage,
                                        ),
                                        style: TextStyle(
                                          color: AppTheme.lightGray,
                                          fontSize: 12,
                                        ),
                                      ),
                                    SizedBox(height: 8),
                                    // Rating with stars
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          color: Color(0xFFFFD700),
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          movie.voteAverage.toStringAsFixed(1),
                                          style: TextStyle(
                                            color: AppTheme.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '(150 votes)',
                                          style: TextStyle(
                                            color: AppTheme.lightGray,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    // Action buttons (Play, Download, Favorite)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Play button
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () async {
                                // Check if movie is unreleased
                                if (widget.movie.mediaType != 'tv' &&
                                    _reminderService.isUnreleased(
                                      widget.movie.releaseDate,
                                    )) {
                                  _showUnreleasedToast(widget.movie.title);
                                  return;
                                }

                                final isTV = widget.movie.mediaType == 'tv';
                                if (isTV) {
                                  // If there's watch history with an episode, resume that episode
                                  if (_watchHistory != null &&
                                      _watchHistory!.seasonEpisode != null) {
                                    final seasonEpisode =
                                        _watchHistory!.seasonEpisode!;

                                    // Parse S3:E6 format
                                    final parts = seasonEpisode.split(':');
                                    if (parts.length == 2) {
                                      final season =
                                          int.tryParse(
                                            parts[0].replaceAll('S', ''),
                                          ) ??
                                          1;
                                      final episode =
                                          int.tryParse(
                                            parts[1].replaceAll('E', ''),
                                          ) ??
                                          1;

                                      // Direct to player for this episode
                                      print(
                                        '[DetailsScreen] Opening TV SHOW RESUME: ${widget.movie.title}',
                                      );
                                      print(
                                        '[DetailsScreen] TV Show posterPath: ${widget.movie.posterPath}',
                                      );
                                      print(
                                        '[DetailsScreen] TV Show mediaType: ${widget.movie.mediaType}',
                                      );
                                      print(
                                        '[DetailsScreen] Season/Episode: $seasonEpisode',
                                      );
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => StreamResolverScreen(
                                            title:
                                                '${widget.movie.title} $seasonEpisode',
                                            embedUrl:
                                                'https://vidfast.pro/tv/${widget.movie.id}/$season/$episode',
                                            isTV: true,
                                            showId: widget.movie.id,
                                            seasonEpisode: seasonEpisode,
                                            posterPath: widget.movie.posterPath,
                                          ),
                                        ),
                                      );
                                    }
                                  } else {
                                    // No watch history, open episode screen at season 1
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (BuildContext context) {
                                        return Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      },
                                    );
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EpisodeScreen(
                                          showId: widget.movie.id,
                                          seasonNumber: 1,
                                          showTitle: widget.movie.title,
                                          posterPath: widget.movie.posterPath,
                                        ),
                                      ),
                                    ).then((_) {
                                      Navigator.pop(
                                        context,
                                      ); // Remove the spinner
                                    });
                                  }
                                } else {
                                  // Movie: open StreamResolverScreen with VidKing embed source
                                  print(
                                    '[DetailsScreen] Opening MOVIE: ${widget.movie.title}',
                                  );
                                  print(
                                    '[DetailsScreen] Movie posterPath: ${widget.movie.posterPath}',
                                  );
                                  print(
                                    '[DetailsScreen] Movie mediaType: ${widget.movie.mediaType}',
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StreamResolverScreen(
                                        title: widget.movie.title,
                                        embedUrl:
                                            'https://vidfast.pro/movie/${widget.movie.id}',
                                        isTV: false,
                                        movieId: widget.movie.id,
                                        posterPath: widget.movie.posterPath,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryRed,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.play_arrow,
                                      color: AppTheme.white,
                                      size: 26,
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _watchHistory != null
                                            ? 'Resume ${_watchHistory!.seasonEpisode ?? ''}'
                                            : 'Play',
                                        style: TextStyle(
                                          color: AppTheme.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          // Download button
                          GestureDetector(
                            onTap: () async {
                              // Check if movie is unreleased
                              if (widget.movie.mediaType != 'tv' &&
                                  _reminderService.isUnreleased(
                                    widget.movie.releaseDate,
                                  )) {
                                _showUnreleasedToast(widget.movie.title);
                                return;
                              }
                              _showDownloadOverlay(context);
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.mediumBlack,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                Icons.download,
                                color: AppTheme.white,
                                size: 20,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          // Notification reminder button (only for unreleased movies)
                          if (widget.movie.mediaType != 'tv' &&
                              _reminderService.isUnreleased(
                                widget.movie.releaseDate,
                              ))
                            GestureDetector(
                              onTap: () async {
                                await _toggleReminder();
                              },
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.mediumBlack,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(
                                  _hasReminder
                                      ? Icons.notifications_active
                                      : Icons.notifications_none,
                                  color: _hasReminder
                                      ? AppTheme.primaryRed
                                      : AppTheme.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          if (widget.movie.mediaType != 'tv' &&
                              _reminderService.isUnreleased(
                                widget.movie.releaseDate,
                              ))
                            SizedBox(width: 12),
                          // Favorite button
                          GestureDetector(
                            onTap: () async {
                              setState(() => _isFavorite = !_isFavorite);
                              if (_isFavorite) {
                                await context
                                    .read<MoviesProvider>()
                                    .addFavourite(_currentMovie);
                              } else {
                                await context
                                    .read<MoviesProvider>()
                                    .removeFavourite(widget.movie.id);
                              }
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.mediumBlack,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                _isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _isFavorite
                                    ? AppTheme.primaryRed
                                    : AppTheme.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    // Genres
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: movie.genreIds.isEmpty
                            ? [
                                Text(
                                  'No genres available',
                                  style: TextStyle(
                                    color: AppTheme.lightGray,
                                    fontSize: 13,
                                  ),
                                ),
                              ]
                            : getGenreNames(
                                movie.genreIds,
                              ).map((genre) => _buildGenreChip(genre)).toList(),
                      ),
                    ),
                    SizedBox(height: 28),
                    // Overview
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overview',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            movie.overview.isNotEmpty
                                ? movie.overview
                                : 'No overview available',
                            style: TextStyle(
                              color: AppTheme.lightGray,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 28),
                    // TV Show Seasons and Episodes (only for TV shows)
                    if (widget.movie.mediaType == 'tv')
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seasons',
                              style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 14),
                            FutureBuilder<TVShowDetails>(
                              future: _tvShowDetailsFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return SizedBox(
                                    height: 100,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppTheme.primaryRed,
                                      ),
                                    ),
                                  );
                                }

                                if (snapshot.hasError ||
                                    snapshot.data == null ||
                                    snapshot.data!.seasons.isEmpty) {
                                  return Text(
                                    'No season information available',
                                    style: TextStyle(color: AppTheme.lightGray),
                                  );
                                }

                                final tvShowDetails = snapshot.data!;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Summary info
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.mediumBlack,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Status: ${tvShowDetails.status}',
                                            style: TextStyle(
                                              color: AppTheme.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            '${tvShowDetails.numberOfSeasons} Season${tvShowDetails.numberOfSeasons != 1 ? 's' : ''} • ${tvShowDetails.numberOfEpisodes} Episode${tvShowDetails.numberOfEpisodes != 1 ? 's' : ''}',
                                            style: TextStyle(
                                              color: AppTheme.lightGray,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (tvShowDetails.lastEpisodeToAir !=
                                              null)
                                            Padding(
                                              padding: EdgeInsets.only(top: 6),
                                              child: Text(
                                                'Last Episode: ${tvShowDetails.lastEpisodeToAir}',
                                                style: TextStyle(
                                                  color: AppTheme.primaryRed,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 14),
                                    // Seasons list
                                    SizedBox(
                                      height: 220,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: tvShowDetails.seasons.length,
                                        itemBuilder: (context, index) {
                                          final season =
                                              tvShowDetails.seasons[index];
                                          final seasonPosterUrl =
                                              season.posterPath != null
                                              ? '${AppConfig.tmdbImageBaseUrl}${season.posterPath}'
                                              : null;

                                          return Padding(
                                            padding: EdgeInsets.only(right: 12),
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        EpisodeScreen(
                                                          showId:
                                                              tvShowDetails.id,
                                                          seasonNumber: season
                                                              .seasonNumber,
                                                          showTitle:
                                                              tvShowDetails
                                                                  .name,
                                                          posterPath: widget
                                                              .movie
                                                              .posterPath,
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: Container(
                                                      width: 120,
                                                      height: 170,
                                                      color:
                                                          AppTheme.mediumBlack,
                                                      child:
                                                          seasonPosterUrl !=
                                                              null
                                                          ? CachedNetworkImage(
                                                              imageUrl:
                                                                  seasonPosterUrl,
                                                              fit: BoxFit.cover,
                                                              placeholder:
                                                                  (
                                                                    context,
                                                                    url,
                                                                  ) => Container(
                                                                    color: AppTheme
                                                                        .mediumBlack,
                                                                  ),
                                                              errorWidget:
                                                                  (
                                                                    context,
                                                                    url,
                                                                    error,
                                                                  ) => Container(
                                                                    color: AppTheme
                                                                        .mediumBlack,
                                                                    child: Icon(
                                                                      Icons.tv,
                                                                      color: AppTheme
                                                                          .lightGray,
                                                                      size: 40,
                                                                    ),
                                                                  ),
                                                              memCacheHeight:
                                                                  340,
                                                              memCacheWidth:
                                                                  240,
                                                            )
                                                          : Center(
                                                              child: Icon(
                                                                Icons.tv,
                                                                color: AppTheme
                                                                    .lightGray,
                                                                size: 40,
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 8),
                                                  SizedBox(
                                                    width: 120,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          season.name,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            color:
                                                                AppTheme.white,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          '${season.episodeCount} ep${season.episodeCount != 1 ? 's' : ''}',
                                                          style: TextStyle(
                                                            color: AppTheme
                                                                .lightGray,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ],
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
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 28),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cast',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 14),
                          FutureBuilder<List<Cast>>(
                            future: _castFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return SizedBox(
                                  height: 130,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: 4,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        child: Column(
                                          children: [
                                            SkeletonLoader(
                                              width: 90,
                                              height: 90,
                                              borderRadius:
                                                  const BorderRadius.all(
                                                    Radius.circular(45),
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            SkeletonLoader(
                                              width: 90,
                                              height: 12,
                                              borderRadius:
                                                  const BorderRadius.all(
                                                    Radius.circular(4),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }

                              if (snapshot.hasError ||
                                  snapshot.data == null ||
                                  snapshot.data!.isEmpty) {
                                return SizedBox(
                                  height: 130,
                                  child: Center(
                                    child: Text(
                                      'No cast information available',
                                      style: TextStyle(
                                        color: AppTheme.lightGray,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final castList = snapshot.data!.take(4).toList();

                              return SizedBox(
                                height: 160,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: castList.length,
                                  itemBuilder: (context, index) {
                                    final castMember = castList[index];
                                    final profileUrl =
                                        castMember.profilePath != null
                                        ? '${AppConfig.tmdbImageBaseUrl}${castMember.profilePath}'
                                        : null;

                                    return Padding(
                                      padding: EdgeInsets.only(right: 12),
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CastScreen(
                                                personId: castMember.id,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 90,
                                              height: 90,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppTheme.mediumBlack,
                                                border: Border.all(
                                                  color: AppTheme.lightGray,
                                                  width: 1,
                                                ),
                                              ),
                                              child: profileUrl != null
                                                  ? ClipOval(
                                                      child: CachedNetworkImage(
                                                        imageUrl: profileUrl,
                                                        fit: BoxFit.cover,
                                                        placeholder:
                                                            (
                                                              context,
                                                              url,
                                                            ) => Icon(
                                                              Icons.person,
                                                              color: AppTheme
                                                                  .lightGray,
                                                              size: 50,
                                                            ),
                                                        errorWidget:
                                                            (
                                                              context,
                                                              url,
                                                              error,
                                                            ) => Icon(
                                                              Icons.person,
                                                              color: AppTheme
                                                                  .lightGray,
                                                              size: 50,
                                                            ),
                                                        memCacheHeight: 180,
                                                        memCacheWidth: 180,
                                                      ),
                                                    )
                                                  : Icon(
                                                      Icons.person,
                                                      color: AppTheme.lightGray,
                                                      size: 50,
                                                    ),
                                            ),
                                            SizedBox(height: 8),
                                            SizedBox(
                                              width: 90,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    castMember.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: AppTheme.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    castMember.character,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: AppTheme.lightGray,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 28),
                    // Similar Movies section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Similar',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 14),
                          FutureBuilder<List<Movie>>(
                            future: _similarFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const MovieListSkeletonLoader(
                                  itemCount: 5,
                                );
                              }

                              if (snapshot.hasError ||
                                  snapshot.data == null ||
                                  snapshot.data!.isEmpty) {
                                return SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Text(
                                      'No similar movies found',
                                      style: TextStyle(
                                        color: AppTheme.lightGray,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Limit to 5 similar movies for better performance
                              final similarMovies = snapshot.data!
                                  .take(5)
                                  .toList();

                              return SizedBox(
                                height: 230,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: similarMovies.length,
                                  itemBuilder: (context, index) {
                                    final movie = similarMovies[index];
                                    return Padding(
                                      padding: EdgeInsets.only(right: 12),
                                      child: MovieCard(
                                        posterPath: movie.posterPath,
                                        title: movie.title,
                                        rating: movie.voteAverage,
                                        onTap: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  DetailsScreen(movie: movie),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 28),
                    // Recommended Movies section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommended',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 14),
                          FutureBuilder<List<Movie>>(
                            future: _recommendedFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const MovieListSkeletonLoader(
                                  itemCount: 5,
                                );
                              }

                              if (snapshot.hasError ||
                                  snapshot.data == null ||
                                  snapshot.data!.isEmpty) {
                                return SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Text(
                                      'No recommendations available',
                                      style: TextStyle(
                                        color: AppTheme.lightGray,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Limit to 5 recommended movies for better performance
                              final recommendedMovies = snapshot.data!
                                  .take(5)
                                  .toList();

                              return SizedBox(
                                height: 230,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: recommendedMovies.length,
                                  itemBuilder: (context, index) {
                                    final movie = recommendedMovies[index];
                                    return Padding(
                                      padding: EdgeInsets.only(right: 12),
                                      child: MovieCard(
                                        posterPath: movie.posterPath,
                                        title: movie.title,
                                        rating: movie.voteAverage,
                                        onTap: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  DetailsScreen(movie: movie),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 28),
                    // Comments section - LAST SECTION
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Consumer<CommentsProvider>(
                        builder: (context, provider, _) {
                          return CommentSection(
                            tmdbId: widget.movie.id,
                            isTV: widget.movie.mediaType == 'tv',
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGenreChip(String genre) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.mediumBlack,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(genre, style: TextStyle(color: AppTheme.white, fontSize: 12)),
    );
  }

  void _showDownloadOverlay(BuildContext context) {
    final downloadService = DownloadService();
    final clipsaveService = ClipsaveService();
    downloadService.clearLogs();
    clipsaveService.clearLogs();
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
                final isTV = widget.movie.mediaType == 'tv';
                Map<String, dynamic>? result;

                if (isTV) {
                  // For TV shows, use Moviebox
                  result = await downloadService.fetchDownloadLink(
                    widget.movie.id,
                    widget.movie.title,
                    isTV: true,
                  );
                } else {
                  // For movies, try Moviebox first
                  result = await downloadService.fetchDownloadLink(
                    widget.movie.id,
                    widget.movie.title,
                    isTV: false,
                  );

                  // If Moviebox fails, fallback to Clipsave
                  if (result == null || result['success'] != true) {
                    result = await clipsaveService.fetchMovie(
                      widget.movie.id,
                      widget.movie.title,
                    );
                  }
                }

                setState(() {});

                // If successful, close and show formatted result
                if (result != null && result['success'] == true) {
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (mounted && dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    _showDownloadResultModal(context, result);
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
                              fontSize: 16,
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
  ) {
    // Handle both Clipsave and Moviebox response formats
    List<Map<String, dynamic>> qualities = [];
    List<dynamic> captions = [];
    bool isMoviebox = false;

    // Check if this is a Moviebox response (has 'downloadData' field)
    if (result['downloadData'] != null) {
      // Moviebox format
      isMoviebox = true;
      final downloadData = result['downloadData'] as Map<String, dynamic>;
      final downloads = (downloadData['data']?['downloads'] as List?) ?? [];
      captions = (downloadData['data']?['captions'] as List?) ?? [];

      // Convert downloads to qualities format
      for (final item in downloads) {
        if (item is Map<String, dynamic>) {
          qualities.add(item);
        }
      }
    } else if (result['qualities'] != null) {
      // Clipsave format
      qualities = (result['qualities'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    }

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
                                    _formatReleaseDate(result['year']),
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
                    if (qualities.isNotEmpty) ...[
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
                                crossAxisCount: qualities.length >= 3
                                    ? 3
                                    : qualities.length,
                                childAspectRatio: 1.2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                          itemCount: qualities.length,
                          itemBuilder: (context, index) {
                            final item = qualities[index];

                            // Extract data from both Clipsave and Moviebox formats
                            String quality = 'Unknown';
                            String size = 'Unknown';
                            String downloadUrl = '';

                            // Clipsave format: quality and links
                            if (item['quality'] != null) {
                              quality = item['quality'] as String;
                              final links =
                                  item['links'] as List<dynamic>? ?? [];
                              if (links.isNotEmpty) {
                                downloadUrl = links[0] as String? ?? '';
                              }
                              if (item['size'] != null) {
                                size = item['size'] as String;
                              }
                            } else {
                              // Moviebox format: resolution and url
                              final resValue = item['resolution'];
                              quality = resValue is int
                                  ? '${resValue}p'
                                  : (resValue as String? ?? 'Unknown');
                              downloadUrl = item['url'] as String? ?? '';
                              final sizeValue = item['size'];
                              if (sizeValue != null) {
                                int? sizeBytes;
                                if (sizeValue is int) {
                                  sizeBytes = sizeValue;
                                } else if (sizeValue is String) {
                                  sizeBytes = int.tryParse(sizeValue);
                                }
                                size = _formatBytes(sizeBytes);
                              }
                            }

                            return GestureDetector(
                              onTap: () {
                                if (downloadUrl.isNotEmpty) {
                                  _startMovieDownload(
                                    url: downloadUrl,
                                    resolution: quality
                                        .replaceAll('p', '')
                                        .replaceAll('480', '480')
                                        .replaceAll('720', '720'),
                                    captions: captions,
                                    movieTitle: result['title'] ?? 'Movie',
                                  );
                                  Navigator.pop(sheetContext);
                                }
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
                                      quality,
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
                    // Subtitles Section (only for Moviebox)
                    if (isMoviebox && captions.isNotEmpty) ...[
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
                    if (qualities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No downloads available',
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
                'This content is not available for download',
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

  void _startMovieDownload({
    required String url,
    required String resolution,
    required List<dynamic> captions,
    required String movieTitle,
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

    debugPrint('📥 Starting movie download: $movieTitle ($resolution)p');

    final queueManager = DownloadQueueManager();

    // Generate unique ID for download
    final downloadId = '${movieTitle}_${DateTime.now().millisecondsSinceEpoch}';

    // Build poster URL
    final movie = widget.movie;
    final posterUrl = '${AppConfig.tmdbImageBaseUrl}${movie.posterPath}';

    // Add to queue - this will show in downloads screen
    queueManager.addDownload(
      id: downloadId,
      title: movieTitle,
      videoUrl: url,
      isMovie: true,
      posterUrl: posterUrl,
      subtitles: captions.isNotEmpty
          ? List<Map<String, dynamic>>.from(captions)
          : null,
      quality: resolution,
    );

    // Show live download notification
    // Show toast that download has started
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.download, color: AppTheme.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('Download started: $movieTitle')),
          ],
        ),
        backgroundColor: AppTheme.primaryRed.withOpacity(0.8),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    // Show live download notification (same behavior as episode downloads)
    _showLiveDownloadNotification(downloadId, movieTitle, queueManager);
  }

  /// Show live download notification with updates
  void _showLiveDownloadNotification(
    String downloadId,
    String movieTitle,
    DownloadQueueManager queueManager,
  ) {
    if (!mounted) return;
    _showDownloadNotificationDialog(downloadId, movieTitle, queueManager);
  }

  /// Build a live updating download notification
  void _showDownloadNotificationDialog(
    String downloadId,
    String movieTitle,
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

  /// Show modern notification for unreleased content
  void _showUnreleasedToast(String title) {
    final countdownMsg = _reminderService.getCountdownMessage(
      widget.movie.releaseDate,
    );

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
              Container(
                width: 48,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  image: DecorationImage(
                    image: NetworkImage(
                      '${AppConfig.tmdbImageBaseUrl}${widget.movie.posterPath}',
                    ),
                    fit: BoxFit.cover,
                  ),
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
                      'Coming Soon',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
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

  /// Convert language code to language name
  String _getLanguageName(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) return 'Unknown';

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
      'th': 'Thai',
      'tr': 'Turkish',
      'pl': 'Polish',
      'nl': 'Dutch',
      'sv': 'Swedish',
      'no': 'Norwegian',
      'da': 'Danish',
      'fi': 'Finnish',
      'el': 'Greek',
      'hu': 'Hungarian',
      'cs': 'Czech',
      'ro': 'Romanian',
      'vi': 'Vietnamese',
      'id': 'Indonesian',
      'ms': 'Malay',
      'tl': 'Filipino',
      'uk': 'Ukrainian',
      'he': 'Hebrew',
      'fa': 'Persian',
    };
    return languageMap[languageCode] ?? languageCode.toUpperCase();
  }

  /// Format release date from YYYY-MM-DD to dd/mm/yyyy format
  String _formatReleaseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      return '$day/$month/$year';
    } catch (e) {
      return dateString;
    }
  }
}
