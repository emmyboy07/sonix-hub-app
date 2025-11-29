import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ClipsaveService {
  static final ClipsaveService _instance = ClipsaveService._internal();

  factory ClipsaveService() {
    return _instance;
  }

  ClipsaveService._internal();

  final List<String> _logs = [];
  final String _tmdbApiKey = '1e2d76e7c45818ed61645cb647981e5c';

  List<String> get logs => _logs;

  void addLog(String message) {
    _logs.add('[${DateTime.now().toIso8601String()}] $message');
    debugPrint('🎬 Clipsave: $message');
  }

  void clearLogs() {
    _logs.clear();
  }

  String cleanTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Search for a movie on Clipsave
  Future<List<Map<String, dynamic>>> searchMovie(String query) async {
    try {
      addLog('🔍 Searching for movie: $query');

      final response = await http
          .post(
            Uri.parse('https://clipsave-movies-api.onrender.com/v1/movies/search'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'query': query}),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Search request timeout'),
          );

      if (response.statusCode != 200) {
        addLog('❌ Search failed with status ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      
      // Handle different response formats
      List<Map<String, dynamic>> results = [];
      
      // If data is directly a list
      if (data is List) {
        results = data.cast<Map<String, dynamic>>();
        addLog('✅ Response is direct list with ${results.length} results');
      }
      // If data is a map with 'results' field
      else if (data is Map && data['results'] != null) {
        final resultsList = data['results'];
        if (resultsList is List) {
          results = resultsList.cast<Map<String, dynamic>>();
          addLog('✅ Found results from results field: ${results.length} items');
        }
      }
      // If data is a map with 'data' field (nested structure)
      else if (data is Map && data['data'] != null) {
        final dataList = data['data'];
        if (dataList is List) {
          results = dataList.cast<Map<String, dynamic>>();
          addLog('✅ Found results from data field: ${results.length} items');
        }
      }

      if (results.isEmpty) {
        addLog('⚠️ Response structure: ${data.runtimeType}');
        if (data is Map) {
          addLog('⚠️ Response keys: ${data.keys.toList()}');
        }
        final responseStr = jsonEncode(data);
        if (responseStr.length > 300) {
          addLog('⚠️ Response content (first 300 chars): ${responseStr.substring(0, 300)}');
        } else {
          addLog('⚠️ Response content: $responseStr');
        }
      }

      addLog('✅ Found ${results.length} results');
      return results;
    } catch (e) {
      addLog('❌ Search error: $e');
      return [];
    }
  }

  /// Fetch movie info from Clipsave
  Future<Map<String, dynamic>?> fetchMovieInfo(
    String movieLink,
    String imdbId,
  ) async {
    try {
      addLog('📋 Fetching movie info for IMDB ID: $imdbId');

      final response = await http
          .get(
            Uri.parse(
              'https://clipsave-movies-api.onrender.com/v1/movies/info?link=${Uri.encodeComponent(movieLink)}&id=$imdbId',
            ),
            headers: {
              'accept': 'application/json',
              'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Info request timeout'),
          );

      if (response.statusCode != 200) {
        addLog('❌ Info request failed with status ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] != true || data['data'] == null) {
        addLog('⚠️ No info data returned');
        return null;
      }

      addLog('✅ Movie info fetched successfully');
      return data['data'] as Map<String, dynamic>;
    } catch (e) {
      addLog('❌ Info fetch error: $e');
      return null;
    }
  }

  /// Download links for a specific quality
  Future<List<String>> fetchDownloadLinks(String qualityLink) async {
    try {
      addLog('🔗 Fetching download links for quality');

      final response = await http
          .get(
            Uri.parse(
              'https://clipsave-movies-api.onrender.com/v1/movies/download-links?link=${Uri.encodeComponent(qualityLink)}',
            ),
            headers: {
              'accept': 'application/json',
              'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Download links request timeout'),
          );

      if (response.statusCode != 200) {
        addLog('❌ Download links request failed with status ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] != true || data['data'] == null) {
        addLog('⚠️ No download links returned');
        return [];
      }

      final links = <String>[];
      final dataList = data['data'] as List<dynamic>;

      for (final item in dataList) {
        if (item is Map<String, dynamic> && item['downloadLink'] != null) {
          links.add(item['downloadLink'] as String);
        }
      }

      addLog('✅ Found ${links.length} download links');
      return links;
    } catch (e) {
      addLog('❌ Download links error: $e');
      return [];
    }
  }

  /// Fetch movie from Clipsave (main method)
  Future<Map<String, dynamic>?> fetchMovie(
    int tmdbId,
    String movieTitle,
  ) async {
    try {
      addLog('🎬 Starting movie fetch: $movieTitle (TMDB ID: $tmdbId)');

      // Step 1: Get movie info from TMDB
      addLog('📡 Fetching TMDB data...');
      String? imdbId;
      String? title;

      try {
        final tmdbUrl =
            'https://api.themoviedb.org/3/movie/$tmdbId?api_key=$_tmdbApiKey';
        final tmdbResponse = await http
            .get(Uri.parse(tmdbUrl))
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception('TMDB request timeout'),
            );

        if (tmdbResponse.statusCode == 200) {
          final tmdbData = jsonDecode(tmdbResponse.body) as Map<String, dynamic>;
          imdbId = tmdbData['imdb_id'] as String?;
          title = tmdbData['title'] as String?;

          if (imdbId != null && title != null) {
            addLog('✅ TMDB data: Title=$title, IMDB ID=$imdbId');
          } else {
            addLog('⚠️ Missing IMDB ID or title in TMDB response');
            return null;
          }
        } else {
          addLog('⚠️ TMDB request failed with status ${tmdbResponse.statusCode}');
          return null;
        }
      } catch (e) {
        addLog('❌ TMDB fetch error: $e');
        return null;
      }

      // Step 2: Search for movie on Clipsave
      addLog('🔍 Searching on Clipsave...');
      final cleanedTitle = cleanTitle(title);
      final searchResults = await searchMovie(cleanedTitle);

      if (searchResults.isEmpty) {
        addLog('❌ No search results on Clipsave');
        return null;
      }

      // Step 3: Find matching movie by IMDB ID
      Map<String, dynamic>? matched;
      for (final result in searchResults) {
        if (result['id'] == imdbId) {
          matched = result;
          break;
        }
      }

      if (matched == null) {
        addLog('❌ No matching movie found by IMDB ID on Clipsave');
        return null;
      }

      final movieLink = matched['link'] as String?;
      if (movieLink == null) {
        addLog('❌ No movie link in matched result');
        return null;
      }

      addLog('✅ Found matching movie: $movieLink');

      // Step 4: Get movie info
      addLog('📋 Getting movie info...');
      final movieInfo = await fetchMovieInfo(movieLink, imdbId);

      if (movieInfo == null) {
        addLog('❌ Failed to get movie info');
        return null;
      }

      // Step 5: Extract and process qualities
      addLog('⚙️ Processing qualities...');
      final qualities = movieInfo['qualities'] as List<dynamic>? ?? [];

      if (qualities.isEmpty) {
        addLog('❌ No qualities found');
        return null;
      }

      // Sort qualities by resolution to pick best SD (480p) and HD (720p)
      final qualityList = <Map<String, dynamic>>[];

      for (final quality in qualities) {
        if (quality is Map<String, dynamic>) {
          qualityList.add(quality);
        }
      }

      // Pick 480p and 720p qualities
      Map<String, dynamic>? sd480Quality;
      Map<String, dynamic>? hd720Quality;

      for (final quality in qualityList) {
        final qualityStr = (quality['quality'] as String?)?.toLowerCase() ?? '';
        final name = (quality['name'] as String?)?.toLowerCase() ?? '';

        if ((qualityStr.contains('480') || name.contains('480')) &&
            sd480Quality == null) {
          sd480Quality = quality;
        } else if ((qualityStr.contains('720') || name.contains('720')) &&
            hd720Quality == null) {
          hd720Quality = quality;
        }
      }

      // If we don't have 480p and 720p, pick the first two available
      if (sd480Quality == null && qualityList.isNotEmpty) {
        sd480Quality = qualityList[0];
      }
      if (hd720Quality == null && qualityList.length > 1) {
        hd720Quality = qualityList[1];
      }

      final processedQualities = <Map<String, dynamic>>[];

      // Process 480p (SD)
      if (sd480Quality != null) {
        addLog('🔗 Fetching 480p links...');
        final qualityLink = sd480Quality['link'] as String?;
        if (qualityLink != null) {
          final links = await fetchDownloadLinks(qualityLink);
          if (links.isNotEmpty) {
            processedQualities.add({
              'quality': '480p',
              'size': sd480Quality['size'] ?? 'Unknown',
              'links': links,
            });
            addLog('✅ 480p quality added with ${links.length} links');
          }
        }
      }

      // Process 720p (HD)
      if (hd720Quality != null) {
        addLog('🔗 Fetching 720p links...');
        final qualityLink = hd720Quality['link'] as String?;
        if (qualityLink != null) {
          final links = await fetchDownloadLinks(qualityLink);
          if (links.isNotEmpty) {
            processedQualities.add({
              'quality': '720p',
              'size': hd720Quality['size'] ?? 'Unknown',
              'links': links,
            });
            addLog('✅ 720p quality added with ${links.length} links');
          }
        }
      }

      if (processedQualities.isEmpty) {
        addLog('❌ No qualities could be processed');
        return null;
      }

      addLog('🎉 Movie fetching completed successfully');

      return {
        'success': true,
        'title': title,
        'qualities': processedQualities,
      };
    } catch (e) {
      addLog('❌ Exception occurred: $e');
      return null;
    }
  }
}
