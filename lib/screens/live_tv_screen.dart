import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sonix_hub/screens/minimal_player_screen.dart';
import '../components/channel_card.dart';
import '../components/sport_match_card.dart';
import 'package:sonix_hub/screens/match_details_screen.dart';
import '../config/theme.dart';
import '../widgets/sonix_header.dart';
import 'search_screen.dart';
import '../utils/page_transitions.dart';

// Human readable date formatter (React Native style)
String formatMatchDateRN(dynamic dateMs) {
  int dateVal = dateMs is int ? dateMs : int.tryParse(dateMs.toString()) ?? 0;
  if (dateVal < 1e12) dateVal = dateVal * 1000;
  final d = DateTime.fromMillisecondsSinceEpoch(dateVal);
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
  String timeStr =
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  if (hasStarted) return "Live Now";
  if (isToday) return "Today, $timeStr";
  if (isTomorrow) return "Tomorrow, $timeStr";
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  final year = d.year;
  return "$day/$month/$year, $timeStr";
}

class LiveTVScreen extends StatefulWidget {
  const LiveTVScreen({super.key});

  @override
  State<LiveTVScreen> createState() => _LiveTVScreenState();
}

class _LiveTVScreenState extends State<LiveTVScreen> {
  List<Map<String, dynamic>> channels = [];
  List<Map<String, dynamic>> matches = [];
  String selectedCategory = 'all';
  String section = 'channels'; // 'channels' or 'sports'
  String channelSearch = '';
  bool isLoadingChannels = true;
  bool isLoadingMatches = true;

  static const sportCategories = [
    {'id': 'all', 'name': 'All'},
    {'id': 'basketball', 'name': 'Basketball'},
    {'id': 'football', 'name': 'Football'},
    {'id': 'american-football', 'name': 'American Football'},
    {'id': 'hockey', 'name': 'Hockey'},
    {'id': 'baseball', 'name': 'Baseball'},
    {'id': 'motor-sports', 'name': 'Motor Sports'},
    {'id': 'fight', 'name': 'Fight (UFC, Boxing)'},
    {'id': 'tennis', 'name': 'Tennis'},
    {'id': 'rugby', 'name': 'Rugby'},
    {'id': 'golf', 'name': 'Golf'},
    {'id': 'billiards', 'name': 'Billiards'},
    {'id': 'afl', 'name': 'AFL'},
    {'id': 'darts', 'name': 'Darts'},
    {'id': 'cricket', 'name': 'Cricket'},
    {'id': 'other', 'name': 'Other'},
  ];

  static const channelCategories = [
    'all',
    'local',
    'news',
    'sports',
    'entertainment',
    'premium',
    'lifestyle',
    'kids',
    'documentaries',
    'music',
  ];
  String selectedChannelCategory = 'all';

  @override
  void initState() {
    super.initState();
    loadChannels();
    fetchMatches();
  }

  Future<void> loadChannels() async {
    setState(() => isLoadingChannels = true);
    final String jsonStr = await rootBundle.loadString(
      'assets/channel-list.json',
    );
    final Map<String, dynamic> data = json.decode(jsonStr);
    final List metas = data['metas'] ?? [];
    channels = metas.map<Map<String, dynamic>>((c) {
      final streams = c['streams'] as List?;
      return {
        'id': c['id'] ?? c['name'],
        'title': c['name'] ?? c['title'] ?? c['id'],
        'logo': c['logo'] ?? c['poster'],
        'streams': streams ?? [],
        'country': c['country'] ?? c['countryCode'] ?? '',
        'categories': c['genres'] ?? [],
      };
    }).toList();
    setState(() => isLoadingChannels = false);
  }

  Future<void> fetchMatches() async {
    setState(() => isLoadingMatches = true);
    final category = selectedCategory;
    final url =
        'https://streamed.pk/api/matches/${category == 'all' ? 'all' : category}';
    try {
      final res = await NetworkAssetBundle(Uri.parse(url)).load(url);
      final String jsonStr = utf8.decode(res.buffer.asUint8List());
      final List data = json.decode(jsonStr);
      matches = data.cast<Map<String, dynamic>>();
      print('Fetched matches: \\${matches.length}');
    } catch (e) {
      print('Error fetching matches: \\${e.toString()}');
      matches = [];
    }
    setState(() => isLoadingMatches = false);
  }

