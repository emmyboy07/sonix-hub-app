import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sonix_hub/config/app_config.dart';
import 'package:sonix_hub/models/movie.dart';
import 'package:sonix_hub/models/cast.dart';
import 'package:sonix_hub/models/tv_show_details.dart';
import 'package:sonix_hub/models/person_details.dart'; // Import for PersonDetails

class TMDBService {
  static const Duration _defaultTimeout = Duration(seconds: 8);
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheDuration = Duration(hours: 1);

  // Helper: Check cache validity (1 hour expiry)
  static bool _isCacheValid(String key) {
    if (!_cacheTime.containsKey(key)) return false;
    final elapsed = DateTime.now().difference(_cacheTime[key]!);
    return elapsed < _cacheDuration;
  }

  // Helper: Get cached data if valid, else null
  static dynamic _getCached(String key) {
    return _isCacheValid(key) ? _cache[key] : null;
  }

  // Helper: Cache data with timestamp
  static void _setCached(String key, dynamic value) {
    _cache[key] = value;
    _cacheTime[key] = DateTime.now();
  }

  static Future<Season> getSeason(int showId, int seasonNumber) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.tmdbBaseUrl}/tv/$showId/season/$seasonNumber?api_key=${AppConfig.tmdbApiKey}',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Season.fromJson(data);
      } else {
        throw Exception('Failed to load season');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<List<Movie>> getTrendingMovies() async {
    try {
      const cacheKey = 'trending_movies';
      final cached = _getCached(cacheKey);
      if (cached != null) return List<Movie>.from(cached);

      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/trending/movie/week?api_key=${AppConfig.tmdbApiKey}',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Movie> movies = (data['results'] as List)
            .map((movie) => Movie.fromJson(movie as Map<String, dynamic>))
            .toList();
        _setCached(cacheKey, movies);
        return movies;
      } else {
        throw Exception('Failed to load trending movies');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<List<Movie>> getTopRatedMovies() async {
    try {
      const cacheKey = 'top_rated_movies';
      final cached = _getCached(cacheKey);
      if (cached != null) return List<Movie>.from(cached);

      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/movie/top_rated?api_key=${AppConfig.tmdbApiKey}',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Movie> movies = (data['results'] as List)
            .map((movie) => Movie.fromJson(movie as Map<String, dynamic>))
            .toList();
        _setCached(cacheKey, movies);
        return movies;
      } else {
        throw Exception('Failed to load top rated movies');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<List<Movie>> getPopularMovies() async {
    try {
      const cacheKey = 'popular_movies';
      final cached = _getCached(cacheKey);
      if (cached != null) return List<Movie>.from(cached);

      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/movie/popular?api_key=${AppConfig.tmdbApiKey}',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Movie> movies = (data['results'] as List)
            .map((movie) => Movie.fromJson(movie as Map<String, dynamic>))
            .toList();
        _setCached(cacheKey, movies);
        return movies;
      } else {
        throw Exception('Failed to load popular movies');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<List<Movie>> getUpcomingMovies() async {
    try {
      const cacheKey = 'upcoming_movies';
      final cached = _getCached(cacheKey);
      if (cached != null) return List<Movie>.from(cached);

      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/movie/upcoming?api_key=${AppConfig.tmdbApiKey}',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Movie> movies = (data['results'] as List)
            .map((movie) => Movie.fromJson(movie as Map<String, dynamic>))
            .toList();
        _setCached(cacheKey, movies);
        return movies;
      } else {
        throw Exception('Failed to load upcoming movies');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<List<Movie>> getGenreMovies(int genreId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.tmdbBaseUrl}/discover/movie?api_key=${AppConfig.tmdbApiKey}&with_genres=$genreId',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Movie> movies = (data['results'] as List)
            .map((movie) => Movie.fromJson(movie as Map<String, dynamic>))
            .toList();
        return movies;
      } else {
        throw Exception('Failed to load genre movies');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Fetch both movies and TV shows for a genre
  static Future<List<Movie>> getGenreMoviesAndShows(int genreId) async {
    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse(
            '${AppConfig.tmdbBaseUrl}/discover/movie?api_key=${AppConfig.tmdbApiKey}&with_genres=$genreId',
          ),
        ),
        http.get(
          Uri.parse(
            '${AppConfig.tmdbBaseUrl}/discover/tv?api_key=${AppConfig.tmdbApiKey}&with_genres=$genreId',
          ),
        ),
      ]);

      List<Movie> allResults = [];

      // Process movie response
      if (responses[0].statusCode == 200) {
        final movieData = jsonDecode(responses[0].body);
        final movies = (movieData['results'] as List)
            .map((movie) => Movie.fromJson(movie as Map<String, dynamic>))
            .toList();
        allResults.addAll(movies);
      }

      // Process TV response
      if (responses[1].statusCode == 200) {
        final tvData = jsonDecode(responses[1].body);
        final tvShows = (tvData['results'] as List).map((show) {
          // Convert TV show data to Movie format
          final json = show as Map<String, dynamic>;
          json['title'] = json['name'];
          json['backdrop_path'] = json['backdrop_path'];
          json['poster_path'] = json['poster_path'];
          json['media_type'] = 'tv';
          return Movie.fromJson(json);
        }).toList();
        allResults.addAll(tvShows);
      }

      // Shuffle and return to mix movies and shows
      allResults.shuffle();
      return allResults;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<List<Movie>> searchMovies(String query) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/search/multi?api_key=${AppConfig.tmdbApiKey}&query=$query',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Movie> results = (data['results'] as List)
            .where(
              (item) =>
                  item['media_type'] == 'movie' || item['media_type'] == 'tv',
            )
            .map((item) {
              final mediaType = item['media_type'] ?? 'movie';
              final isTvShow = mediaType == 'tv';
              // Use default values for missing/null fields
              return Movie(
                id: item['id'] ?? 0,
                title: isTvShow
                    ? (item['name'] ?? item['title'] ?? 'Untitled')
                    : (item['title'] ?? item['name'] ?? 'Untitled'),
                posterPath: item['poster_path'] ?? '',
                backdropPath: item['backdrop_path'] ?? '',
                overview: item['overview'] ?? '',
                voteAverage: (item['vote_average'] ?? 0.0).toDouble(),
                releaseDate: isTvShow
                    ? (item['first_air_date'] ?? item['release_date'] ?? '')
                    : (item['release_date'] ?? item['first_air_date'] ?? ''),
                genreIds: item['genre_ids'] != null
                    ? List<int>.from(item['genre_ids'])
                    : <int>[],
                mediaType: mediaType,
                originalLanguage: item['original_language'] ?? '',
              );
            })
            .toList();
        return results;
      } else {
        throw Exception('Failed to search movies and shows');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get movie credits (cast)
  static Future<List<Cast>> getMovieCast(int movieId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/movie/$movieId/credits?api_key=${AppConfig.tmdbApiKey}',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Cast> cast = (data['cast'] as List)
            .map((member) => Cast.fromJson(member as Map<String, dynamic>))
            .toList();
        return cast;
      } else {
        throw Exception('Failed to load cast');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get similar movies
  static Future<List<Movie>> getSimilarMovies(int movieId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/movie/$movieId/similar?api_key=${AppConfig.tmdbApiKey}',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Movie> movies = (data['results'] as List)
            .map((movie) => Movie.fromJson(movie as Map<String, dynamic>))
            .toList();
        return movies;
      } else {
        throw Exception('Failed to load similar movies');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get recommended movies
  static Future<List<Movie>> getRecommendedMovies(int movieId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/movie/$movieId/recommendations?api_key=${AppConfig.tmdbApiKey}',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Movie> movies = (data['results'] as List)
            .map((movie) => Movie.fromJson(movie as Map<String, dynamic>))
            .toList();
        return movies;
      } else {
        throw Exception('Failed to load recommended movies');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get TV show credits (cast)
  static Future<List<Cast>> getTVShowCast(int showId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/tv/$showId/credits?api_key=${AppConfig.tmdbApiKey}',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Cast> cast = (data['cast'] as List)
            .map((member) => Cast.fromJson(member as Map<String, dynamic>))
            .toList();
        return cast;
      } else {
        throw Exception('Failed to load TV show cast');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get similar TV shows
  static Future<List<Movie>> getSimilarTVShows(int showId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/tv/$showId/similar?api_key=${AppConfig.tmdbApiKey}',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Movie> shows = (data['results'] as List).map((show) {
          final result = Movie.fromJson(show as Map<String, dynamic>);
          return result.copyWith(mediaType: 'tv');
        }).toList();
        return shows;
      } else {
        throw Exception('Failed to load similar TV shows');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get recommended TV shows
  static Future<List<Movie>> getRecommendedTVShows(int showId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/tv/$showId/recommendations?api_key=${AppConfig.tmdbApiKey}',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Movie> shows = (data['results'] as List).map((show) {
          final result = Movie.fromJson(show as Map<String, dynamic>);
          return result.copyWith(mediaType: 'tv');
        }).toList();
        return shows;
      } else {
        throw Exception('Failed to load recommended TV shows');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get TV show details with seasons
  static Future<TVShowDetails> getTVShowDetails(int showId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/tv/$showId?api_key=${AppConfig.tmdbApiKey}',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TVShowDetails.fromJson(data);
      } else {
        throw Exception('Failed to load TV show details');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get movie details
  static Future<Movie> getMovieDetails(int movieId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.tmdbBaseUrl}/movie/$movieId?api_key=${AppConfig.tmdbApiKey}',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Movie.fromJson({...data, 'media_type': 'movie'});
      } else {
        throw Exception('Failed to load movie details');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get full person details (details, images, credits, external ids)
  static Future<PersonDetails> getPersonDetailsFull(int personId) async {
    final apiKey = AppConfig.tmdbApiKey;
    final baseUrl = AppConfig.tmdbBaseUrl;
    final imageBaseUrl = AppConfig.tmdbImageBaseUrl;
    try {
      final detailsRes = await http.get(
        Uri.parse(
          '$baseUrl/person/$personId?api_key=$apiKey&append_to_response=images,movie_credits,tv_credits,external_ids',
        ),
      );
      if (detailsRes.statusCode != 200) {
        throw Exception('Failed to load person details');
      }
      final detailsJson = jsonDecode(detailsRes.body);
      // Patch image URLs
      if (detailsJson['profile_path'] != null) {
        detailsJson['profile_path'] =
            imageBaseUrl + detailsJson['profile_path'];
      }
      if (detailsJson['backdrop_path'] != null) {
        detailsJson['backdrop_path'] =
            imageBaseUrl + detailsJson['backdrop_path'];
      }
      if (detailsJson['images'] != null &&
          detailsJson['images']['profiles'] != null) {
        detailsJson['images']['profiles'] =
            (detailsJson['images']['profiles'] as List)
                .map(
                  (img) => {
                    'file_path': imageBaseUrl + (img['file_path'] ?? ''),
                  },
                )
                .toList();
      }
      if (detailsJson['movie_credits'] != null &&
          detailsJson['movie_credits']['cast'] != null) {
        detailsJson['movie_credits']['cast'] =
            (detailsJson['movie_credits']['cast'] as List)
                .where((c) => c['poster_path'] != null)
                .map((c) {
                  c['poster_path'] = imageBaseUrl + (c['poster_path'] ?? '');
                  return c;
                })
                .toList();
      }
      if (detailsJson['tv_credits'] != null &&
          detailsJson['tv_credits']['cast'] != null) {
        detailsJson['tv_credits']['cast'] =
            (detailsJson['tv_credits']['cast'] as List)
                .where((c) => c['poster_path'] != null)
                .map((c) {
                  c['poster_path'] = imageBaseUrl + (c['poster_path'] ?? '');
                  return c;
                })
                .toList();
      }
      // Known for: top 12 movies by popularity
      detailsJson['known_for'] = (detailsJson['movie_credits']?['cast'] ?? [])
          .take(12)
          .toList();
      return PersonDetails.fromJson(detailsJson);
    } catch (e) {
      throw Exception('Error loading person details: $e');
    }
  }

  /// Fetch YouTube trailer video ID for a movie or TV show
  static Future<String?> getTrailerVideoId(int id, bool isTV) async {
    try {
      final endpoint = isTV ? 'tv' : 'movie';
      final url =
          '${AppConfig.tmdbBaseUrl}/$endpoint/$id/videos?api_key=${AppConfig.tmdbApiKey}';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final videos = data['results'] as List?;

        if (videos == null || videos.isEmpty) {
          debugPrint('⚠️ No videos found for $endpoint ID: $id');
          return null;
        }

        // Find official YouTube trailer (prioritize in order)
        for (final video in videos) {
          if (video['site'] == 'YouTube' && video['type'] == 'Trailer') {
            debugPrint(
              '✅ Found official trailer: ${video['name']} (${video['key']})',
            );
            return video['key'];
          }
        }

        // Fallback: Any YouTube video
        for (final video in videos) {
          if (video['site'] == 'YouTube') {
            debugPrint(
              '⚠️ Using non-trailer video: ${video['name']} (${video['key']})',
            );
            return video['key'];
          }
        }

        debugPrint('⚠️ No YouTube videos found for $endpoint ID: $id');
        return null;
      } else {
        debugPrint('❌ Failed to fetch videos: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching trailer: $e');
      return null;
    }
  }
}
