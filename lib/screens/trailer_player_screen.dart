import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/tmdb_service.dart';
import '../config/theme.dart';

class TrailerPlayerScreen extends StatefulWidget {
  final String title;
  final int movieId;
  final String mediaType;

  const TrailerPlayerScreen({
    super.key,
    required this.title,
    required this.movieId,
    required this.mediaType,
  });

  @override
  State<TrailerPlayerScreen> createState() => _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState extends State<TrailerPlayerScreen> {
  late Future<String?> _trailerIdFuture;
  YoutubePlayerController? _youtubeController;
  String? _currentVideoId;

  @override
  void initState() {
    super.initState();
    _trailerIdFuture = _fetchTrailerId();

    // Allow rotation while the player is open.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<String?> _fetchTrailerId() async {
    try {
      final videoId = await TMDBService.getTrailerVideoId(
        widget.movieId,
        widget.mediaType == 'tv',
      );
      return videoId;
    } catch (e) {
      debugPrint('Error fetching trailer: $e');
      return null;
    }
  }

  void _initYoutubeController(String videoId) {
    if (_youtubeController != null && _currentVideoId == videoId) return;

    _youtubeController?.dispose();

    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: false,
      ),
    );

    _currentVideoId = videoId;
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.darkBlack,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryRed.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trailer',
                    style: TextStyle(
                      color: AppTheme.lightGray,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryRed,
                        ),
                        strokeWidth: 3.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Loading trailer...',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.videocam_off_rounded,
                        size: 64,
                        color: AppTheme.primaryRed,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Trailer Unavailable',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: AppTheme.lightGray,
                          fontSize: 15,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInYoutube(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch YouTube URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _trailerIdFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildError('Failed to load trailer.');
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoading();
        }

        final videoId = snapshot.data;
        if (videoId == null || videoId.isEmpty) {
          return _buildError(
            'No trailer found for this ${widget.mediaType == 'tv' ? 'TV Show' : 'Movie'}',
          );
        }

        // Initialize controller if needed
        _initYoutubeController(videoId);

        return Scaffold(
          backgroundColor: AppTheme.darkBlack,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Container(
                    color: AppTheme.darkBlack,
                    child: YoutubePlayerBuilder(
                      player: YoutubePlayer(
                        controller: _youtubeController!,
                        showVideoProgressIndicator: true,
                        onReady: () {},
                      ),
                      builder: (context, player) {
                        return Column(
                          children: [
                            // Player
                            AspectRatio(aspectRatio: 16 / 9, child: player),
                            // Title and actions
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _openInYoutube(videoId),
                                    icon: const Icon(
                                      Icons.open_in_new,
                                      color: AppTheme.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
