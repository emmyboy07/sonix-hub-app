import 'package:flutter/material.dart';
import '../models/youtube_video.dart';
import '../services/youtube_service.dart';
import '../services/watch_history_service.dart';
import '../config/theme.dart';
import 'player/universal_player_screen.dart';

class YouTubeDetailsScreen extends StatefulWidget {
  final YouTubeVideo video;
  const YouTubeDetailsScreen({super.key, required this.video});

  @override
  State<YouTubeDetailsScreen> createState() => _YouTubeDetailsScreenState();
}

class _YouTubeDetailsScreenState extends State<YouTubeDetailsScreen> {
  bool _loading = false;
  String? _error;
  WatchHistoryItem? _watchHistory;

  @override
  void initState() {
    super.initState();
    _loadWatchHistory();
  }

  int _stableIdFromString(String s) {
    // Deterministic small int derived from id string for WatchHistory
    var acc = 0;
    for (var i = 0; i < s.length; i++) {
      acc = (acc * 31 + s.codeUnitAt(i)) & 0x7fffffff;
    }
    return acc;
  }

  Future<void> _loadWatchHistory() async {
    try {
      final movieId = _stableIdFromString(widget.video.id);
      final history = await WatchHistoryService.getHistory(movieId: movieId);
      if (mounted && history != null && history.progressPercentage < 95) {
        setState(() {
          _watchHistory = history;
        });
      }
    } catch (e) {
      print('Error loading watch history: $e');
    }
  }

  Future<void> _play() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final streams = await YouTubeService().getVideoStreams(widget.video.id);
      if (streams.isEmpty) {
        setState(() {
          _error = 'No playable streams found';
          _loading = false;
        });
        return;
      }

      // Pick best stream (first) as fallback
      final streamUrl = streams.values.first;

      final movieId = _stableIdFromString(widget.video.id);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UniversalPlayerScreen(
            title: widget.video.title,
            streamUrl: streamUrl,
            headers: const {},
            movieId: movieId,
            posterPath: widget.video.thumbnailUrl,
            source: 'youtube',
            externalId: widget.video.id,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBlack,
        elevation: 0,
        title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                v.thumbnailUrl,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: AppTheme.mediumBlack,
                  child: const Icon(Icons.play_circle_outline, size: 64),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              v.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              v.channelName,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            if (v.uploadDate != null)
              Text(
                'Uploaded: ${v.uploadDate!.year}-${v.uploadDate!.month.toString().padLeft(2, '0')}-${v.uploadDate!.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _play,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      _loading
                          ? 'Loading...'
                          : (_watchHistory != null ? 'Resume' : 'Play'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: AppTheme.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            Text(
              'Description',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              v.description.isNotEmpty ? v.description : 'No description',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
