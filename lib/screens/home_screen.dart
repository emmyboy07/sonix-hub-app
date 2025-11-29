import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../models/movie.dart';
import '../providers/movies_provider.dart';
import '../widgets/sonix_header.dart';
import '../widgets/movie_card.dart';
import '../widgets/skeleton_loader.dart';
import '../utils/page_transitions.dart';
import '../services/tmdb_service.dart';
import 'details_screen.dart';
import 'search_screen.dart';
import 'filter_screen.dart';
import '../services/youtube_service.dart';
import '../models/youtube_video.dart';
import 'youtube_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _heroPageController;
  int _currentHeroIndex = 0;
  late Timer _heroTimer;
  int _heroMovieCount = 5; // Track actual hero movie count

  // Nollywood (YouTube) section
  late Future<List<YouTubeVideo>> _nollywoodFuture;

  // Cached futures to prevent rebuilds
  late Future<List<Movie>> _actionFuture;
  late Future<List<Movie>> _comedyFuture;
  late Future<List<Movie>> _horrorFuture;
  late Future<List<Movie>> _romanceFuture;
  late Future<List<Movie>> _sciFiFuture;
  late Future<List<Movie>> _thrillerFuture;

  @override
  void initState() {
    super.initState();
    _heroPageController = PageController();
    _loadData();
    _startHeroAutoScroll();
    // Initialize cached futures for genre sections (prevent rebuilds)
    _actionFuture = TMDBService.getGenreMoviesAndShows(28);
    _comedyFuture = TMDBService.getGenreMoviesAndShows(35);
    _horrorFuture = TMDBService.getGenreMoviesAndShows(27);
    _romanceFuture = TMDBService.getGenreMoviesAndShows(10749);
    _sciFiFuture = TMDBService.getGenreMoviesAndShows(878);
    _thrillerFuture = TMDBService.getGenreMoviesAndShows(53);
    // Fetch Nollywood videos via YouTube
    _nollywoodFuture = YouTubeService().searchVideos('nollywood movies');
  }

  void _startHeroAutoScroll() {
    _heroTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_heroPageController.hasClients && _heroMovieCount > 0) {
        final nextPage = _currentHeroIndex + 1;
        _heroPageController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _loadData() {
    Future.microtask(() {
      context.read<MoviesProvider>().loadAllMovies();
    });
  }

  @override
  void dispose() {
    _heroTimer.cancel();
    _heroPageController.dispose();
    super.dispose();
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
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildHeroSection(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Trending This Week', showFilter: true),
                  _buildMovieHorizontalList('trending'),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Popular'),
                  _buildMovieHorizontalList('popular'),
                  const SizedBox(height: 32),
                  // Nollywood section (above genres)
                  _buildSectionTitle('Nollywood Movies'),
                  _buildNollywoodSection(),
                  const SizedBox(height: 32),
                  // Genre Sections
                  _buildSectionTitle('Top Action'),
                  _buildActionSection(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Top Comedy'),
                  _buildComedySection(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Top Horror'),
                  _buildHorrorSection(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Romance'),
                  _buildRomanceSection(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Sci-Fi'),
                  _buildSciFiSection(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Thriller'),
                  _buildThrillerSection(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Top Rated'),
                  _buildMovieHorizontalList('topRated'),
                  const SizedBox(height: 32),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNollywoodSection() {
    return FutureBuilder<List<YouTubeVideo>>(
      future: _nollywoodFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRed),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const SizedBox.shrink();
        final videos = snapshot.data!.take(10).toList();
        return SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final v = videos[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 140,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => YouTubeDetailsScreen(video: v),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            v.thumbnailUrl,
                            width: 140,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 140,
                              height: 90,
                              color: AppTheme.mediumBlack,
                              child: Icon(
                                Icons.play_circle_outline,
                                color: AppTheme.lightGray,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          v.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          v.channelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeroSection() {
    return Consumer<MoviesProvider>(
      builder: (context, provider, child) {
        var movies = provider.trendingMovies;

        if (movies.isEmpty) {
          return const HeroSkeletonLoader();
        }

        // Limit hero to first 5 items for performance
        movies = movies.take(5).toList();

        // Update the actual hero movie count
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_heroMovieCount != movies.length) {
            setState(() {
              _heroMovieCount = movies.length;
            });
          }
        });

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 420,
                child: PageView.builder(
                  controller: _heroPageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentHeroIndex = index % movies.length;
                    });

                    // Seamless loop - jump to start when reaching near the end
                    if (index % movies.length == movies.length - 1 &&
                        index > 0) {
                      Future.delayed(Duration(milliseconds: 800), () {
                        if (_heroPageController.hasClients) {
                          _heroPageController.jumpToPage(0);
                        }
                      });
                    }
                  },
                  itemCount: null, // Infinite items
                  itemBuilder: (context, index) {
                    return _buildHeroItem(movies[index % movies.length]);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                movies.length,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _currentHeroIndex == index ? 28 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: _currentHeroIndex == index
                          ? AppTheme.primaryRed
                          : Colors.white.withOpacity(0.4),
                      boxShadow: _currentHeroIndex == index
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryRed.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ]
                          : [],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroItem(Movie movie) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: '${AppConfig.tmdbImageBaseUrl}${movie.backdropPath}',
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: AppTheme.mediumBlack),
          errorWidget: (context, url, error) => Container(
            color: AppTheme.mediumBlack,
            child: Icon(Icons.movie, color: AppTheme.lightGray),
          ),
        ),
        // Top gradient overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom gradient overlay (stronger)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 240,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.95),
                ],
              ),
            ),
          ),
        ),
        // Content positioned at bottom with padding
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title - larger and bolder with shadow
                Text(
                  movie.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                // Rating and Info Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            movie.voteAverage.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Featured',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Overview text
                Text(
                  movie.overview.isNotEmpty
                      ? movie.overview
                      : 'No description available',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFDDDDDD),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                // Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          navigateWithTransition(
                            context,
                            DetailsScreen(movie: movie),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: AppTheme.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text(
                          'Watch Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.info_outline),
                        color: Colors.white,
                        onPressed: () {
                          navigateWithTransition(
                            context,
                            DetailsScreen(movie: movie),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, {bool showFilter = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (showFilter)
            GestureDetector(
              onTap: () {
                navigateWithTransition(context, const FilterScreen());
              },
              child: Icon(Icons.tune, color: AppTheme.primaryRed, size: 24),
            ),
        ],
      ),
    );
  }

  // Helper method to build genre section widgets
  Widget _buildCachedGenreSection(Future<List<Movie>> future) {
    return FutureBuilder<List<Movie>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MovieListSkeletonLoader(itemCount: 10);
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final movies = snapshot.data!.take(10).toList();

        return SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const ClampingScrollPhysics(),
            cacheExtent: 300,
            itemCount: movies.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 130,
                  child: GestureDetector(
                    onTap: () {
                      navigateWithTransition(
                        context,
                        DetailsScreen(movie: movies[index]),
                      );
                    },
                    child: MovieCard(
                      posterPath: movies[index].posterPath,
                      title: movies[index].title,
                      rating: movies[index].voteAverage,
                      onTap: () {
                        navigateWithTransition(
                          context,
                          DetailsScreen(movie: movies[index]),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActionSection() => _buildCachedGenreSection(_actionFuture);
  Widget _buildComedySection() => _buildCachedGenreSection(_comedyFuture);
  Widget _buildHorrorSection() => _buildCachedGenreSection(_horrorFuture);
  Widget _buildRomanceSection() => _buildCachedGenreSection(_romanceFuture);
  Widget _buildSciFiSection() => _buildCachedGenreSection(_sciFiFuture);
  Widget _buildThrillerSection() => _buildCachedGenreSection(_thrillerFuture);

  Widget _buildMovieHorizontalList(String type) {
    return Consumer<MoviesProvider>(
      builder: (context, provider, child) {
        final movies = provider.getMovieList(type);

        if (movies.isEmpty) {
          return const MovieListSkeletonLoader(itemCount: 10);
        }

        // Limit to first 10 items to reduce frame skips
        final displayedMovies = movies.take(10).toList();

        return SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const ClampingScrollPhysics(),
            cacheExtent: 300,
            itemCount: displayedMovies.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 130,
                  child: GestureDetector(
                    onTap: () {
                      navigateWithTransition(
                        context,
                        DetailsScreen(movie: displayedMovies[index]),
                      );
                    },
                    child: MovieCard(
                      posterPath: displayedMovies[index].posterPath,
                      title: displayedMovies[index].title,
                      rating: displayedMovies[index].voteAverage,
                      onTap: () {
                        navigateWithTransition(
                          context,
                          DetailsScreen(movie: displayedMovies[index]),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
