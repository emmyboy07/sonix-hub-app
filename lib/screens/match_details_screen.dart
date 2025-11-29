import 'package:flutter/material.dart';
import '../widgets/sonix_header.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'search_screen.dart';
import '../utils/page_transitions.dart';

class MatchDetailsScreen extends StatefulWidget {
  final String matchId;
  const MatchDetailsScreen({super.key, required this.matchId});

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  Map<String, dynamic>? match;
  List<dynamic> sources = [];
  int selectedSourceIdx = 0;
  bool loading = false;
  List<dynamic> streams = [];
  int selectedStreamIdx = 0;
  bool embedLoading = true;
  // Removed WebView controller
  Timer? _countdownTimer;
  Map<String, int>? countdown;

  @override
  void initState() {
    super.initState();
    fetchMatchDetails();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchMatchDetails() async {
    setState(() {
      loading = true;
    });
    try {
      final res = await http.get(
        Uri.parse('https://streamed.pk/api/matches/all'),
      );
      final data = json.decode(res.body);
      final matchesArr = data is List ? data : (data['data'] ?? []);
      final foundMatch = matchesArr.firstWhere(
        (m) => m['id'].toString() == widget.matchId,
        orElse: () => null,
      );
      if (foundMatch != null) {
        setState(() {
          match = foundMatch;
          sources = (match?['sources'] as List?)?.cast<dynamic>() ?? [];
          selectedSourceIdx = 0;
        });
        if (sources.isNotEmpty) {
          await fetchStreams(0);
        }
        setupCountdown();
      }
    } catch (e) {
      // handle error
    }
    setState(() {
      loading = false;
    });
  }

  Future<void> fetchStreams(int idx) async {
    setState(() {
      loading = true;
      selectedSourceIdx = idx;
      streams = [];
      selectedStreamIdx = 0;
    });
    try {
      final source = sources[idx];
      final res = await http.get(
        Uri.parse(
          'https://streamed.pk/api/stream/${source['source']}/${source['id']}',
        ),
      );
      final data = json.decode(res.body);
      final streamArr = data is List ? data : (data['data'] ?? []);
      setState(() {
        streams = (streamArr as List?)?.cast<dynamic>() ?? [];
        selectedStreamIdx = 0;
      });
      // Debug print streams
      print(
        'Fetched streams for source: ${source['source']} id: ${source['id']}',
      );
      print('Streams:');
      for (var s in streams) {
        print(s);
      }
    } catch (e) {
      // handle error
      print('Error fetching streams: $e');
    }
    setState(() {
      loading = false;
    });
  }

  void setupCountdown() {
    _countdownTimer?.cancel();
    if (match == null) return;
    final status = getMatchStatus(match!['date']);
    if (status != 'upcoming') {
      setState(() {
        countdown = null;
      });
      return;
    }
    updateCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => updateCountdown(),
    );
  }

  void updateCountdown() {
    if (match == null) return;
    final c = getCountdown(match!['date']);
    setState(() {
      countdown = c;
    });
  }

