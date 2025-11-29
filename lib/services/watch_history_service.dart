import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WatchHistoryItem {
  final int movieId;
  final String title;
  final String? seasonEpisode; // Format: "S2:E4" for TV shows
  final Duration position;
  final Duration totalDuration;
  final DateTime lastWatched;
  final String? posterPath; // TMDB poster path or full URL for external sources
  final String? source; // e.g. 'tmdb', 'youtube'
  final String? externalId; // e.g. youtube video id when source == 'youtube'

  WatchHistoryItem({
    required this.movieId,
    required this.title,
    this.seasonEpisode,
    required this.position,
    required this.totalDuration,
    required this.lastWatched,
    this.posterPath,
    this.source,
    this.externalId,
  });

  int get progressPercentage {
    if (totalDuration.inSeconds == 0) return 0;
    return ((position.inSeconds / totalDuration.inSeconds) * 100).toInt();
  }

  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'title': title,
    'seasonEpisode': seasonEpisode,
    'positionMs': position.inMilliseconds,
    'totalDurationMs': totalDuration.inMilliseconds,
    'lastWatched': lastWatched.toIso8601String(),
    'posterPath': posterPath,
    'source': source,
    'externalId': externalId,
  };

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return WatchHistoryItem(
      movieId: json['movieId'] as int,
      title: json['title'] as String,
      seasonEpisode: json['seasonEpisode'] as String?,
      position: Duration(milliseconds: json['positionMs'] as int),
      totalDuration: Duration(milliseconds: json['totalDurationMs'] as int),
      lastWatched: DateTime.parse(json['lastWatched'] as String),
      posterPath: json['posterPath'] as String?,
      source: json['source'] as String?,
      externalId: json['externalId'] as String?,
    );
  }
}

class WatchHistoryService {
  static const String _key = 'watch_history';
  static const String _continueKey = 'continue_watching';

  /// Add or update watch history for a movie/show
  /// For series: removes old episode entry and adds new one (overwrites)
  /// For movies: updates existing entry or creates new one
  static Future<void> addToHistory({
    required int movieId,
    required String title,
    required Duration position,
    required Duration totalDuration,
    String? seasonEpisode,
    String? posterPath,
    String? source,
    String? externalId,
  }) async {
    try {
      print('[WatchHistoryService] ┌─ addToHistory START');
      print('[WatchHistoryService] │ movieId: $movieId');
      print('[WatchHistoryService] │ title: $title');
      print('[WatchHistoryService] │ seasonEpisode: $seasonEpisode');
      print('[WatchHistoryService] │ posterPath: $posterPath');
      print('[WatchHistoryService] │ position: ${position.inSeconds}s');
      print(
        '[WatchHistoryService] │ totalDuration: ${totalDuration.inSeconds}s',
      );

      final prefs = await SharedPreferences.getInstance();
      print('[WatchHistoryService] │ ✅ SharedPreferences initialized');

      final historyJson = prefs.getStringList(_key) ?? [];
      print('[WatchHistoryService] │ Current items: ${historyJson.length}');

      // Remove existing entry if it exists
      final beforeRemove = historyJson.length;
      historyJson.removeWhere((item) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          final matches =
              data['movieId'] == movieId &&
              data['seasonEpisode'] == seasonEpisode;
          if (matches) {
            print('[WatchHistoryService] │ 🔄 Removing old entry');
          }
          return matches;
        } catch (e) {
          print('[WatchHistoryService] │ ⚠️  Error in removeWhere: $e');
          return false;
        }
      });

      final afterRemove = historyJson.length;
      print(
        '[WatchHistoryService] │ After removal: $beforeRemove → $afterRemove items',
      );

      // Add new entry
      final item = WatchHistoryItem(
        movieId: movieId,
        title: title,
        seasonEpisode: seasonEpisode,
        position: position,
        totalDuration: totalDuration,
        lastWatched: DateTime.now(),
        posterPath: posterPath,
        source: source,
        externalId: externalId,
      );

      final jsonStr = jsonEncode(item.toJson());
      historyJson.add(jsonStr);
      print('[WatchHistoryService] │ ✅ New entry added');
      print('[WatchHistoryService] │ JSON: $jsonStr');

