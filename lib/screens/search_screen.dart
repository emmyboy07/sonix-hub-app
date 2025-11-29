import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../providers/movies_provider.dart';
import '../utils/page_transitions.dart';
import '../models/movie.dart';
import 'details_screen.dart';
import 'cast_screen.dart';
import '../services/youtube_service.dart';
import '../models/youtube_video.dart';
import 'youtube_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _searchController;
  final FocusNode _focusNode = FocusNode();
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  List<Map<String, dynamic>> _mixedResults = [];
  bool _isSearchingMixed = false;
  List<String> _recentSearches = [];
  List<dynamic> _trendingMovies = [];
  bool _isLoadingTrending = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _speechToText = stt.SpeechToText();
    _loadRecentSearches();
    _loadTrendingMovies();
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _speechToText.stop();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentList = prefs.getStringList('recent_searches') ?? [];
      if (mounted) {
        setState(() {
          _recentSearches = recentList;
        });
      }
    } catch (e) {
      print('Error loading recent searches: $e');
    }
  }

  Future<void> _loadTrendingMovies() async {
    setState(() => _isLoadingTrending = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.tmdbBaseUrl}/trending/movie/week?api_key=${AppConfig.tmdbApiKey}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = (data['results'] as List).take(10).toList();
        if (mounted) {
          setState(() {
            _trendingMovies = results;
            _isLoadingTrending = false;
          });
        }
      } else {
        throw Exception('Failed to load trending movies');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTrending = false);
        print('Error loading trending: $e');
      }
    }
  }

  // Search suggestions removed per product request.

  void _addToRecentSearches(String query) {
    if (query.isEmpty) return;
    setState(() {
      _recentSearches.remove(query); // Remove if exists
      _recentSearches.insert(0, query); // Add to beginning
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.sublist(0, 10); // Keep only 10
      }
    });
    // Save to SharedPreferences
    _saveRecentSearches();
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_searches', _recentSearches);
    } catch (e) {
      print('Error saving recent searches: $e');
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onError: (error) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${error.errorMsg}')));
        },
        onStatus: (status) {
          // Handle status
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _searchController.text = result.recognizedWords;
              });
              if (result.finalResult) {
                // Perform search when voice recognition completes
                _addToRecentSearches(result.recognizedWords);
                _searchMixed(result.recognizedWords);
              }
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  Future<void> _searchMixed(String query) async {
    if (query.isEmpty) {
      setState(() {
        _mixedResults.clear();
        _isSearchingMixed = false;
      });
      return;
    }

    setState(() => _isSearchingMixed = true);
    try {
      // Use the multi search endpoint to get both movies and people
      final response = await http.get(
        Uri.parse(
          '${AppConfig.tmdbBaseUrl}/search/multi?api_key=${AppConfig.tmdbApiKey}&query=$query',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final allResults = (data['results'] as List).where((item) {
          final mediaType = item['media_type'];
          return mediaType == 'movie' ||
              mediaType == 'tv' ||
              mediaType == 'person';
        }).toList();

        // Separate movies and people. We'll present movies/TV first,
        // then YouTube results, and put actors (people) last.
        final movies = allResults
            .where(
              (item) =>
                  item['media_type'] == 'movie' || item['media_type'] == 'tv',
            )
            .toList();
        final people = allResults
            .where((item) => item['media_type'] == 'person')
            .toList();

        // Start by showing movies/TV only so the UI can render quickly.
        final mixedResults = <Map<String, dynamic>>[];
        mixedResults.addAll(movies.map((e) => e as Map<String, dynamic>));

        if (mounted) {
          setState(() {
            _mixedResults = mixedResults;
            _isSearchingMixed = false;
          });
        }

        // Fetch YouTube results and then append YouTube + actors so actors are last
        try {
          final yv = await YouTubeService().searchVideos(query);
          final youtubeMaps = (yv.isNotEmpty
              ? yv
                    .map(
                      (v) => {
                        'media_type': 'youtube',
                        'id': v.id,
                        'title': v.title,
                        'thumbnail_url': v.thumbnailUrl,
                        'channel_name': v.channelName,
                      },
                    )
                    .toList()
              : <Map<String, dynamic>>[]);

          if (mounted) {
            setState(() {
              _mixedResults = [
                ..._mixedResults,
                ...youtubeMaps,
                ...people.map((e) => e as Map<String, dynamic>),
              ];
            });
          }
        } catch (e) {
          // On error, still append actors so the ordering is consistent
          if (mounted) {
            setState(() {
              _mixedResults = [
                ..._mixedResults,
                ...people.map((e) => e as Map<String, dynamic>),
              ];
              _isSearchingMixed = false;
            });
          }
          print('YouTube search failed: $e');
        }
      } else {
        throw Exception('Failed to search');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingMixed = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBlack,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Stack(
          children: [
            TextField(
              controller: _searchController,
              focusNode: _focusNode,
              style: TextStyle(color: AppTheme.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search movies, shows...',
                hintStyle: TextStyle(
                  color: AppTheme.lightGray.withOpacity(0.6),
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: AppTheme.primaryRed.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppTheme.mediumBlack,
                prefixIcon: Icon(
                  Icons.search,
                  color: AppTheme.primaryRed,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AppTheme.lightGray,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          context.read<MoviesProvider>().searchMovies('');
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                // Only update UI; suggestions removed
                setState(() {});
              },
              onSubmitted: (value) {
                // Perform actual search when user presses enter
                if (value.isNotEmpty) {
                  _addToRecentSearches(value);
                  _searchMixed(value);
                  _focusNode.unfocus();
                  setState(() {});
                }
              },
            ),
            // suggestions UI removed
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? AppTheme.primaryRed : AppTheme.white,
              size: 24,
            ),
            onPressed: _startListening,
            tooltip: _isListening ? 'Stop listening' : 'Voice search',
          ),
        ],
      ),
      body: Column(
        children: [
          // search suggestions removed
          // Search content
          Expanded(child: _buildMixedResults()),
        ],
      ),
    );
  }

  Widget _buildMixedResults() {
    // Show trending if no search query
    if (_searchController.text.isEmpty) {
      return _buildTrendingSection();
    }

    if (_isSearchingMixed) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRed),
      );
    }

    if (_mixedResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, color: AppTheme.lightGray, size: 80),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(color: AppTheme.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: TextStyle(
                color: AppTheme.lightGray.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      cacheExtent: 400,
      itemCount: _mixedResults.length,
      itemBuilder: (context, index) {
        final item = _mixedResults[index];
        final mediaType = item['media_type'] as String?;

        if (mediaType == 'person') {
          return _buildPeopleResultItem(item);
        } else if (mediaType == 'youtube') {
          return _buildYouTubeResultItem(item);
        } else {
          return _buildMovieResultItem(item);
        }
      },
    );
  }

  Widget _buildYouTubeResultItem(Map<String, dynamic> item) {
    final title = item['title'] ?? 'Unknown';
    final thumb = item['thumbnail_url'] ?? '';
    final id = item['id'] as String?;
    final channel = item['channel_name'] ?? '';

    return GestureDetector(
      onTap: () async {
        if (id == null) return;
        // Build a YouTubeVideo instance and navigate to details
        final v = YouTubeVideo(
          id: id,
          title: title,
          channelName: channel,
          channelId: '',
          thumbnailUrl: thumb,
          duration: Duration.zero,
          viewCount: 0,
          uploadDate: null,
          description: '',
        );
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => YouTubeDetailsScreen(video: v)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.mediumBlack, width: 1),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                height: 56,
                color: AppTheme.mediumBlack,
                child: thumb.isNotEmpty
                    ? Image.network(thumb, fit: BoxFit.cover)
                    : Icon(
                        Icons.play_circle_outline,
                        color: AppTheme.lightGray,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Badge under the title, left aligned
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Nollywood',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieResultItem(Map<String, dynamic> item) {
    final title = item['title'] ?? item['name'] ?? 'Unknown';
    final posterPath = item['poster_path'];
    final posterUrl = posterPath != null
        ? '${AppConfig.tmdbImageBaseUrl}$posterPath'
        : '';
    final voteAverage = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
    final overview = item['overview'] as String? ?? '';
    final mediaType = item['media_type'] as String?;
    final id = item['id'] as int?;

    return GestureDetector(
      onTap: () {
        if (id != null) {
          _addToRecentSearches(title);
          final movie = Movie(
            id: id,
            title: title,
            posterPath: posterPath ?? '',
            overview: overview,
            voteAverage: voteAverage,
            mediaType: mediaType ?? 'movie',
            releaseDate: item['release_date'] ?? '',
            backdropPath: item['backdrop_path'] ?? '',
            genreIds: List<int>.from(item['genre_ids'] as List? ?? []),
          );
          navigateWithTransition(context, DetailsScreen(movie: movie));
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.mediumBlack, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 90,
                color: AppTheme.mediumBlack,
                child: posterUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: AppTheme.mediumBlack),
                        errorWidget: (context, url, error) => Container(
                          color: AppTheme.mediumBlack,
                          child: Icon(
                            Icons.movie,
                            color: AppTheme.lightGray,
                            size: 30,
                          ),
                        ),
                        memCacheHeight: 180,
                        memCacheWidth: 120,
                      )
                    : Icon(Icons.movie, color: AppTheme.lightGray, size: 30),
              ),
            ),
            SizedBox(width: 16),
            // Movie info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  // Rating and metadata
                  Row(
                    children: [
                      Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                      SizedBox(width: 4),
                      Text(
                        voteAverage.toStringAsFixed(1),
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          mediaType == 'tv' ? 'TV Show' : 'Movie',
                          style: TextStyle(
                            color: AppTheme.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Overview
                  Text(
                    overview.isNotEmpty ? overview : 'No description available',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.lightGray,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeopleResultItem(Map<String, dynamic> item) {
    final name = item['name'] ?? 'Unknown';
    final profilePath = item['profile_path'];
    final profileUrl = profilePath != null
        ? '${AppConfig.tmdbImageBaseUrl}$profilePath'
        : '';
    final department = item['known_for_department'] ?? 'Acting';
    final id = item['id'] as int?;

    return GestureDetector(
      onTap: () {
        if (id != null) {
          _addToRecentSearches(name);
          navigateWithTransition(context, CastScreen(personId: id));
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.mediumBlack, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 90,
                color: AppTheme.mediumBlack,
                child: profileUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: profileUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: AppTheme.mediumBlack),
                        errorWidget: (context, url, error) => Container(
                          color: AppTheme.mediumBlack,
                          child: Icon(
                            Icons.person,
                            color: AppTheme.lightGray,
                            size: 30,
                          ),
                        ),
                        memCacheHeight: 180,
                        memCacheWidth: 120,
                      )
                    : Icon(Icons.person, color: AppTheme.lightGray, size: 30),
              ),
            ),
            SizedBox(width: 16),
            // Person info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Name
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  // Department with badge
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Person',
                          style: TextStyle(
                            color: AppTheme.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          department,
                          style: TextStyle(
                            color: AppTheme.lightGray,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
  }

  Widget _buildTrendingSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches Section
          if (_recentSearches.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Searches',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      setState(() {
                        _recentSearches.clear();
                      });
                      await _saveRecentSearches();
                    },
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        color: AppTheme.primaryRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentSearches.map((query) {
                  return GestureDetector(
                    onTap: () {
                      _searchController.text = query;
                      context.read<MoviesProvider>().searchMovies(query);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.mediumBlack,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryRed.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history,
                            color: AppTheme.lightGray,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            query,
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 24),
          ],
          // Top 10 Trending Section
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Top 10 Searches',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Top 10',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoadingTrending)
            Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryRed),
              ),
            )
          else if (_trendingMovies.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No trending movies found',
                  style: TextStyle(color: AppTheme.lightGray),
                ),
              ),
            )
          else
            ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _trendingMovies.length,
              itemBuilder: (context, index) {
                final movie = _trendingMovies[index];
                final posterUrl = movie['poster_path'] != null
                    ? '${AppConfig.tmdbImageBaseUrl}${movie['poster_path']}'
                    : '';
                final title = movie['title'] ?? movie['name'] ?? 'Unknown';

                return GestureDetector(
                  onTap: () {
                    // Navigate to movie details
                    _addToRecentSearches(title);
                    final movieObj = Movie(
                      id: movie['id'],
                      title: title,
                      overview: movie['overview'] ?? '',
                      posterPath: movie['poster_path'] ?? '',
                      backdropPath: movie['backdrop_path'] ?? '',
                      releaseDate: movie['release_date'] ?? '',
                      voteAverage: (movie['vote_average'] ?? 0).toDouble(),
                      genreIds: List<int>.from(movie['genre_ids'] ?? []),
                      mediaType: movie['media_type'] ?? 'movie',
                    );
                    navigateWithTransition(
                      context,
                      DetailsScreen(movie: movieObj),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.mediumBlack,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Rank Badge
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                color: AppTheme.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // Poster image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 40,
                            height: 60,
                            color: AppTheme.mediumBlack,
                            child: posterUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: posterUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(color: AppTheme.mediumBlack),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.movie,
                                      color: AppTheme.lightGray,
                                      size: 20,
                                    ),
                                    memCacheHeight: 120,
                                    memCacheWidth: 80,
                                  )
                                : Icon(
                                    Icons.movie,
                                    color: AppTheme.lightGray,
                                    size: 20,
                                  ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // Movie info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Color(0xFFFFD700),
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    (movie['vote_average'] ?? 0)
                                        .toStringAsFixed(1),
                                    style: TextStyle(
                                      color: AppTheme.white,
                                      fontSize: 11,
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
        ],
      ),
    );
  }
}
