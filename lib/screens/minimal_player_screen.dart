import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';

class MinimalPlayerScreen extends StatefulWidget {
  final List<String> urls;
  final String title;
  const MinimalPlayerScreen({
    required this.urls,
    required this.title,
    super.key,
  });

  @override
  State<MinimalPlayerScreen> createState() => _MinimalPlayerScreenState();
}

class _MinimalPlayerScreenState extends State<MinimalPlayerScreen> {
  VideoPlayerController? _controller;
  int _currentUrlIndex = 0;
  bool _isLoading = true;
  bool _allFailed = false;
  final Set<String> _tried = {};
  bool _showControls = true;
  bool _isMuted = false;
  // Removed unused _lastTap

  @override
  void initState() {
    super.initState();
    _setLandscape();
    _tryInitializeController();
  }

  Future<void> _setLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _setPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _tryInitializeController() {
    // Skip empty or already tried URLs
    while (_currentUrlIndex < widget.urls.length &&
        (widget.urls[_currentUrlIndex].trim().isEmpty ||
            _tried.contains(widget.urls[_currentUrlIndex]))) {
      _currentUrlIndex++;
    }
    if (_currentUrlIndex >= widget.urls.length) {
      setState(() {
        _allFailed = true;
        _isLoading = false;
      });
      return;
    }
    _isLoading = true;
    _controller?.dispose();
    final url = widget.urls[_currentUrlIndex];
    _tried.add(url);
    debugPrint('Trying stream URL: $url');
    _controller = VideoPlayerController.network(url)
      ..initialize()
          .then((_) {
            setState(() {
              _isLoading = false;
            });
            _controller?.play();
          })
          .catchError((e) {
            debugPrint('Stream failed: $url, error: $e');
            // Try next stream after a short delay
            Future.delayed(const Duration(milliseconds: 500), () {
              setState(() {
                _currentUrlIndex++;
              });
              _tryInitializeController();
            });
          });
  }

  @override
  void dispose() {
    _setPortrait(); // Reset to portrait mode when leaving the player
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showControls = _showControls || _isLoading || _allFailed;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_isLoading && !_allFailed) {
            setState(() {
              _showControls = !_showControls;
            });
          }
        },
        child: Center(
          child: _allFailed
              ? const Text(
                  'All streams failed to load',
                  style: TextStyle(color: Colors.red),
                )
              : _isLoading
              ? const CircularProgressIndicator()
              : _controller != null && _controller!.value.isInitialized
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    ),
                    if (showControls)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.18),
                          child: Stack(
                            children: [
                              // Top left: back button and title
                              Positioned(
                                top: 24,
                                left: 16,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_back,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 4,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Top right: live icon
                              Positioned(
                                top: 32,
                                right: 24,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      255,
                                      255,
                                      21,
                                      4,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.circle,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'LIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Bottom right: mute/unmute
                              Positioned(
                                bottom: 32,
                                right: 32,
                                child: IconButton(
                                  icon: Icon(
                                    _isMuted
                                        ? Icons.volume_off
                                        : Icons.volume_up,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isMuted = !_isMuted;
                                      _controller?.setVolume(
                                        _isMuted ? 0.0 : 1.0,
                                      );
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              : const Text(
                  'Failed to load stream',
                  style: TextStyle(color: Colors.red),
                ),
        ),
      ),
    );
  }
}