      // Save to SharedPreferences
      final saveSuccess = await prefs.setStringList(_key, historyJson);
      print(
        '[WatchHistoryService] │ ✅ Saved to SharedPreferences: $saveSuccess',
      );
      print('[WatchHistoryService] │ Total items now: ${historyJson.length}');

      // Verify save
      final verify = prefs.getStringList(_key);
      print(
        '[WatchHistoryService] │ ✅ Verification - items in storage: ${verify?.length}',
      );

      // Also update continue watching
      await _updateContinueWatching(movieId, item.progressPercentage);

      print('[WatchHistoryService] └─ addToHistory COMPLETE ✅');
    } catch (e) {
      print('[WatchHistoryService] └─ addToHistory FAILED ❌');
      print('[WatchHistoryService] ERROR: $e');
    }
  }

  /// Get watch history for a specific movie/show
  static Future<WatchHistoryItem?> getHistory({
    required int movieId,
    String? seasonEpisode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_key) ?? [];

      for (final item in historyJson) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          if (data['movieId'] == movieId &&
              data['seasonEpisode'] == seasonEpisode) {
            return WatchHistoryItem.fromJson(data);
          }
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (e) {
      print('Error getting watch history: $e');
      return null;
    }
  }

  /// Get all watch history items sorted by last watched
  static Future<List<WatchHistoryItem>> getAllHistory() async {
    try {
      print('[WatchHistoryService] ┌─ getAllHistory START');

      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_key) ?? [];

      print(
        '[WatchHistoryService] │ Raw items in SharedPreferences: ${historyJson.length}',
      );

      final items = <WatchHistoryItem>[];
      for (int i = 0; i < historyJson.length; i++) {
        try {
          final data = jsonDecode(historyJson[i]) as Map<String, dynamic>;
          final item = WatchHistoryItem.fromJson(data);
          items.add(item);
          print(
            '[WatchHistoryService] │ ✅ Item $i: ${item.title} (${item.seasonEpisode ?? 'Movie'}) - ${item.progressPercentage}% - posterPath: ${item.posterPath}',
          );
        } catch (e) {
          print('[WatchHistoryService] │ ⚠️  Item $i failed to parse: $e');
        }
      }

      // Sort by last watched (newest first)
      items.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));

      print('[WatchHistoryService] │ Parsed items: ${items.length}');
      print('[WatchHistoryService] └─ getAllHistory COMPLETE ✅');

      return items;
    } catch (e) {
      print('[WatchHistoryService] └─ getAllHistory FAILED ❌');
      print('[WatchHistoryService] ERROR: $e');
      return [];
    }
  }

  /// Remove item from watch history
  static Future<void> removeFromHistory({
    required int movieId,
    String? seasonEpisode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_key) ?? [];

      historyJson.removeWhere((item) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          return data['movieId'] == movieId &&
              data['seasonEpisode'] == seasonEpisode;
        } catch (_) {
          return false;
        }
      });

      await prefs.setStringList(_key, historyJson);
    } catch (e) {
      print('Error removing from watch history: $e');
    }
  }

  /// Clear all watch history
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print(
        'DEBUG: Clearing watch history - removing keys: $_key and $_continueKey',
      );

      // Remove both keys
      await prefs.remove(_key);
      await prefs.remove(_continueKey);

      // Verify they were actually removed
      final remaining = prefs.getStringList(_key);
      print('DEBUG: After clear, remaining history items: $remaining');

      if (remaining == null || remaining.isEmpty) {
        print('DEBUG: Watch history successfully cleared');
      } else {
        print(
          'WARNING: Watch history still contains items after clear: ${remaining.length}',
        );
      }
    } catch (e) {
      print('Error clearing watch history: $e');
    }
  }

  /// Update continue watching list for quick access
  static Future<void> _updateContinueWatching(int movieId, int progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final continueWatching = prefs.getStringList(_continueKey) ?? [];

      // Remove existing entry
      continueWatching.removeWhere((item) {
        try {
          final parts = item.split('|');
          return int.tryParse(parts[0]) == movieId;
        } catch (_) {
          return false;
        }
      });

      // Add if progress is less than 95%
      if (progress < 95) {
        continueWatching.add('$movieId|$progress');
      }

      await prefs.setStringList(_continueKey, continueWatching);
    } catch (e) {
      print('Error updating continue watching: $e');
    }
  }
}
