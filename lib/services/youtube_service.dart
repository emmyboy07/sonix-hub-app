import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/youtube_video.dart';

class YouTubeQualityConfig {
  final Map<String, String> videoStreams;
  final String audioStream;
  final List<String> availableQualities;
  final String defaultQuality;

  YouTubeQualityConfig({
    required this.videoStreams,
    required this.audioStream,
    required this.availableQualities,
    required this.defaultQuality,
  });
}

class YouTubeService {
  static final YouTubeService _instance = YouTubeService._internal();
  factory YouTubeService() => _instance;
  YouTubeService._internal();

  late final YoutubeExplode _yt;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _yt = YoutubeExplode();
    _initialized = true;
  }

  Future<List<YouTubeVideo>> getTrending({
    String query = 'nollywood movies',
  }) async {
    await initialize();
    try {
      final results = await _yt.search.search(query);
      return _convertSearchResults(results.take(20));
    } catch (e) {
      print('Error fetching trending YouTube: $e');
      return [];
    }
  }

  Future<List<YouTubeVideo>> searchVideos(String query) async {
    await initialize();
    try {
      // Ensure we bias the search to Nollywood content and filter results
      final effectiveQuery = query.toLowerCase().contains('nollywood')
          ? query
          : '$query nollywood';
      final results = await _yt.search.search(effectiveQuery);
      final converted = _convertSearchResults(results.take(50));

      // Strict filter: only return videos that appear to be Nollywood-related.
      // We check title, description and channel name for common Nollywood keywords.
      final filtered = converted.where((v) {
        final s = '${v.title} ${v.description} ${v.channelName}'.toLowerCase();
        final containsNol =
            s.contains('nollywood') ||
            s.contains('nigerian') ||
            s.contains('naija');
        final durationSeconds = v.duration.inSeconds;
        final isShort = durationSeconds > 0 && durationSeconds <= 60;
        return containsNol && !isShort;
      }).toList();

      return filtered;
    } catch (e) {
      print('Error searching YouTube: $e');
      return [];
    }
  }

  Future<Map<String, String>> getVideoStreams(String videoId) async {
    await initialize();
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streamMap = <String, String>{};
      for (final stream in manifest.muxed) {
        final quality = stream.videoQuality.toString().replaceAll(
          'VideoQuality.',
          '',
        );
        streamMap[quality] = stream.url.toString();
      }
      if (streamMap.isEmpty) {
        final videoStream = manifest.videoOnly.withHighestBitrate();
        if (videoStream != null) streamMap['best'] = videoStream.url.toString();
      }
      return streamMap;
    } catch (e) {
      print('Error getting video streams: $e');
      return {};
    }
  }

  List<YouTubeVideo> _convertSearchResults(Iterable<dynamic> results) {
    final videos = <YouTubeVideo>[];
    for (final result in results) {
      try {
        if (result is Video) {
          videos.add(
            YouTubeVideo(
              id: result.id.value,
              title: result.title,
              channelName: result.author,
              channelId: result.channelId.value,
              thumbnailUrl: result.thumbnails.highResUrl,
              duration: result.duration ?? Duration.zero,
              viewCount: result.engagement.viewCount ?? 0,
              uploadDate: result.uploadDate,
              description: result.description ?? '',
            ),
          );
        }
      } catch (e) {
        print('Error converting search result: $e');
        continue;
      }
    }
    return videos;
  }

  void dispose() {
    if (_initialized) {
      try {
        _yt.close();
      } catch (_) {}
      _initialized = false;
    }
  }
}