  String getMatchStatus(
    dynamic matchDate, {
    int durationMs = 2 * 60 * 60 * 1000,
  }) {
    int dateVal = matchDate is int
        ? matchDate
        : int.tryParse(matchDate.toString()) ?? 0;
    if (dateVal < 1e12) dateVal = dateVal * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= dateVal && now <= dateVal + durationMs) {
      return "live";
    } else if (now < dateVal) {
      return "upcoming";
    } else {
      return "ended";
    }
  }

  String formatMatchDate(dynamic dateMs) {
    int dateVal = dateMs is int ? dateMs : int.tryParse(dateMs.toString()) ?? 0;
    if (dateVal < 1e12) dateVal = dateVal * 1000;
    final d = DateTime.fromMillisecondsSinceEpoch(dateVal);
    final timeStr =
        "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;
    final isTomorrow =
        d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day;
    final hasStarted = isToday && now.isAfter(d);
    if (hasStarted) {
      return "Started Today, $timeStr";
    }
    if (isToday) {
      return "Start Date: Today, $timeStr";
    }
    if (isTomorrow) {
      return "Start Date: Tomorrow, $timeStr";
    }
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    return "Start Date: $day/$month/$year, $timeStr";
  }

  Map<String, int>? getCountdown(dynamic dateMs) {
    int dateVal = dateMs is int ? dateMs : int.tryParse(dateMs.toString()) ?? 0;
    if (dateVal < 1e12) dateVal = dateVal * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = dateVal - now;
    if (diff <= 0) return null;
    final days = diff ~/ (1000 * 60 * 60 * 24);
    final hours = (diff ~/ (1000 * 60 * 60)) % 24;
    final minutes = (diff ~/ (1000 * 60)) % 60;
    final seconds = (diff ~/ 1000) % 60;
    return {
      'days': days,
      'hours': hours,
      'minutes': minutes,
      'seconds': seconds,
    };
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF0000)),
        ),
      );
    }

    final teamHome = match?['teams']?['home'];
    final teamAway = match?['teams']?['away'];
    String? homeBadgeUrl;
    String? awayBadgeUrl;
    if (teamHome != null &&
        teamHome['badge'] != null &&
        teamHome['badge'].toString().isNotEmpty) {
      homeBadgeUrl =
          'https://streamed.pk/api/images/badge/${teamHome['badge']}.webp';
    }
    if (teamAway != null &&
        teamAway['badge'] != null &&
        teamAway['badge'].toString().isNotEmpty) {
      awayBadgeUrl =
          'https://streamed.pk/api/images/badge/${teamAway['badge']}.webp';
    }
    final title = match?['title'] ?? '';

    // Get the selected stream URL safely
    String? selectedStreamUrl;
    if (streams.isNotEmpty && selectedStreamIdx < streams.length) {
      final url = streams[selectedStreamIdx]['embedUrl']?.toString() ?? '';
      print('Selected stream embedUrl: $url');
      if (url.isNotEmpty && url.startsWith('http')) {
        selectedStreamUrl = url;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sonix Header
              SonixHeader(
                onSearchPressed: () {
                  navigateWithTransition(context, const SearchScreen());
                },
              ),
              // Header with Back Button and Title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Teams Row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        if (homeBadgeUrl != null)
                          CircleAvatar(
                            backgroundImage: NetworkImage(homeBadgeUrl),
                            radius: 28,
                            backgroundColor: Colors.black,
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 80,
                          child: Text(
                            teamHome?['name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Column(
                      children: [
                        if (awayBadgeUrl != null)
                          CircleAvatar(
                            backgroundImage: NetworkImage(awayBadgeUrl),
                            radius: 28,
                            backgroundColor: Colors.black,
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 80,
                          child: Text(
                            teamAway?['name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Stream Info & Player (removed WebView)
              if (selectedStreamUrl != null &&
                  selectedStreamIdx < streams.length) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Now Playing: ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                                fontSize: 15,
                              ),
                            ),
                            TextSpan(
                              text:
                                  streams[selectedStreamIdx]['label'] ??
                                  'Stream',
                              style: const TextStyle(
                                color: Color(0xFFFF0000),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            TextSpan(
                              text: streams[selectedStreamIdx]['hd'] == true
                                  ? ' (HD)'
                                  : ' (SD)',
                              style: const TextStyle(
                                color: Color(0xFFFF0000),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Viewers: ${streams[selectedStreamIdx]['viewers'] ?? '-'}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Player area: show embed URL in-app using InAppWebView
                Container(
                  width: double.infinity,
                  height: screenWidth * 9 / 16,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[700]!, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        InAppWebView(
                          key: ValueKey(selectedStreamIdx),
                          initialUrlRequest: URLRequest(
                            url: WebUri(selectedStreamUrl),
                          ),
                          initialSettings: InAppWebViewSettings(
                            javaScriptEnabled: true,
                            allowsInlineMediaPlayback: true,
                            mediaPlaybackRequiresUserGesture: false,
                            userAgent:
                                'Mozilla/5.0 (Linux; Android 12; HZFlix) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
                            thirdPartyCookiesEnabled: true,
                            hardwareAcceleration: true,
                            loadWithOverviewMode: true,
                            useWideViewPort: true,
                            supportZoom: false,
                            verticalScrollBarEnabled: false,
                            horizontalScrollBarEnabled: false,
                          ),
                          onLoadStart: (controller, url) {
                            setState(() => embedLoading = true);
                          },
                          onLoadStop: (controller, url) {
                            setState(() => embedLoading = false);
                          },
                          onLoadError: (controller, url, code, message) {
                            setState(() => embedLoading = false);
                          },
                          shouldOverrideUrlLoading: (controller, navAction) async {
                            final url = navAction.request.url?.toString() ?? '';
                            final originalUrl = selectedStreamUrl ?? '';
                            // Block known ad/popunder domains
                            final blockedDomains = [
                              'ads',
                              'adnxs',
                              'doubleclick',
                              'google-analytics',
                              'facebook',
                              'popads',
                              'popcash',
                              'propeller',
                              'taboola',
                              'outbrain',
                              'mgid',
                              'clickadu',
                              'exoclick',
                              'juicyads',
                              'revcontent',
                              'chrome',
                              'play.google',
                              'itunes',
                              'microsoft',
                              'bit.ly',
                            ];
                            if (blockedDomains.any(
                              (domain) => url.toLowerCase().contains(domain),
                            )) {
                              return NavigationActionPolicy.CANCEL;
                            }
                            // Only allow navigation to the original embed URL and same domain media/resources
                            try {
                              final streamUri = Uri.parse(originalUrl);
                              final requestUri = Uri.parse(url);
                              final isSameDomain =
                                  streamUri.host == requestUri.host;
                              final isMedia = url.contains(
                                RegExp(
                                  r'\.(m3u8|ts|mp4|m4s|key|mpd)$',
                                  caseSensitive: false,
                                ),
                              );
                              final isResource = url.contains(
                                RegExp(
                                  r'\.(css|js|png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf)$',
                                  caseSensitive: false,
                                ),
                              );
                              if (url == originalUrl ||
                                  isMedia ||
                                  (isSameDomain && isResource)) {
                                return NavigationActionPolicy.ALLOW;
                              }
                            } catch (e) {}
                            // Block all other navigation
                            return NavigationActionPolicy.CANCEL;
                          },
                        ),
                        if (embedLoading)
                          Center(
                            child: CircularProgressIndicator(
                              color: const Color(0xFFFF0000),
                              strokeWidth: 3,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Match Time Info
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  child: Center(
                    child: Text(
                      formatMatchDate(match?['date']),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
                // All Sources
                if (sources.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sources',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: List.generate(sources.length, (idx) {
                            final src = sources[idx];
                            final isActive = idx == selectedSourceIdx;
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isActive
                                    ? const Color(0xFFFF0000)
                                    : Colors.black,
                                foregroundColor: isActive
                                    ? Colors.white
                                    : const Color(0xFFFF0000),
                                side: BorderSide(
                                  color: Colors.grey[600]!,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () => fetchStreams(idx),
                              child: Text(
                                isActive
                                    ? '✓ ${src['label']?.toString() ?? src['source']?.toString() ?? 'Source'}'
                                    : src['label']?.toString() ??
                                          src['source']?.toString() ??
                                          'Source',
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                // Stream Selection
                if (streams.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Streams',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: List.generate(streams.length, (idx) {
                            final streamName = 'Stream #${idx + 1}';
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: idx == selectedStreamIdx
                                    ? const Color(0xFFFF0000)
                                    : Colors.black,
                                foregroundColor: idx == selectedStreamIdx
                                    ? Colors.white
                                    : const Color(0xFFFF0000),
                                side: BorderSide(
                                  color: Colors.grey[600]!,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  selectedStreamIdx = idx;
                                });
                              },
                              child: Text(streamName),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No valid stream available for this match.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
