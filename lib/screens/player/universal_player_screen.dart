import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import '../../utils/app_theme.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/watch_history_service.dart';
import '../../utils/subtitle_import_helper.dart';

class PlaybackSource {
  final String url;
  final Map<String, String> headers;
  final String? label; // e.g., 1080p, 720p, Auto
  const PlaybackSource({required this.url, required this.headers, this.label});
}

class SubtitleSource {
  final String url;
  final Map<String, String> headers;
  final String? label; // e.g., English, Bangla
  final String? lang;
  final String? inlineText; // optional inline VTT/SRT content
  const SubtitleSource({
    required this.url,
    required this.headers,
    this.label,
    this.lang,
    this.inlineText,
  });
}

class _Cue {
  final int startMs;
  final int endMs;
  final String text;
  const _Cue({required this.startMs, required this.endMs, required this.text});
}

class UniversalPlayerScreen extends StatefulWidget {
  final String title;
  final String streamUrl;
  final Map<String, String>? headers;
  final List<PlaybackSource>? alternateSources;
  final List<SubtitleSource>? subtitles;
  final int? movieId; // For tracking watch history
  final String? seasonEpisode; // Format: "S2:E4" for TV shows
  final String? posterPath; // For storing poster image path in history
  final String? source; // optional source identifier, e.g. 'youtube'
  final String? externalId; // optional external id, e.g. youtube video id

  const UniversalPlayerScreen({
    super.key,
    required this.title,
    required this.streamUrl,
    this.headers,
    this.alternateSources,
    this.subtitles,
    this.movieId,
    this.seasonEpisode,
    this.posterPath,
    this.source,
    this.externalId,
  });

  @override
  State<UniversalPlayerScreen> createState() => _UniversalPlayerScreenState();
}

