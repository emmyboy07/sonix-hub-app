import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();

  factory DownloadService() {
    return _instance;
  }

  DownloadService._internal();

  final List<String> _logs = [];

  List<String> get logs => _logs;

  void addLog(String message) {
    _logs.add('[${DateTime.now().toIso8601String()}] $message');
    debugPrint('📥 Download: $message');
  }

  void clearLogs() {
    _logs.clear();
  }

  String? extractSubjectId(String html, String movieTitle, {String? year}) {
    try {
      // Split title into words for more flexible matching
      final titleWords = movieTitle.toLowerCase().trim().split(RegExp(r'\s+'));
      if (titleWords.isEmpty) {
        addLog('❌ Empty title provided');
        return null;
      }

      // Pattern to extract all entries: id, some field, and title
      final entryPattern = RegExp(
        r'"(\d{16,})"\s*,\s*"[^"]*"\s*,\s*"([^"]+)"',
        caseSensitive: true,
        dotAll: true,
      );

      String? bestMatch;
      int bestScore = 0;

      // Find all matches and score them
      for (final match in entryPattern.allMatches(html)) {
        final subjectId = match.group(1)!;
        final movieboxTitle = match.group(2)!.toLowerCase().trim();

        // Score the match
        int score = 0;

        // Check if moviebox title starts with our search title
        if (movieboxTitle.startsWith(movieTitle.toLowerCase())) {
          score += 100; // High priority for exact start match
        }

        // Check word-by-word match for the beginning
        final movieboxWords = movieboxTitle.split(RegExp(r'\s+'));
        int matchedWords = 0;
        for (int i = 0; i < titleWords.length && i < movieboxWords.length; i++) {
          if (titleWords[i] == movieboxWords[i]) {
            matchedWords++;
          } else {
            break; // Stop at first mismatch
          }
        }

        if (matchedWords > 0) {
          score += matchedWords * 10; // Score based on matched words
          
          // Additional points for year match if provided
          if (year != null && movieboxTitle.contains(year)) {
            score += 50;
          }

          addLog(
            '🎯 Candidate: "$movieboxTitle" (ID: $subjectId, Score: $score)',
          );

          if (score > bestScore) {
            bestScore = score;
            bestMatch = subjectId;
          }
        }
      }

      if (bestMatch != null) {
        addLog('✅ Best match found with score: $bestScore');
        return bestMatch;
      } else {
        addLog('❌ No suitable match found in search results');
        return null;
      }
    } catch (e) {
      addLog('❌ Error extracting subjectId: $e');
      return null;
    }
  }

  String? extractDetailPathFromHtml(
    String html,
    String subjectId,
    String movieTitle,
  ) {
    try {
      final slug =
          '${movieTitle.trim().toLowerCase().replaceAll(RegExp(r"[''']"), '').replaceAll('&', 'and').replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '')}-';

      addLog('📝 Generated slug: $slug');

      final idPattern = RegExp('"($subjectId)"');
      final idMatch = idPattern.firstMatch(html);
      if (idMatch == null) {
        addLog('⚠️ Subject ID not found in HTML');
        return null;
      }

      final before = html.substring(0, idMatch.start);
      final detailPathRegex = RegExp('"((?:$slug)[^"]+)"', multiLine: true);

      String? lastMatch;
      for (final match in detailPathRegex.allMatches(before)) {
        lastMatch = match.group(1);
      }

      if (lastMatch != null) {
        addLog('✅ Detail path found: $lastMatch');
      } else {
        addLog('⚠️ Detail path not found');
      }

      return lastMatch;
    } catch (e) {
      addLog('❌ Error extracting detail path: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchDownloadLink(
    int tmdbId,
    String movieTitle, {
    int seasonNumber = 0,
    int episodeNumber = 0,
    bool isTV = false,
  }) async {
    try {
      addLog('🔎 Starting download link fetch for: $movieTitle (ID: $tmdbId)');

      // First, fetch movie/tv data from TMDB to get release year
      addLog('📡 Fetching ${isTV ? 'TV show' : 'movie'} info from TMDB...');
      String year = '';
      String searchTitle = movieTitle;

      try {
        final endpoint = isTV ? 'tv' : 'movie';
        final tmdbUrl =
            'https://api.themoviedb.org/3/$endpoint/$tmdbId?api_key=1e2d76e7c45818ed61645cb647981e5c';
        final tmdbResponse = await http
            .get(Uri.parse(tmdbUrl))
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception('TMDB request timeout'),
            );

        if (tmdbResponse.statusCode == 200) {
          final tmdbData =
              jsonDecode(tmdbResponse.body) as Map<String, dynamic>;
          final title = isTV
              ? tmdbData['name'] as String?
              : tmdbData['title'] as String?;
          final releaseDate = isTV
              ? tmdbData['first_air_date'] as String?
              : tmdbData['release_date'] as String?;
          year = releaseDate?.split('-').first ?? '';
          // For TV shows, use the TMDB name for searching instead of the episode title
          if (isTV && title != null) {
            searchTitle = title;
          }
          addLog('✅ TMDB data: Title=$title, Year=$year');
        } else {
          addLog(
            '⚠️ TMDB request failed with status ${tmdbResponse.statusCode}',
          );
        }
      } catch (e) {
        addLog('⚠️ TMDB fetch error: $e');
      }

      // Step 1: Search on moviebox.ph
      addLog('🌐 Searching on moviebox.ph...');
      final searchKeyword = '$searchTitle $year'.trim();
      final searchUrl =
          'https://moviebox.ph/web/searchResult?keyword=${Uri.encodeComponent(searchKeyword)}';
      addLog('🔍 Search URL: $searchUrl');

      final searchResponse = await http
          .get(
            Uri.parse(searchUrl),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Search request timeout'),
          );

      if (searchResponse.statusCode != 200) {
        addLog('❌ Search failed with status ${searchResponse.statusCode}');
        return null;
      }

      final html = searchResponse.body;
      addLog('📄 HTML fetched, length: ${html.length} bytes');

      // Step 2: Extract subject ID from search results
      addLog('🔎 Extracting subject ID from search results...');
      final subjectId = extractSubjectId(html, searchTitle, year: year);

      if (subjectId == null) {
        addLog('❌ Subject ID not found in search results');
        addLog('⚠️ Content might not be available on moviebox.ph');
        return null;
      }

      addLog('🆔 Subject ID: $subjectId');

      // Step 3: Extract detail path
      addLog('🔎 Extracting detail path...');
      final detailPath = extractDetailPathFromHtml(
        html,
        subjectId,
        searchTitle,
      );
      final detailsUrl = detailPath != null
          ? 'https://moviebox.ph/movies/$detailPath?id=$subjectId'
          : null;

      if (detailsUrl != null) {
        addLog('🔗 Details URL: $detailsUrl');
      }

      // Step 4: Fetch download data
      addLog('⬇️ Fetching download data...');
      final downloadUrl =
          'https://moviebox.ph/wefeed-h5-bff/web/subject/download?subjectId=$subjectId&se=$seasonNumber&ep=$episodeNumber';
      addLog('📥 Download URL: $downloadUrl');

      final downloadResponse = await http
          .get(
            Uri.parse(downloadUrl),
            headers: {
              'accept': 'application/json',
              'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              'x-client-info': jsonEncode({'timezone': 'Africa/Lagos'}),
              if (detailsUrl != null) 'referer': detailsUrl,
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Download data request timeout'),
          );

      if (downloadResponse.statusCode != 200) {
        addLog(
          '❌ Download data request failed with status ${downloadResponse.statusCode}',
        );
        return null;
      }

      final downloadData =
          jsonDecode(downloadResponse.body) as Map<String, dynamic>;
      addLog('✅ Download data fetched successfully');

      // Log the full download data response
      addLog('📊 Full Download Response:');
      final responseStr = jsonEncode(downloadData);
      // Log in chunks to avoid truncation
      if (responseStr.length > 500) {
        addLog(responseStr.substring(0, 500));
      } else {
        addLog(responseStr);
      }

      // Extract and log the download/streaming links
      if (downloadData['data'] != null) {
        final data = downloadData['data'] as Map<String, dynamic>;

        // Log download links
        if (data['downloadLink'] != null) {
          addLog('🔗 Download Link: ${data['downloadLink']}');
        }

        // Log list links (streaming)
        if (data['list'] != null && (data['list'] as List).isNotEmpty) {
          final list = data['list'] as List;
          for (int i = 0; i < list.length && i < 3; i++) {
            final item = list[i] as Map<String, dynamic>;
            if (item['url'] != null) {
              addLog('🎬 Stream Link ${i + 1}: ${item['url']}');
            }
          }
          if (list.length > 3) {
            addLog('📊 Total available streams: ${list.length}');
          }
        }
      }

      addLog('🎉 Ready to stream!');

      return {
        'success': true,
        'title': movieTitle,
        'year': year,
        'subjectId': subjectId,
        'downloadData': downloadData,
      };
    } catch (e) {
      addLog('❌ Exception occurred: $e');
      return null;
    }
  }
}
