import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../models/movie.dart';
import '../utils/page_transitions.dart';
import 'details_screen.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // Filter options
  String _selectedContentType = 'all'; // all, movie, tv
  final Set<int> _selectedGenres = {};
  int _selectedYear = 0; // 0 means all years

  // Pagination
  List<Movie> _allResults = [];
  List<Movie> _displayedResults = [];
  int _nextMoviePage = 1;
  int _nextTVPage = 1;
  static const int _itemsPerPage = 15;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;

  // Genre list
  final List<Map<String, dynamic>> _genres = [
    {'id': 28, 'name': 'Action'},
    {'id': 12, 'name': 'Adventure'},
    {'id': 16, 'name': 'Animation'},
    {'id': 35, 'name': 'Comedy'},
    {'id': 80, 'name': 'Crime'},
    {'id': 99, 'name': 'Documentary'},
    {'id': 18, 'name': 'Drama'},
    {'id': 10751, 'name': 'Family'},
    {'id': 14, 'name': 'Fantasy'},
    {'id': 36, 'name': 'History'},
    {'id': 27, 'name': 'Horror'},
    {'id': 10402, 'name': 'Music'},
    {'id': 9648, 'name': 'Mystery'},
    {'id': 10749, 'name': 'Romance'},
    {'id': 878, 'name': 'Science Fiction'},
    {'id': 10770, 'name': 'TV Movie'},
    {'id': 53, 'name': 'Thriller'},
    {'id': 10752, 'name': 'War'},
    {'id': 37, 'name': 'Western'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _applyFilters();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (!_isLoadingMore) {
      final nextIndex = _displayedResults.length;
      if (nextIndex < _allResults.length) {
        // Still items to display from already fetched data
        setState(() {
          _isLoadingMore = true;
          final endIndex = (nextIndex + _itemsPerPage).clamp(
            0,
            _allResults.length,
          );
          _displayedResults.addAll(_allResults.sublist(nextIndex, endIndex));
          _isLoadingMore = false;
        });
      } else if (nextIndex >= _allResults.length) {
        // At the end of fetched data, fetch more pages
        _fetchMorePages();
      }
    }
  }

  Future<void> _fetchMorePages() async {
    try {
      List<Movie> newResults = [];

      if (_selectedContentType == 'all') {
        // Fetch next 3 pages from both simultaneously
        final futures = <Future<List<Movie>>>[];
        for (int i = 0; i < 3; i++) {
          futures.add(_fetchDiscoverPage('movie', _nextMoviePage + i));
          futures.add(_fetchDiscoverPage('tv', _nextTVPage + i));
        }

        final results = await Future.wait(futures);

        List<Movie> movieResults = [];
        List<Movie> tvResults = [];

        // Separate movies and TV results
        for (int i = 0; i < results.length; i++) {
          if (i.isEven) {
            movieResults.addAll(results[i]);
          } else {
            tvResults.addAll(results[i]);
          }
        }

        // Intelligently mix
        movieResults.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
        tvResults.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));

        int movieIndex = 0;
        int tvIndex = 0;

        while (movieIndex < movieResults.length || tvIndex < tvResults.length) {
          if (movieIndex < movieResults.length) {
            newResults.add(movieResults[movieIndex]);
            movieIndex++;
          }
          if (tvIndex < tvResults.length) {
            newResults.add(tvResults[tvIndex]);
            tvIndex++;
          }
        }

        _nextMoviePage += 3;
        _nextTVPage += 3;
      } else if (_selectedContentType == 'movie') {
        // Fetch next 5 pages of movies only
        for (int page = _nextMoviePage; page < _nextMoviePage + 5; page++) {
          final pageResults = await _fetchDiscoverPage('movie', page);
          newResults.addAll(pageResults);
        }
        _nextMoviePage += 5;
      } else if (_selectedContentType == 'tv') {
        // Fetch next 5 pages of TV only
        for (int page = _nextTVPage; page < _nextTVPage + 5; page++) {
          final pageResults = await _fetchDiscoverPage('tv', page);
          newResults.addAll(pageResults);
        }
        _nextTVPage += 5;
      }

      // Apply filters
      newResults = _applyClientSideFilters(newResults);

      if (mounted) {
        setState(() {
          _allResults.addAll(newResults);
          // After adding more results, try to load next batch immediately
          final nextIndex = _displayedResults.length;
          if (nextIndex < _allResults.length) {
            final endIndex = (nextIndex + (_itemsPerPage * 3)).clamp(
              0,
              _allResults.length,
            );
            _displayedResults.addAll(_allResults.sublist(nextIndex, endIndex));
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching more pages: $e');
    }
  }

  Future<void> _applyFilters() async {
    setState(() {
      _isLoading = true;
      _nextMoviePage = 1;
      _nextTVPage = 1;
      _displayedResults = [];
      _allResults = [];
    });

    try {
      List<Movie> results = [];

      if (_selectedContentType == 'all') {
        // Fetch both movies and TV simultaneously
        results = await _fetchBothSimultaneously();
      } else if (_selectedContentType == 'movie') {
        // Fetch only movies
        for (int page = 1; page <= 5; page++) {
          final pageResults = await _fetchDiscoverPage('movie', page);
          results.addAll(pageResults);
        }
        _nextMoviePage = 6;
      } else if (_selectedContentType == 'tv') {
        // Fetch only TV
        for (int page = 1; page <= 5; page++) {
          final pageResults = await _fetchDiscoverPage('tv', page);
          results.addAll(pageResults);
        }
        _nextTVPage = 6;
      }

      // Apply filters
      results = _applyClientSideFilters(results);

      if (mounted) {
        setState(() {
          _allResults = results;
          // Load first page
          final endIndex = _itemsPerPage.clamp(0, _allResults.length);
          _displayedResults = _allResults.sublist(0, endIndex);
          _isLoading = false;
          // Scroll to top
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error applying filters: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Intelligently fetches and mixes movies and TV simultaneously
  Future<List<Movie>> _fetchBothSimultaneously() async {
    List<Movie> movieResults = [];
    List<Movie> tvResults = [];

    // Fetch pages 1-3 from both simultaneously
    final futures = <Future<List<Movie>>>[];
    for (int page = 1; page <= 3; page++) {
      futures.add(_fetchDiscoverPage('movie', page));
      futures.add(_fetchDiscoverPage('tv', page));
    }

    final results = await Future.wait(futures);

    // Separate movies and TV results
    for (int i = 0; i < results.length; i++) {
      if (i.isEven) {
        movieResults.addAll(results[i]);
      } else {
        tvResults.addAll(results[i]);
      }
    }

    // Intelligently mix: Alternate between movies and TV by rating
    // Sort both by rating first
    movieResults.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    tvResults.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));

    List<Movie> mixed = [];
    int movieIndex = 0;
    int tvIndex = 0;

    // Alternate between movie and TV in a smart way
    while (movieIndex < movieResults.length || tvIndex < tvResults.length) {
      if (movieIndex < movieResults.length) {
        mixed.add(movieResults[movieIndex]);
        movieIndex++;
      }
      if (tvIndex < tvResults.length) {
        mixed.add(tvResults[tvIndex]);
        tvIndex++;
      }
    }

    // Set next pages to fetch
    _nextMoviePage = 4;
    _nextTVPage = 4;

    return mixed;
  }

  /// Fetch from discover endpoint with genre filtering support
  Future<List<Movie>> _fetchDiscoverPage(String type, int page) async {
    try {
      // Build genre filter string
      String genreFilter = '';
      if (_selectedGenres.isNotEmpty) {
        genreFilter = '&with_genres=${_selectedGenres.first}';
      }

      // Build the endpoint URL
      final endpoint = type == 'tv' ? '/discover/tv' : '/discover/movie';
      final url =
          '${AppConfig.tmdbBaseUrl}$endpoint?api_key=${AppConfig.tmdbApiKey}&page=$page&sort_by=popularity.desc$genreFilter';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Movie> results = (data['results'] as List).map((item) {
          // Add media_type to the JSON if it's missing
          final itemJson = item as Map<String, dynamic>;
          if (!itemJson.containsKey('media_type')) {
            itemJson['media_type'] = type == 'tv' ? 'tv' : 'movie';
          }
          return Movie.fromJson(itemJson);
        }).toList();
        return results;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching $type page $page: $e');
      return [];
    }
  }

  List<Movie> _applyClientSideFilters(List<Movie> results) {
    // Filter by content type
    if (_selectedContentType == 'movie') {
      results = results.where((m) => m.mediaType != 'tv').toList();
    } else if (_selectedContentType == 'tv') {
      results = results.where((m) => m.mediaType == 'tv').toList();
    }

    // Filter by genre if selected
    if (_selectedGenres.isNotEmpty) {
      results = results
          .where(
            (m) =>
                m.genreIds.any((genreId) => _selectedGenres.contains(genreId)),
          )
          .toList();
    }

    // Filter by year (only if year is selected, not "All Years")
    if (_selectedYear > 0) {
      results = results
          .where(
            (m) =>
                m.releaseDate.isNotEmpty &&
                int.tryParse(m.releaseDate.split('-')[0]) == _selectedYear,
          )
          .toList();
    }

    // Remove duplicates
    final seenIds = <int>{};
    results = results.where((m) {
      if (seenIds.contains(m.id)) return false;
      seenIds.add(m.id);
      return true;
    }).toList();

    // Sort by rating descending
    results.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: const Text('Filter Content'),
        backgroundColor: AppTheme.darkBlack,
      ),
      body: Column(
        children: [
          // Filter Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.mediumBlack,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content Type
                Text(
                  'Content Type',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFilterChip(
                      label: 'All',
                      selected: _selectedContentType == 'all',
                      onTap: () {
                        setState(() => _selectedContentType = 'all');
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Movies',
                      selected: _selectedContentType == 'movie',
                      onTap: () {
                        setState(() => _selectedContentType = 'movie');
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Series',
                      selected: _selectedContentType == 'tv',
                      onTap: () {
                        setState(() => _selectedContentType = 'tv');
                        _applyFilters();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Year and Genre Side by Side
                Row(
                  children: [
                    // Year Selection Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Year',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _selectedYear,
                              dropdownColor: AppTheme.mediumBlack,
                              isExpanded: true,
                              underline: const SizedBox.shrink(),
                              items: [
                                DropdownMenuItem(
                                  value: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'All Years',
                                      style: TextStyle(
                                        color: AppTheme.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                ...List.generate(24, (index) => 2026 - index)
                                    .map(
                                      (year) => DropdownMenuItem(
                                        value: year,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            year.toString(),
                                            style: TextStyle(
                                              color: AppTheme.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    ,
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedYear = value);
                                  _applyFilters();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Genres Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Genres',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _selectedGenres.isEmpty
                                  ? null
                                  : _selectedGenres.first,
                              dropdownColor: AppTheme.mediumBlack,
                              isExpanded: true,
                              underline: const SizedBox.shrink(),
                              hint: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Text(
                                  _selectedGenres.isEmpty
                                      ? 'All Genres'
                                      : 'Genre: ${_genres.firstWhere((g) => g['id'] == _selectedGenres.first)['name']}',
                                  style: TextStyle(
                                    color: AppTheme.lightGray,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              items: _genres
                                  .map(
                                    (genre) => DropdownMenuItem<int>(
                                      value: genre['id'],
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          genre['name'],
                                          style: TextStyle(
                                            color: AppTheme.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    if (_selectedGenres.contains(value)) {
                                      _selectedGenres.remove(value);
                                    } else {
                                      _selectedGenres.clear();
                                      _selectedGenres.add(value);
                                    }
                                  });
                                  _applyFilters();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_selectedGenres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedGenres.clear());
                        _applyFilters();
                      },
                      child: Text(
                        'Clear genre filter',
                        style: TextStyle(
                          color: AppTheme.primaryRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Results Grid (3 columns) with infinite scroll
          if (_isLoading)
            Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          else if (_displayedResults.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No results found. Try adjusting your filters.',
                  style: TextStyle(color: AppTheme.lightGray),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.65,
                ),
                itemCount: _displayedResults.length,
                itemBuilder: (context, index) {
                  final movie = _displayedResults[index];
                  return GestureDetector(
                    onTap: () {
                      navigateWithTransition(
                        context,
                        DetailsScreen(movie: movie),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl:
                                '${AppConfig.tmdbImageBaseUrl}${movie.posterPath}',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) =>
                                Container(color: AppTheme.mediumBlack),
                            errorWidget: (context, url, error) => Container(
                              color: AppTheme.mediumBlack,
                              child: Icon(
                                Icons.movie,
                                color: AppTheme.lightGray,
                              ),
                            ),
                          ),
                          // Gradient overlay at bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Title and Rating
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  movie.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: AppTheme.primaryRed,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      movie.voteAverage.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
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
                  );
                },
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryRed : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: selected ? Border.all(color: AppTheme.primaryRed) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppTheme.white,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