class _UniversalPlayerScreenState extends State<UniversalPlayerScreen> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _error = false;
  String? _errorMsg;
  bool _showControls = true;
  bool _isBuffering = false;
  bool _shouldBePlayingBeforeBuffer = false;
  Duration? _lastReportedPosition;
  double _playbackSpeed = 1.0;
  double _aspect = 16 / 9; // 0.0 means fill
  late final List<PlaybackSource> _sources;
  int _currentSourceIndex = 0;
  bool _listening = false;
  bool _switching = false;
  List<PlaybackSource> _hlsVariants = [];
  List<SubtitleSource> _subtitles = [];
  int _selectedSubtitle = -1; // -1 = Off
  String _subtitleText = '';
  Timer? _posTimer;
  bool _wasPlaying = false;
  double _volume = 1.0;
  double _lastNonZeroVolume = 1.0;
  double _dim = 0.0; // 0.0 bright, increases to dark overlay
  bool _locked = false;
  double _brightness = 1.0;
  bool _canSystemBrightness = false;
  double _dragStartBrightness = 1.0;
  double _dragStartVolume = 1.0;
  double _dragAccumDy = 0.0;
  bool _showBrightnessHUD = false;
  bool _showVolumeHUD = false;
  bool _seekFlashLeft = false;
  bool _seekFlashRight = false;
  Timer? _brightnessHudTimer;
  Timer? _volumeHudTimer;
  Timer? _seekFlashLeftTimer;
  Timer? _seekFlashRightTimer;
  StreamSubscription<double>? _volStream;
  double _subtitleScale = 1.0;
  double _subtitleBottom = 80.0;
  int _subtitleOffsetMs = 0;
  // Subtitle gesture helpers
  double _subDragStartBottom = 0.0;
  double _subDragStartScale = 1.0;
  double _subAccumDy = 0.0;
  bool _showSubtitleHUD = false;
  Timer? _subtitleHudTimer;
  String _activeSettingsSection = ''; // '', 'playback', 'resolution', 'display'

  // Realtime UI bindings for settings sheet
  final ValueNotifier<double> _subScaleVN = ValueNotifier<double>(1.0);
  final ValueNotifier<double> _subBottomVN = ValueNotifier<double>(80.0);
  final ValueNotifier<int> _subOffsetVN = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _enterFullscreen();
    _initBrightness();
    _initSystemVolume();
    _loadSubtitlePrefs();
    _sources = [
      PlaybackSource(
        url: widget.streamUrl,
        headers: widget.headers ?? const <String, String>{},
        label: null,
      ),
      ...?widget.alternateSources,
    ];
    // Initialize subtitles from widget if provided
    if (widget.subtitles != null && widget.subtitles!.isNotEmpty) {
      _subtitles = List<SubtitleSource>.from(widget.subtitles!);
      _selectedSubtitle = 0;
      // async load first subtitle track
      Future.microtask(() => _loadSubtitleTrack(0));
    }
    Future.microtask(() async {
      // Load saved watch position if available
      Duration? resumeAt;
      if (widget.movieId != null) {
        final history = await WatchHistoryService.getHistory(
          movieId: widget.movieId!,
          seasonEpisode: widget.seasonEpisode,
        );
        if (history != null && history.progressPercentage < 95) {
          resumeAt = history.position;
        }
      }

      final idx = await _preselectPlayableIndex(max: 4) ?? 0;
      if (!mounted) return;
      await _init(index: idx, resumeAt: resumeAt);
    });
  }

  void _enterFullscreen() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  Future<void> _seekAndResume(Duration position) async {
    try {
      final wasPlaying = _controller?.value.isPlaying ?? false;
      await _controller?.seekTo(position);
      if (wasPlaying) {
        await Future.delayed(const Duration(milliseconds: 100));
        await _controller?.play();
      }
    } catch (_) {}
  }

  Future<void> _init({required int index, Duration? resumeAt}) async {
    try {
      final src = _sources[index];
      _controller?.dispose();
      _listening = false;
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(src.url),
        httpHeaders: src.headers,
      );
      await _controller!.initialize();
      await _controller!.setVolume(_volume);
      if (resumeAt != null &&
          resumeAt > Duration.zero &&
          resumeAt < _controller!.value.duration) {
        await _controller!.seekTo(resumeAt);
      }
      await _controller!.setPlaybackSpeed(_playbackSpeed);
      await _controller!.play();
      _attachListenerOnce();
      // In background, if HLS master, parse variants for resolution selection
      _maybeLoadHlsVariants(src);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = false;
        _currentSourceIndex = index;
      });
    } catch (e) {
      if (!mounted) return;
      // Try next source if available
      final next = index + 1;
      if (next < _sources.length) {
        setState(() {
          _loading = true;
          _error = false;
          _currentSourceIndex = next;
        });
        await _init(index: next, resumeAt: resumeAt);
        return;
      }
      setState(() {
        _loading = false;
        _error = true;
        _errorMsg = e.toString();
      });
    }
  }

  void _attachListenerOnce() {
    if (_controller == null || _listening) return;
    _listening = true;
    _controller!.addListener(() async {
      final v = _controller!.value;

      // Detect buffering: buffered position is behind current position
      bool isBuffering = false;
      if (v.isInitialized) {
        if (v.buffered.isEmpty || (v.buffered.last.end < v.position)) {
          isBuffering = true;
        }
      }

      // Track playback state before buffering
      if (!isBuffering && v.isPlaying) {
        _shouldBePlayingBeforeBuffer = true;
      }

      // FORCE playback during buffering - never allow pause
      if (isBuffering && _shouldBePlayingBeforeBuffer && !v.isPlaying) {
        try {
          await _controller!.play();
        } catch (_) {}
        setState(() => _isBuffering = true);
        return; // Skip other logic
      }

      // Clear buffering flag when done
      if (!isBuffering && _isBuffering) {
        setState(() => _isBuffering = false);
      }

      // Normal pause/play tracking (only when NOT buffering)
      if (isBuffering) {
        setState(() => _isBuffering = true);
      } else if (v.isPlaying != _wasPlaying) {
        _wasPlaying = v.isPlaying;
        if (!v.isPlaying) {
          _shouldBePlayingBeforeBuffer = false; // User explicitly paused
        }
        _ensurePosTicker();
      }

      if (v.hasError && !_switching) {
        _switching = true;
        final next = (_currentSourceIndex + 1);
        if (next < _sources.length) {
          setState(() {
            _loading = true;
            _error = false;
          });
          await _init(index: next);
        } else {
          setState(() {
            _error = true;
            _errorMsg = v.errorDescription;
          });
        }
        _switching = false;
      }
      // Update subtitles
      _updateSubtitleForPosition(v.position);
    });
  }

  void _ensurePosTicker() {
    final playing = _controller?.value.isPlaying ?? false;
    if (playing) {
      _posTimer ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) {
          _posTimer?.cancel();
          _posTimer = null;
          return;
        }
        final c = _controller;
        if (c == null || !c.value.isInitialized) return;
        if (!c.value.isPlaying) {
          _lastReportedPosition = null;
          return;
        }

        // Check buffering: if position hasn't changed between checks while playing, we're buffering
        final currentPos = c.value.position;
        bool isBuffering = false;

        // Method 1: Check buffered range
        if (c.value.buffered.isNotEmpty) {
          isBuffering = c.value.buffered.last.end < c.value.position;
        } else {
          isBuffering = true; // Nothing buffered
        }

        // Method 2: Check if position stalled (more reliable)
        if (_lastReportedPosition != null &&
            _lastReportedPosition == currentPos &&
            c.value.isPlaying) {
          isBuffering = true;
          print(
            '[Player] Position stalled at $currentPos - marking as buffering',
          );
        }

        _lastReportedPosition = currentPos;

        if (isBuffering != _isBuffering) {
          print(
            '[Player] Buffering state: $isBuffering (position: $currentPos, stalled: ${_lastReportedPosition == currentPos})',
          );
          setState(() => _isBuffering = isBuffering);
        } else {
          setState(() {});
        }
      });
    } else {
      _posTimer?.cancel();
      _posTimer = null;
      _lastReportedPosition = null;
    }
  }

  Future<int?> _preselectPlayableIndex({int max = 4}) async {
    final n = _sources.length;
    final limit = n < max ? n : max;
    for (int i = 0; i < limit; i++) {
      final s = _sources[i];
      final ok = await _headOk(s.url, s.headers);
      if (ok) return i;
    }
    return null;
  }

  Future<bool> _headOk(String url, Map<String, String> headers) async {
    try {
      final h = Map<String, String>.from(headers);
      h.putIfAbsent(
        'Accept',
        () => url.toLowerCase().contains('.m3u8')
            ? 'application/x-mpegURL,video/*;q=0.9,*/*;q=0.8'
            : 'video/*;q=0.9,*/*;q=0.8',
      );
      h['Cache-Control'] = 'no-cache, no-store, must-revalidate';
      h['Pragma'] = 'no-cache';
      h['Expires'] = '0';
      h['X-Playback-Nonce'] = DateTime.now().millisecondsSinceEpoch.toString();
      final resp = await http
          .head(Uri.parse(url), headers: h)
          .timeout(const Duration(seconds: 2));
      if (resp.statusCode == 200 || resp.statusCode == 206) return true;
      if (resp.statusCode >= 200 && resp.statusCode < 300) return true;
    } catch (_) {}
    // Some hosts block HEAD. Try a tiny ranged GET to validate playability quickly.
    try {
      final h = Map<String, String>.from(headers);
      h['Range'] = 'bytes=0-1';
      h.putIfAbsent('Accept', () => 'video/*;q=0.9,*/*;q=0.8');
      h['Cache-Control'] = 'no-cache, no-store, must-revalidate';
      h['Pragma'] = 'no-cache';
      h['Expires'] = '0';
      h['X-Playback-Nonce'] = DateTime.now().millisecondsSinceEpoch.toString();
      final resp = await http
          .get(Uri.parse(url), headers: h)
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 206 || resp.statusCode == 200) return true;
      if (resp.statusCode >= 200 && resp.statusCode < 300) return true;
    } catch (_) {}
    return false;
  }

  // ===== Subtitles =====
  void setSubtitleSources(List<SubtitleSource> subs) {
    print('[UniversalPlayer] === RECEIVED SUBTITLES ===');
    print('[UniversalPlayer] Total subtitles: ${subs.length}');
    for (int i = 0; i < subs.length; i++) {
      final sub = subs[i];
      final hasInline = sub.inlineText != null && sub.inlineText!.isNotEmpty;
      final inlineSize = hasInline
          ? ' (inline: ${sub.inlineText!.length} bytes)'
          : '';
      print(
        '[UniversalPlayer] [$i] Label: ${sub.label}, Lang: ${sub.lang}, URL: ${sub.url.substring(0, 60)}...$inlineSize',
      );
    }
    print('[UniversalPlayer] === END RECEIVED SUBTITLES ===');
    _subtitles = subs;
    _selectedSubtitle = subs.isNotEmpty ? 0 : -1;
    if (_selectedSubtitle >= 0) {
      _loadSubtitleTrack(_selectedSubtitle);
    } else {
      _subtitleText = '';
    }
  }

  Future<void> _loadSubtitleTrack(int index) async {
    print('[UniversalPlayer] Loading subtitle track index: $index');
    if (index < 0 || index >= _subtitles.length) {
      print('[UniversalPlayer] Invalid subtitle index, turning off subtitles');
      setState(() {
        _selectedSubtitle = -1;
        _subtitleText = '';
      });
      return;
    }
    final sub = _subtitles[index];
    print(
      '[UniversalPlayer] Loading subtitle: Label=${sub.label}, Lang=${sub.lang}',
    );
    try {
      // Use inline text directly if available
      if (sub.inlineText != null && sub.inlineText!.isNotEmpty) {
        final text = sub.inlineText!;
        final isVtt = _looksLikeVtt(text);
        print(
          '[UniversalPlayer] Using inline text (${text.length} bytes), format: ${isVtt ? 'VTT' : 'SRT'}',
        );
        _cues = isVtt ? _parseVtt(text) : _parseSrt(text);
        _normalizeCuesIfNeeded();
        print(
          '[UniversalPlayer] Parsed ${_cues.length} subtitle cues from inline text',
        );
        setState(() {
          _selectedSubtitle = index;
        });
        return;
      }
      // Ignore network fetch for pseudo inline URLs if no inlineText
      if (sub.url.startsWith('inline:')) {
        print('[UniversalPlayer] Skipping inline pseudo URL without content');
        return; // nothing to load
      }
      // Load from assets: prefix 'asset:' e.g. asset:assets/subtitles/file.vtt
      if (sub.url.startsWith('asset:')) {
        final assetPath = sub.url.substring('asset:'.length);
        final text = await rootBundle.loadString(assetPath, cache: false);
        final isVtt = _looksLikeVtt(text);
        _cues = isVtt ? _parseVtt(text) : _parseSrt(text);
        _normalizeCuesIfNeeded();
        setState(() {
          _selectedSubtitle = index;
        });
        return;
      }
      // Load from local file path on device: file:// or absolute path
      if (sub.url.startsWith('file://') || sub.url.startsWith('/')) {
        final p = sub.url.startsWith('file://')
            ? Uri.parse(sub.url).toFilePath()
            : sub.url;
        final bytes = await File(p).readAsBytes();
        final text = utf8.decode(bytes, allowMalformed: true);
        final isVtt = _looksLikeVtt(text);
        _cues = isVtt ? _parseVtt(text) : _parseSrt(text);
        _normalizeCuesIfNeeded();
        setState(() {
          _selectedSubtitle = index;
        });
        return;
      }
      // Handle HLS subtitle playlists
      if (sub.url.toLowerCase().contains('.m3u8')) {
        final ok = await _loadHlsSubtitlePlaylist(sub);
        if (ok) {
          setState(() {
            _selectedSubtitle = index;
          });
          return;
        }
      }

      final text = await _httpGetWithHeaderAttempts(sub.url, sub.headers);
      if (text != null) {
        final isVtt = _looksLikeVtt(text);
        print(
          '[UniversalPlayer] Fetched subtitle from URL, size: ${text.length} bytes, format: ${isVtt ? 'VTT' : 'SRT'}',
        );
        _cues = isVtt ? _parseVtt(text) : _parseSrt(text);
        _normalizeCuesIfNeeded();
        print(
          '[UniversalPlayer] Parsed ${_cues.length} subtitle cues from URL',
        );
        setState(() {
          _selectedSubtitle = index;
        });
      } else {
        print('[UniversalPlayer] Failed to fetch subtitle from URL');
      }
    } catch (_) {}
  }

  List<_Cue> _cues = [];
  void _updateSubtitleForPosition(Duration pos) {
    if (_cues.isEmpty) {
      if (_subtitleText.isNotEmpty) {
        setState(() {
          _subtitleText = '';
        });
      }
      return;
    }
    final t = pos.inMilliseconds + _subtitleOffsetMs;
    // binary search could be used; we keep it simple
    _Cue? found;
    for (final c in _cues) {
      if (t >= c.startMs && t <= c.endMs) {
        found = c;
        break;
      }
    }
    final newText = found?.text ?? '';
    if (newText != _subtitleText) {
      setState(() {
        _subtitleText = newText;
      });
    }
  }

  String _sanitizeSubtitleText(String s) {
    var t = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    t = t.replaceAll(RegExp(r'</?i>', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'</?b>', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'</?u>', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'<font[^>]*>', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'</font>', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'<[^>]+>'), '');
    t = t
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    t = t.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    });
    t = t.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    });
    return t;
  }

  bool _isRtl(String s) {
    return RegExp(r'[\u0590-\u05FF\u0600-\u06FF]').hasMatch(s);
  }

  List<_Cue> _parseSrt(String s) {
    final lines = s.replaceAll('\r', '').split('\n');
    final cues = <_Cue>[];
    int i = 0;
    while (i < lines.length) {
      // skip index line
      if (lines[i].trim().isEmpty) {
        i++;
        continue;
      }
      i++;
      if (i >= lines.length) break;
      final times = lines[i];
      final m = RegExp(
        r"(\d{2}:\d{2}:\d{2},\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2},\d{3})",
      ).firstMatch(times);
      i++;
      if (m == null) continue;
      final start = _parseTimeSrt(m.group(1)!);
      final end = _parseTimeSrt(m.group(2)!);
      final buf = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        buf.add(lines[i]);
        i++;
      }
      final raw = buf.join('\n');
      cues.add(
        _Cue(startMs: start, endMs: end, text: _sanitizeSubtitleText(raw)),
      );
      // skip empty line
      while (i < lines.length && lines[i].trim().isEmpty) {
        i++;
      }
    }
    return cues;
  }

  List<_Cue> _parseVtt(String s) {
    final body = s.replaceAll('\r', '').split('\n');
    final cues = <_Cue>[];
    int i = 0;
    // skip WEBVTT header if present
    if (body.isNotEmpty && body[0].toUpperCase().contains('WEBVTT')) {
      i++;
    }
    while (i < body.length) {
      if (body[i].trim().isEmpty) {
        i++;
        continue;
      }
      // optional cue id line
      if (!body[i].contains('-->') && i + 1 < body.length) i++;
      if (i >= body.length) break;
      final times = body[i];
      final m = RegExp(
        r"(\d{2}:\d{2}:\d{2}\.\d{3}|\d{2}:\d{2}\.\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}\.\d{3}|\d{2}:\d{2}\.\d{3})",
      ).firstMatch(times);
      i++;
      if (m == null) continue;
      final start = _parseTimeVtt(m.group(1)!);
      final end = _parseTimeVtt(m.group(2)!);
      final buf = <String>[];
      while (i < body.length && body[i].trim().isNotEmpty) {
        buf.add(body[i]);
        i++;
      }
      final raw = buf.join('\n');
      cues.add(
        _Cue(startMs: start, endMs: end, text: _sanitizeSubtitleText(raw)),
      );
      while (i < body.length && body[i].trim().isEmpty) {
        i++;
      }
    }
    return cues;
  }

  void _normalizeCuesIfNeeded() {
    if (_cues.isEmpty) return;
    int minStart = _cues.first.startMs;
    for (final c in _cues) {
      if (c.startMs < minStart) minStart = c.startMs;
    }
    // If subtitles start very late (e.g., due to X-TIMESTAMP-MAP), normalize to start ~0
    if (minStart > 300000) {
      // > 5 minutes
      final shift = minStart;
      _cues = _cues
          .map(
            (c) => _Cue(
              startMs: c.startMs - shift,
              endMs: c.endMs - shift,
              text: c.text,
            ),
          )
          .toList();
    }
  }

  int _parseTimeSrt(String t) {
    final p = t.split(',');
    final hms = p[0].split(':');
    final ms = int.tryParse(p[1]) ?? 0;
    final h = int.tryParse(hms[0]) ?? 0;
    final m = int.tryParse(hms[1]) ?? 0;
    final s = int.tryParse(hms[2]) ?? 0;
    return ((h * 3600 + m * 60 + s) * 1000) + ms;
  }

  int _parseTimeVtt(String t) {
    final parts = t.split(':');
    int h = 0, m = 0;
    double s = 0.0;
    if (parts.length == 3) {
      h = int.parse(parts[0]);
      m = int.parse(parts[1]);
      s = double.parse(parts[2]);
    } else if (parts.length == 2) {
      m = int.parse(parts[0]);
      s = double.parse(parts[1]);
    }
    return ((h * 3600 + m * 60) * 1000) + (s * 1000).round();
  }

  Future<String?> _httpGetWithHeaderAttempts(
    String url,
    Map<String, String> baseHeaders,
  ) async {
    final attempts = <Map<String, String>>[];
    final base = Map<String, String>.from(baseHeaders);
    attempts.add(base);
    final noOrigin = Map<String, String>.from(base)..remove('Origin');
    attempts.add(noOrigin);
    final noUA = Map<String, String>.from(base)..remove('User-Agent');
    attempts.add(noUA);
    final desktop = Map<String, String>.from(base)
      ..update(
        'User-Agent',
        (_) =>
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
        ifAbsent: () =>
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
      );
    attempts.add(desktop);

    for (final h in attempts) {
      try {
        final resp = await http.get(Uri.parse(url), headers: h);
        if (resp.statusCode >= 200 &&
            resp.statusCode < 300 &&
            resp.bodyBytes.isNotEmpty) {
          try {
            return utf8.decode(resp.bodyBytes, allowMalformed: true);
          } catch (_) {
            return String.fromCharCodes(resp.bodyBytes);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  bool _looksLikeVtt(String text) {
    final head = text.trimLeft();
    // WEBVTT header is definitive
    if (head.startsWith('WEBVTT')) return true;

    // Check timestamp format: VTT uses dots (00:00:00.000), SRT uses commas (00:00:00,000)
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      // Look for timestamp lines with --> separator
      if (trimmed.contains('-->')) {
        // VTT timestamps use dots: HH:MM:SS.mmm or MM:SS.mmm
        if (RegExp(
          r'\d{2}:\d{2}[:\d]*\.\d{3}\s*-->\s*\d{2}:\d{2}[:\d]*\.\d{3}',
        ).hasMatch(trimmed)) {
          print('[FORMAT DETECTION] Detected VTT format (dot timestamps)');
          return true;
        }
        // SRT timestamps use commas: HH:MM:SS,mmm
        if (RegExp(
          r'\d{2}:\d{2}:\d{2},\d{3}\s*-->\s*\d{2}:\d{2}:\d{2},\d{3}',
        ).hasMatch(trimmed)) {
          print('[FORMAT DETECTION] Detected SRT format (comma timestamps)');
          return false;
        }
      }
    }

    // Fallback: default to SRT
    print('[FORMAT DETECTION] Could not detect format, defaulting to SRT');
    return false;
  }

  Future<bool> _loadHlsSubtitlePlaylist(SubtitleSource sub) async {
    try {
      final playlist = await _httpGetWithHeaderAttempts(sub.url, sub.headers);
      if (playlist == null || playlist.isEmpty) return false;
      final base = Uri.parse(sub.url);
      final lines = playlist.replaceAll('\r', '').split('\n');
      // Try to find an external VTT referenced via URI="..."
      for (final line in lines) {
        if (line.startsWith('#') && line.contains('URI="')) {
          final m = RegExp(r'URI="([^"]+)"').firstMatch(line);
          if (m != null) {
            final uri = base.resolve(m.group(1)!).toString();
            final vtt = await _httpGetWithHeaderAttempts(uri, sub.headers);
            if (vtt != null && vtt.isNotEmpty && _looksLikeVtt(vtt)) {
              _cues = _parseVtt(vtt);
              _normalizeCuesIfNeeded();
              return true;
            }
          }
        }
      }
      // Else, try first non-comment line as segment/VTT
      for (final line in lines) {
        final t = line.trim();
        if (t.isEmpty || t.startsWith('#')) continue;
        final uri = base.resolve(t).toString();
        final body = await _httpGetWithHeaderAttempts(uri, sub.headers);
        if (body != null && body.isNotEmpty && _looksLikeVtt(body)) {
          _cues = _parseVtt(body);
          _normalizeCuesIfNeeded();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  // ===== HLS Variants =====
  Future<void> _maybeLoadHlsVariants(PlaybackSource src) async {
    if (!src.url.toLowerCase().contains('.m3u8')) return;
    try {
      final resp = await http.get(Uri.parse(src.url), headers: src.headers);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final text = resp.body;
        if (text.contains('#EXT-X-STREAM-INF')) {
          final base = Uri.parse(src.url);
          final variants = <PlaybackSource>[];
          final lines = text.split('\n');
          for (int i = 0; i < lines.length - 1; i++) {
            final line = lines[i];
            if (line.startsWith('#EXT-X-STREAM-INF')) {
              String? label;
              final resM = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
              if (resM != null) {
                label = '${resM.group(2)}p';
              }
              final next = lines[i + 1].trim();
              if (next.isNotEmpty && !next.startsWith('#')) {
                final vUrl = base.resolve(next).toString();
                variants.add(
                  PlaybackSource(url: vUrl, headers: src.headers, label: label),
                );
              }
            }
          }
          if (variants.isNotEmpty) {
            setState(() {
              _hlsVariants = variants;
            });
            // Optionally add to _sources for manual switch
            for (final v in variants) {
              if (!_sources.any((s) => s.url == v.url)) {
                _sources.add(v);
              }
            }
          }
        }
        // Parse HLS subtitle renditions (EXT-X-MEDIA:TYPE=SUBTITLES)
        if (text.contains('#EXT-X-MEDIA') && text.contains('TYPE=SUBTITLES')) {
          final base = Uri.parse(src.url);
          final newSubs = <SubtitleSource>[];
          final mediaLines = text
              .split('\n')
              .where(
                (l) =>
                    l.startsWith('#EXT-X-MEDIA') &&
                    l.contains('TYPE=SUBTITLES'),
              );
          for (final line in mediaLines) {
            String? uri;
            String? name;
            String? lang;
            final uriM = RegExp(r'URI="([^"]+)"').firstMatch(line);
            if (uriM != null) uri = uriM.group(1);
            final nameM = RegExp(r'NAME="([^"]+)"').firstMatch(line);
            if (nameM != null) name = nameM.group(1);
            final langM = RegExp(r'LANGUAGE="([^"]+)"').firstMatch(line);
            if (langM != null) lang = langM.group(1);
            if (uri != null && uri.isNotEmpty) {
              final abs = base.resolve(uri).toString();
              if (!_subtitles.any((s) => s.url == abs)) {
                newSubs.add(
                  SubtitleSource(
                    url: abs,
                    headers: src.headers,
                    label: name ?? lang,
                    lang: lang,
                  ),
                );
              }
            }
          }
          if (newSubs.isNotEmpty) {
            setState(() {
              _subtitles.addAll(newSubs);
            });
            if (_selectedSubtitle == -1) {
              // auto-load first HLS subtitle if none selected yet
              _loadSubtitleTrack(0);
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    try {
      _posTimer?.cancel();
    } catch (_) {}
    try {
      _brightnessHudTimer?.cancel();
    } catch (_) {}
    try {
      _volumeHudTimer?.cancel();
    } catch (_) {}
    try {
      _seekFlashLeftTimer?.cancel();
    } catch (_) {}
    try {
      _seekFlashRightTimer?.cancel();
    } catch (_) {}
    try {
      _volStream?.cancel();
    } catch (_) {}

    // Save watch history before disposing - this MUST complete before disposing
    try {
      if (widget.movieId != null && _controller != null) {
        final position = _controller!.value.position;
        final duration = _controller!.value.duration;

        print(
          '═══════════════════════════════════════════════════════════════',
        );
        print('[DISPOSE] Watch History Save Started');
        print('movieId: ${widget.movieId}');
        print('seasonEpisode: ${widget.seasonEpisode}');
        print('title: ${widget.title}');
        print('position: ${position.inSeconds}s');
        print('duration: ${duration.inSeconds}s');

        // Only save if at least 10 seconds have passed
        if (position.inSeconds > 10) {
          print('[DISPOSE] ✅ Position >10s, saving to history...');
          print('[DISPOSE] posterPath being saved: ${widget.posterPath}');
          await WatchHistoryService.addToHistory(
            movieId: widget.movieId!,
            title: widget.title,
            position: position,
            totalDuration: duration,
            seasonEpisode: widget.seasonEpisode,
            posterPath: widget.posterPath,
            source: widget.source,
            externalId: widget.externalId,
          );
          print('[DISPOSE] ✅ Watch history saved successfully!');
        } else {
          print(
            '[DISPOSE] ❌ Position <10s (${position.inSeconds}s), skipping save',
          );
        }
        print(
          '═══════════════════════════════════════════════════════════════',
        );
      } else {
        print(
          '[DISPOSE] ❌ Cannot save: movieId=${widget.movieId}, hasController=${_controller != null}',
        );
      }
    } catch (e) {
      print('[DISPOSE] ❌ ERROR: Failed to save watch history: $e');
    }

    try {
      _controller?.dispose();
    } catch (_) {}
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _togglePlay() async {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
    _ensurePosTicker();
    setState(() {});
  }

  Future<void> _setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    if (_volume > 0.0) _lastNonZeroVolume = _volume;
    try {
      await FlutterVolumeController.setVolume(_volume);
    } catch (_) {}
    await _controller?.setVolume(1.0);
    setState(() {});
  }

  Future<void> _initBrightness() async {
    try {
      await ScreenBrightness.instance.setAnimate(true);
      final canSys = await ScreenBrightness.instance.canChangeSystemBrightness;
      final cur = await ScreenBrightness.instance.current;
      if (!mounted) return;
      setState(() {
        _canSystemBrightness = canSys;
        _brightness = cur.clamp(0.0, 1.0);
      });
    } catch (_) {}
  }

  Future<void> _setBrightness(double v) async {
    final b = v.clamp(0.0, 1.0);
    try {
      if (_canSystemBrightness) {
        await ScreenBrightness.instance.setSystemScreenBrightness(b);
      } else {
        await ScreenBrightness.instance.setApplicationScreenBrightness(b);
      }
    } catch (_) {}
    setState(() {
      _brightness = b;
      _dim = 0.0;
    });
  }

  Future<void> _initSystemVolume() async {
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      final v = await FlutterVolumeController.getVolume();
      if (!mounted) return;
      final newV = ((v ?? _volume).clamp(0.0, 1.0)).toDouble();
      setState(() {
        _volume = newV;
        _lastNonZeroVolume = _volume == 0 ? 1.0 : _volume;
      });
      _volStream = FlutterVolumeController.addListener((val) {
        if (!mounted) return;
        final nv = (val.clamp(0.0, 1.0)).toDouble();
        setState(() {
          _volume = nv;
        });
      });
    } catch (_) {}
  }

  Future<void> _loadSubtitlePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _subtitleScale = p.getDouble('sub_scale') ?? 1.0;
        _subtitleBottom = p.getDouble('sub_bottom') ?? 80.0;
        _subtitleOffsetMs = p.getInt('sub_offset_ms') ?? 0;
      });
      _subScaleVN.value = _subtitleScale;
      _subBottomVN.value = _subtitleBottom;
      _subOffsetVN.value = _subtitleOffsetMs;
    } catch (_) {}
  }

  Future<void> _saveSubtitlePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('sub_scale', _subtitleScale);
      await p.setDouble('sub_bottom', _subtitleBottom);
      await p.setInt('sub_offset_ms', _subtitleOffsetMs);
    } catch (_) {}
  }

  void _toggleMute() async {
    if (_volume > 0) {
      final prev = _volume;
      await _setVolume(0.0);
      _lastNonZeroVolume = prev;
    } else {
      await _setVolume(_lastNonZeroVolume == 0 ? 1.0 : _lastNonZeroVolume);
    }
  }

  void _changeAspect() {
    setState(() {
      if (_aspect == 16 / 9) {
        _aspect = 21 / 10;
      } else if (_aspect == 21 / 10)
        _aspect = 0.0; // Fill
      else
        _aspect = 16 / 9;
    });
  }

  void _openSettings() async {
    _activeSettingsSection = '';
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black45,
        pageBuilder: (ctx, animation, secondaryAnimation) => StatefulBuilder(
          builder: (builderCtx, builderSetState) =>
              _buildSettingsSheet(ctx, animation, builderSetState),
        ),
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) =>
            child,
      ),
    );
  }

  Widget _buildSettingsSheet(
    BuildContext ctx,
    Animation<double> animation,
    StateSetter builderSetState,
  ) {
    return Material(
      color: Colors.transparent,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.30,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF121212).withOpacity(0.92),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              },
              child: _activeSettingsSection.isEmpty
                  ? _buildSettingsMainMenu(ctx, builderSetState)
                  : _buildSettingsSubmenu(
                      ctx,
                      _activeSettingsSection,
                      builderSetState,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsMainMenu(BuildContext ctx, StateSetter builderSetState) {
    return Column(
      key: const ValueKey('main'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(ctx),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMainMenuOption(
                    ctx,
                    'Playback',
                    () => builderSetState(
                      () => _activeSettingsSection = 'playback',
                    ),
                  ),
                  Divider(
                    color: Colors.white.withOpacity(0.08),
                    height: 20,
                    thickness: 1,
                  ),
                  _buildMainMenuOption(
                    ctx,
                    'Resolution',
                    () => builderSetState(
                      () => _activeSettingsSection = 'resolution',
                    ),
                  ),
                  Divider(
                    color: Colors.white.withOpacity(0.08),
                    height: 20,
                    thickness: 1,
                  ),
                  _buildMainMenuOption(
                    ctx,
                    'Display',
                    () => builderSetState(
                      () => _activeSettingsSection = 'display',
                    ),
                  ),
                  Divider(
                    color: Colors.white.withOpacity(0.08),
                    height: 20,
                    thickness: 1,
                  ),
                  _buildMainMenuOption(
                    ctx,
                    'Subtitles',
                    () => builderSetState(
                      () => _activeSettingsSection = 'subtitles',
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainMenuOption(
    BuildContext ctx,
    String title,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSubmenu(
    BuildContext ctx,
    String section,
    StateSetter builderSetState,
  ) {
    return Column(
      key: ValueKey(section),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => builderSetState(() => _activeSettingsSection = ''),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.white54,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      section[0].toUpperCase() + section.substring(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(ctx),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              child: _buildSubmenuContent(section, ctx, builderSetState),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmenuContent(
    String section,
    BuildContext ctx,
    StateSetter builderSetState,
  ) {
    switch (section) {
      case 'playback':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSettingSection(
              title: 'Speed',
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                      .map(
                        (s) => SizedBox(
                          height: 32,
                          child: ChoiceChip(
                            label: Text(
                              '${s}x',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            selected: _playbackSpeed == s,
                            onSelected: (_) {
                              setState(() {
                                _playbackSpeed = s;
                              });
                              _controller?.setPlaybackSpeed(_playbackSpeed);
                              builderSetState(() {});
                            },
                            labelStyle: TextStyle(
                              color: _playbackSpeed == s
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 13,
                            ),
                            selectedColor: AppTheme.redAccent,
                            backgroundColor: Colors.white.withOpacity(0.06),
                            side: BorderSide(
                              color: _playbackSpeed == s
                                  ? AppTheme.redAccent
                                  : Colors.white.withOpacity(0.15),
                              width: 1,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        );
      case 'resolution':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSettingSection(
              title: 'Quality',
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildResolutionChips(ctx),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        );
      case 'display':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSettingSection(
              title: 'Aspect Ratio',
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() => _aspect = 16 / 9);
                        builderSetState(() {});
                      },
                      child: _buildDisplayOption(
                        'Full Screen',
                        _aspect == 16 / 9,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _aspect = 21 / 10);
                        builderSetState(() {});
                      },
                      child: _buildDisplayOption('Cinema', _aspect == 21 / 10),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _aspect = 0.0);
                        builderSetState(() {});
                      },
                      child: _buildDisplayOption('Fill', _aspect == 0.0),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        );
      case 'subtitles':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Import subtitle button
            _buildSettingSection(
              title: 'Import Subtitle',
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final imported =
                          await SubtitleImportHelper.importSubtitleFile();
                      if (imported != null && mounted) {
                        setState(() {
                          _subtitles.add(imported);
                          _selectedSubtitle = _subtitles.length - 1;
                        });
                        // Load the imported subtitle
                        await _loadSubtitleTrack(_selectedSubtitle);

                        // Show confirmation snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Imported: ${imported.label}'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: AppTheme.redAccent,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Choose Subtitle File'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.redAccent,
                      side: BorderSide(color: AppTheme.redAccent, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Subtitle selection
            _buildSettingSection(
              title: 'Select Subtitle',
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildSubtitleChips(ctx),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Subtitle size
            _buildSettingSection(
              title: 'Size',
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _subScaleVN,
                  builder: (ctx2, scale, _) => Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.redAccent,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: AppTheme.redAccent,
                          ),
                          child: Slider(
                            value: scale.clamp(0.5, 2.0),
                            min: 0.5,
                            max: 2.0,
                            divisions: 30,
                            onChanged: (v) {
                              setState(() {
                                _subtitleScale = v;
                              });
                              _subScaleVN.value = _subtitleScale;
                            },
                            onChangeEnd: (_) => _saveSubtitlePrefs(),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${(scale * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Subtitle bottom position
            _buildSettingSection(
              title: 'Position',
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _subBottomVN,
                  builder: (ctx2, bottom, _) => Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.redAccent,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: AppTheme.redAccent,
                          ),
                          child: Slider(
                            value: bottom.clamp(20.0, 240.0),
                            min: 20,
                            max: 240,
                            onChanged: (v) {
                              setState(() {
                                _subtitleBottom = v;
                              });
                              _subBottomVN.value = v;
                            },
                            onChangeEnd: (_) => _saveSubtitlePrefs(),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${bottom.round()}px',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Subtitle sync/offset
            _buildSettingSection(
              title: 'Sync',
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: _subOffsetVN,
                  builder: (ctx2, offMs, _) => Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.redAccent,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: AppTheme.redAccent,
                          ),
                          child: Slider(
                            value: offMs.toDouble().clamp(-5000.0, 5000.0),
                            min: -5000,
                            max: 5000,
                            divisions: 100,
                            label: '$offMs ms',
                            onChanged: (v) {
                              setState(() {
                                _subtitleOffsetMs = v.round();
                              });
                              _subOffsetVN.value = _subtitleOffsetMs;
                            },
                            onChangeEnd: (_) => _saveSubtitlePrefs(),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$offMs ms',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildDisplayOption(String label, bool selected) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
          if (selected)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppTheme.redAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 12),
            )
          else
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  void _openSubtitles() async {
    if (_subtitles.isEmpty) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'No subtitles available',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtitles',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: -8,
                    children: _buildSubtitleChips(ctx),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Subtitle Settings',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<double>(
                    valueListenable: _subScaleVN,
                    builder: (ctx2, scale, _) => Row(
                      children: [
                        const Text(
                          'Size',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppTheme.redAccent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: AppTheme.redAccent,
                            ),
                            child: Slider(
                              value: scale.clamp(0.6, 2.0),
                              min: 0.6,
                              max: 2.0,
                              divisions: 14,
                              onChanged: (v) {
                                setState(() {
                                  _subtitleScale = v;
                                });
                                _subScaleVN.value = v;
                              },
                              onChangeEnd: (_) => _saveSubtitlePrefs(),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${(scale * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<double>(
                    valueListenable: _subBottomVN,
                    builder: (ctx2, bottom, _) => Row(
                      children: [
                        const Text(
                          'Position',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppTheme.redAccent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: AppTheme.redAccent,
                            ),
                            child: Slider(
                              value: bottom.clamp(20.0, 240.0),
                              min: 20,
                              max: 240,
                              onChanged: (v) {
                                setState(() {
                                  _subtitleBottom = v;
                                });
                                _subBottomVN.value = v;
                              },
                              onChangeEnd: (_) => _saveSubtitlePrefs(),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${bottom.round()}px',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<int>(
                    valueListenable: _subOffsetVN,
                    builder: (ctx2, offMs, _) => Row(
                      children: [
                        const Text(
                          'Sync',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppTheme.redAccent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: AppTheme.redAccent,
                            ),
                            child: Slider(
                              value: offMs.toDouble().clamp(-5000.0, 5000.0),
                              min: -5000,
                              max: 5000,
                              divisions: 100,
                              label: '$offMs ms',
                              onChanged: (v) {
                                setState(() {
                                  _subtitleOffsetMs = v.round();
                                });
                                _subOffsetVN.value = _subtitleOffsetMs;
                              },
                              onChangeEnd: (_) => _saveSubtitlePrefs(),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$offMs ms',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (result != null && result.containsKey('subtitle')) {
      final idx = result['subtitle'] as int;
      if (idx == -1) {
        setState(() {
          _selectedSubtitle = -1;
          _subtitleText = '';
          _cues = [];
        });
      } else {
        _loadSubtitleTrack(idx);
      }
    }
  }

  List<Widget> _buildResolutionChips(BuildContext ctx) {
    final chips = <Widget>[];
    // Build from HLS variants if any, else from sources labels if present
    final variants = _hlsVariants.isNotEmpty
        ? _hlsVariants
        : _sources.where((s) => s.label != null).toList();
    if (variants.isEmpty) {
      chips.add(
        ChoiceChip(
          label: const Text('Default'),
          selected: true,
          onSelected: (_) {},
          labelStyle: const TextStyle(color: Colors.white),
          selectedColor: AppTheme.redAccent,
          backgroundColor: Colors.white12,
        ),
      );
      return chips;
    }
    for (final v in variants) {
      final idx = _sources.indexWhere((s) => s.url == v.url);
      chips.add(
        ChoiceChip(
          label: Text(v.label ?? 'Auto'),
          selected: _currentSourceIndex == idx,
          onSelected: (_) {
            final resume = _controller?.value.position ?? Duration.zero;
            Navigator.pop(ctx, {'switchTo': idx});
            _init(index: idx, resumeAt: resume);
          },
          labelStyle: const TextStyle(color: Colors.white),
          selectedColor: AppTheme.redAccent,
          backgroundColor: Colors.white12,
        ),
      );
    }
    return chips;
  }

  List<Widget> _buildSubtitleChips(BuildContext ctx) {
    final chips = <Widget>[];
    chips.add(
      ChoiceChip(
        label: const Text('Off'),
        selected: _selectedSubtitle == -1,
        onSelected: (_) {
          Navigator.pop(ctx, {'subtitle': -1});
          setState(() {
            _selectedSubtitle = -1;
            _subtitleText = '';
            _cues = [];
          });
        },
        labelStyle: const TextStyle(color: Colors.white),
        selectedColor: AppTheme.redAccent,
        backgroundColor: Colors.white12,
      ),
    );
    for (int i = 0; i < _subtitles.length; i++) {
      final sub = _subtitles[i];
      chips.add(
        ChoiceChip(
          label: Text(sub.label ?? sub.lang ?? 'Subtitle ${i + 1}'),
          selected: _selectedSubtitle == i,
          onSelected: (_) {
            Navigator.pop(ctx, {'subtitle': i});
            _loadSubtitleTrack(i);
          },
          labelStyle: const TextStyle(color: Colors.white),
          selectedColor: AppTheme.redAccent,
          backgroundColor: Colors.white12,
        ),
      );
    }
    return chips;
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    }
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _controller?.value.isPlaying ?? false;
    final pos = _controller?.value.position ?? Duration.zero;
    final dur = _controller?.value.duration ?? Duration.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_locked) return;
          setState(() => _showControls = !_showControls);
        },
        child: Stack(
          children: [
            Center(child: _buildVideo()),
            if (_dim > 0)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: Container(color: Colors.black.withOpacity(_dim)),
                ),
              ),
            // Center gestures: pinch to resize subtitles, vertical drag to move position
            if (!_loading && !_error)
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: double.infinity,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onScaleStart: (_) {
                      _subDragStartScale = _subtitleScale;
                      _subDragStartBottom = _subtitleBottom;
                      _subAccumDy = 0.0;
                      _subtitleHudTimer?.cancel();
                      setState(() {
                        _showSubtitleHUD = true;
                      });
                    },
                    onScaleUpdate: (d) {
                      // Scale for size
                      final ns = (_subDragStartScale * d.scale).clamp(0.6, 2.0);
                      // Vertical pan for position
                      _subAccumDy += d.focalPointDelta.dy;
                      final nb = (_subDragStartBottom - _subAccumDy).clamp(
                        20.0,
                        300.0,
                      );
                      setState(() {
                        _subtitleScale = ns;
                        _subtitleBottom = nb;
                      });
                      _subScaleVN.value = _subtitleScale;
                      _subBottomVN.value = _subtitleBottom;
                    },
                    onScaleEnd: (_) {
                      _subtitleHudTimer?.cancel();
                      _subtitleHudTimer = Timer(
                        const Duration(milliseconds: 800),
                        () {
                          if (mounted) {
                            setState(() {
                              _showSubtitleHUD = false;
                            });
                          }
                        },
                      );
                      _saveSubtitlePrefs();
                    },
                  ),
                ),
              ),
            if (!_loading && !_error)
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: double.infinity,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: (_) {
                      _dragStartBrightness = _brightness;
                      _dragAccumDy = 0.0;
                      _brightnessHudTimer?.cancel();
                      setState(() {
                        _showBrightnessHUD = true;
                      });
                    },
                    onVerticalDragUpdate: (d) {
                      _dragAccumDy += (d.primaryDelta ?? d.delta.dy);
                      final nb = _dragStartBrightness - (_dragAccumDy / 300.0);
                      _setBrightness(nb);
                      if (!_showBrightnessHUD) {
                        setState(() {
                          _showBrightnessHUD = true;
                        });
                      }
                    },
                    onVerticalDragEnd: (_) {
                      _brightnessHudTimer?.cancel();
                      _brightnessHudTimer = Timer(
                        const Duration(milliseconds: 800),
                        () {
                          if (mounted) {
                            setState(() {
                              _showBrightnessHUD = false;
                            });
                          }
                        },
                      );
                    },
                    onTap: () {
                      if (_locked) return;
                      setState(() => _showControls = !_showControls);
                    },
                    onDoubleTap: () {
                      final pos = _controller?.value.position ?? Duration.zero;
                      final seek = pos - const Duration(seconds: 10);
                      _seekAndResume(
                        seek < Duration.zero ? Duration.zero : seek,
                      );
                      _seekFlashLeftTimer?.cancel();
                      setState(() {
                        _seekFlashLeft = true;
                      });
                      _seekFlashLeftTimer = Timer(
                        const Duration(milliseconds: 600),
                        () {
                          if (mounted) {
                            setState(() {
                              _seekFlashLeft = false;
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            if (!_loading && !_error)
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: double.infinity,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: (_) {
                      _dragStartVolume = _volume;
                      _dragAccumDy = 0.0;
                      _volumeHudTimer?.cancel();
                      setState(() {
                        _showVolumeHUD = true;
                      });
                    },
                    onVerticalDragUpdate: (d) async {
                      _dragAccumDy += (d.primaryDelta ?? d.delta.dy);
                      final nv = (_dragStartVolume - (_dragAccumDy / 300.0))
                          .clamp(0.0, 1.0);
                      await _setVolume(nv);
                      if (!_showVolumeHUD) {
                        setState(() {
                          _showVolumeHUD = true;
                        });
                      }
                    },
                    onVerticalDragEnd: (_) {
                      _volumeHudTimer?.cancel();
                      _volumeHudTimer = Timer(
                        const Duration(milliseconds: 800),
                        () {
                          if (mounted) {
                            setState(() {
                              _showVolumeHUD = false;
                            });
                          }
                        },
                      );
                    },
                    onTap: () {
                      if (_locked) return;
                      setState(() => _showControls = !_showControls);
                    },
                    onDoubleTap: () {
                      final pos = _controller?.value.position ?? Duration.zero;
                      final dur = _controller?.value.duration ?? Duration.zero;
                      final seek = pos + const Duration(seconds: 10);
                      _seekAndResume(seek > dur ? dur : seek);
                      _seekFlashRightTimer?.cancel();
                      setState(() {
                        _seekFlashRight = true;
                      });
                      _seekFlashRightTimer = Timer(
                        const Duration(milliseconds: 600),
                        () {
                          if (mounted) {
                            setState(() {
                              _seekFlashRight = false;
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            if (_showBrightnessHUD)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: AnimatedOpacity(
                    opacity: _showBrightnessHUD ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.brightness_medium_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 10,
                            height: 80,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                Container(
                                  width: 10,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  width: 10,
                                  height: 80 * _brightness.clamp(0.0, 1.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_showVolumeHUD)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: AnimatedOpacity(
                    opacity: _showVolumeHUD ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 10,
                            height: 80,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                Container(
                                  width: 10,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  width: 10,
                                  height: 80 * _volume.clamp(0.0, 1.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_seekFlashLeft)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 80),
                  child: AnimatedOpacity(
                    opacity: _seekFlashLeft ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.replay_10,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            if (_seekFlashRight)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 80),
                  child: AnimatedOpacity(
                    opacity: _seekFlashRight ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.forward_10,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: AppTheme.redAccent),
              ),
            if (_error) _buildError(),
            // Subtitle overlay
            if (_subtitleText.isNotEmpty && !_loading && !_error)
              Positioned(
                left: 12,
                right: 12,
                bottom: _subtitleBottom,
                child: Text(
                  _subtitleText,
                  textAlign: TextAlign.center,
                  textDirection: _isRtl(_subtitleText)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18 * _subtitleScale,
                    shadows: const [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  maxLines: 4,
                  softWrap: true,
                ),
              ),
            if (_showControls && !_loading && !_error)
              _buildControls(isPlaying, pos, dur),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox();
    }

    final videoWidget = _aspect == 0.0
        ? SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          )
        : AspectRatio(aspectRatio: _aspect, child: VideoPlayer(_controller!));

    // Show spinner if loading, buffering, or hasn't started yet
    final shouldShowSpinner =
        _loading ||
        _isBuffering ||
        (_controller?.value.position == Duration.zero &&
            !(_controller?.value.isPlaying ?? false));

    if (!shouldShowSpinner) {
      return videoWidget;
    }

    // Show small red buffering spinner at center
    return Stack(
      alignment: Alignment.center,
      children: [
        videoWidget,
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(bool isPlaying, Duration pos, Duration dur) {
    if (_locked) {
      return SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _iconButton(
              Icons.lock,
              () => setState(() => _locked = false),
            ),
          ),
        ),
      );
    }

    final pad = MediaQuery.of(context).padding;
    final padTop = pad.top;
    final padBottom = pad.bottom;
    final size = MediaQuery.of(context).size;
    const double sliderHeight = 180.0;
    final double usableH = size.height - padTop - padBottom;
    final double slidersTop = padTop + (usableH - sliderHeight) / 2 - 30;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black54,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black54,
                ],
              ),
            ),
          ),
        ),
        // Top bar with back arrow and title
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _iconButton(
                    Icons.arrow_back,
                    () => Navigator.pop(context),
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Top-right lock button
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 16),
              child: _iconButton(
                Icons.lock_open,
                () => setState(() => _locked = true),
                size: 32,
              ),
            ),
          ),
        ),
        // Left brightness slider
        Positioned(
          left: 12,
          top: slidersTop,
          child: _verticalSlider(
            label: '${(_brightness * 100).round()}%',
            value: _brightness.clamp(0.0, 1.0),
            onChanged: (v) => _setBrightness(v),
            icon: Icons.brightness_medium_rounded,
            height: sliderHeight.toDouble(),
          ),
        ),
        // Right volume slider
        Positioned(
          right: 12,
          top: slidersTop,
          child: _verticalSlider(
            label: '${(_volume * 100).round()}%',
            value: _volume.clamp(0.0, 1.0),
            onChanged: (v) async {
              await _setVolume(v);
            },
            icon: Icons.volume_up_rounded,
            height: sliderHeight.toDouble(),
          ),
        ),
        // Center transport controls
        Align(
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _iconButton(Icons.replay_10, () {
                final seek = pos - const Duration(seconds: 10);
                _seekAndResume(seek < Duration.zero ? Duration.zero : seek);
              }, size: 44),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _togglePlay,
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(width: 24),
              _iconButton(Icons.forward_10, () {
                final seek = pos + const Duration(seconds: 10);
                _seekAndResume(seek > dur ? dur : seek);
              }, size: 44),
            ],
          ),
        ),
        // Progress slider just above bottom actions
        Positioned(
          left: 24,
          right: 24,
          bottom: 48 + padBottom,
          child: Row(
            children: [
              Text(
                _format(pos),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.redAccent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppTheme.redAccent,
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: dur.inMilliseconds == 0
                        ? 0.0
                        : pos.inMilliseconds / dur.inMilliseconds,
                    onChanged: (v) {
                      final ms = (v * dur.inMilliseconds).round();
                      _seekAndResume(Duration(milliseconds: ms));
                      setState(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _format(dur),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
        // Bottom actions row: volume, subtitles, aspect, settings
        Positioned(
          left: 24,
          right: 24,
          bottom: 16 + padBottom,
          child: Row(
            children: [
              _iconButton(
                _volume == 0 ? Icons.volume_off : Icons.volume_up,
                _toggleMute,
                size: 32,
              ),
              const SizedBox(width: 16),
              const Spacer(),
              _iconButton(Icons.settings, _openSettings, size: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconButton(
    IconData icon,
    VoidCallback onPressed, {
    double size = 32,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Icon(icon, color: Colors.white, size: size),
    );
  }

  Widget _verticalSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required IconData icon,
    double height = 180,
    double width = 40,
  }) {
    return Column(
      children: [
        SizedBox(
          width: width,
          height: height,
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                trackHeight: 3,
              ),
              child: Slider(value: value, onChanged: onChanged),
            ),
          ),
        ),
        const SizedBox(height: 0),
        Transform.translate(
          offset: const Offset(0, -12),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 12),
          const Text(
            'Failed to play stream',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(_errorMsg ?? '', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = false;
              });
              _init(index: (_currentSourceIndex + 1) % _sources.length);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