  @override
  Widget build(BuildContext context) {
    final tabTitle = section == 'channels' ? 'Channels' : 'Live Sport';
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      body: Column(
        children: [
          SonixHeader(
            onSearchPressed: () {
              navigateWithTransition(context, const SearchScreen());
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tabTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => section = 'channels'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: section == 'channels'
                            ? const Color(0xFFFF0000)
                            : Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.tv,
                            color: section == 'channels'
                                ? Colors.white
                                : Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Channels',
                            style: TextStyle(
                              color: section == 'channels'
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => section = 'sports'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: section == 'sports'
                            ? const Color(0xFFFF0000)
                            : Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sports_soccer,
                            color: section == 'sports'
                                ? Colors.white
                                : Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Live Sport',
                            style: TextStyle(
                              color: section == 'sports'
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search bar for both tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: section == 'channels'
                            ? 'Search channels...'
                            : 'Search live sport...',
                        hintStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.grey[900],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (v) => setState(() => channelSearch = v),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Filters for current tab
          if (section == 'channels') ...[
            Container(
              height: 32,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: channelCategories.length,
                itemBuilder: (context, index) {
                  final cat = channelCategories[index];
                  final isSelected = selectedChannelCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => selectedChannelCategory = cat),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF0000)
                            : Colors.grey[900],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        cat[0].toUpperCase() + cat.substring(1),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Container(
              height: 32,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sportCategories.length,
                itemBuilder: (context, index) {
                  final category = sportCategories[index];
                  final isSelected = selectedCategory == category['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategory = category['id'] ?? 'all';
                      });
                      fetchMatches();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF0000)
                            : Colors.grey[900],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        category['name'] ?? '',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          // Content for current tab
          Expanded(
            child: section == 'channels'
                ? (isLoadingChannels
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          children: channels
                              .where((c) {
                                final cat = selectedChannelCategory;
                                final matchesCat =
                                    cat == 'all' ||
                                    ((c['categories'] as List?)
                                            ?.map(
                                              (e) => e.toString().toLowerCase(),
                                            )
                                            .contains(cat) ??
                                        false);
                                final matchesSearch =
                                    channelSearch.isEmpty ||
                                    (c['title']
                                            ?.toString()
                                            .toLowerCase()
                                            .contains(
                                              channelSearch.toLowerCase(),
                                            ) ??
                                        false);
                                return matchesCat && matchesSearch;
                              })
                              .map(
                                (channel) => ChannelCard(
                                  item: channel,
                                  onPlay: (item) {
                                    final streams =
                                        item['streams'] as List? ?? [];
                                    final keys = [
                                      'url',
                                      'file',
                                      'src',
                                      'link',
                                      'uri',
                                      'stream',
                                      'hls',
                                    ];
                                    final urls = streams
                                        .whereType<Map>()
                                        .map((s) {
                                          for (final k in keys) {
                                            final v = s[k];
                                            if (v is String &&
                                                v.trim().isNotEmpty) {
                                              return v.trim();
                                            }
                                          }
                                          return null;
                                        })
                                        .whereType<String>()
                                        .where((u) => u.startsWith('http'))
                                        .toList();
                                    String? pickBest(List<String> urls) {
                                      if (urls.isEmpty) return null;
                                      String lower(String s) => s.toLowerCase();
                                      final hls = urls.firstWhere(
                                        (s) =>
                                            lower(s).contains('.m3u8') ||
                                            lower(s).contains('manifest') ||
                                            lower(s).contains('playlist') ||
                                            lower(s).contains('/hls/') ||
                                            lower(s).contains('master') ||
                                            lower(s).contains('index'),
                                        orElse: () => '',
                                      );
                                      if (hls.isNotEmpty) return hls;
                                      final http = urls.firstWhere(
                                        (s) => s.startsWith('http'),
                                        orElse: () => '',
                                      );
                                      if (http.isNotEmpty) return http;
                                      return urls.first;
                                    }

                                    final best = pickBest(urls);
                                    final ordered = best != null
                                        ? [
                                            best,
                                            ...urls.where((u) => u != best),
                                          ]
                                        : urls;
                                    final orderedStrings = ordered
                                        .whereType<String>()
                                        .where((u) => u.startsWith('http'))
                                        .toList();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MinimalPlayerScreen(
                                          urls: orderedStrings,
                                          title: item['title'] ?? '',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                              .toList(),
                        ))
                : (isLoadingMatches
                      ? const Center(child: CircularProgressIndicator())
                      : matches.isEmpty
                      ? const Center(
                          child: Text(
                            'No live sport available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView(
                          children: matches
                              .where((match) {
                                final matchesSearch =
                                    channelSearch.isEmpty ||
                                    (match['title']
                                            ?.toString()
                                            .toLowerCase()
                                            .contains(
                                              channelSearch.toLowerCase(),
                                            ) ??
                                        false);
                                return matchesSearch;
                              })
                              .map((match) {
                                // Format date/time (React Native style)
                                match['formattedDate'] = formatMatchDateRN(
                                  match['date'],
                                );
                                return SportMatchCard(
                                  item: match,
                                  onPlay: (_) {
                                    final matchId =
                                        match['id']?.toString() ?? '';
                                    if (matchId.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MatchDetailsScreen(
                                            matchId: matchId,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                );
                              })
                              .toList(),
                        )),
            // Human readable date formatter
          ),
        ],
      ),
    );
  }
}
