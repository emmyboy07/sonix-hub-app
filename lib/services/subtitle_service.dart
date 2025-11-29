import 'package:http/http.dart' as http;
import 'dart:convert';

const String _subtitleApiBase = 'https://sub.wyzie.ru';

class SubtitleItem {
  final String? id;
  final String url;
  final String? flagUrl;
  final String? format;
  final String? encoding;
  final String? display;
  final String? language;
  final String? media;
  final bool isHearingImpaired;
  final String? source;

  SubtitleItem({
    this.id,
    required this.url,
    this.flagUrl,
    this.format,
    this.encoding,
    this.display,
    this.language,
    this.media,
    this.isHearingImpaired = false,
    this.source,
  });

  factory SubtitleItem.fromJson(Map<String, dynamic> json) {
    return SubtitleItem(
      id: json['id'] ?? json['subtitle_id'] ?? json['_id'],
      url: json['url'] ?? '',
      flagUrl: json['flagUrl'] ?? json['flag_url'],
      format: json['format'],
      encoding: json['encoding'],
      display:
          json['display'] ?? json['label'] ?? json['language'] ?? json['lang'],
      language: json['language'] ?? json['lang'],
      media: json['media'],
      isHearingImpaired:
          json['isHearingImpaired'] ?? json['hearing_impaired'] ?? false,
      source: json['source'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'flagUrl': flagUrl,
      'format': format,
      'encoding': encoding,
      'display': display,
      'language': language,
      'media': media,
      'isHearingImpaired': isHearingImpaired,
      'source': source,
    };
  }
}

class SubtitleForPlayer {
  final String lang;
  final String label;
  final String url;

  SubtitleForPlayer({
    required this.lang,
    required this.label,
    required this.url,
  });

  Map<String, dynamic> toJson() {
    return {'lang': lang, 'label': label, 'url': url};
  }
}

class SubtitleService {
  static const Duration _defaultTimeout = Duration(seconds: 8);
  static final http.Client _httpClient = http.Client();

  /// Search subtitles by TMDB ID or IMDB ID
  /// Returns a list of available subtitles
  static Future<List<SubtitleItem>> searchById(
    String id, {
    int? season,
    int? episode,
    String? language,
    String? format,
  }) async {
    try {
      final params = <String, String>{
        'id': id,
        'encoding': 'utf-8', // Always request UTF-8 encoding
      };

      if (season != null) params['season'] = season.toString();
      if (episode != null) params['episode'] = episode.toString();
      if (language != null) params['language'] = language;
      if (format != null) params['format'] = format;

      final uri = Uri.parse(
        '$_subtitleApiBase/search',
      ).replace(queryParameters: params);

      final response = await _httpClient
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        print('[SubtitleService] Non-200 response: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);

      if (data is! List) {
        print('[SubtitleService] Expected array but got: ${data.runtimeType}');
        return [];
      }

      final items = (data)
          .map((item) => SubtitleItem.fromJson(item as Map<String, dynamic>))
          .toList();

      print('[SubtitleService] Found ${items.length} subtitles for ID: $id');
      return items;
    } catch (e) {
      print('[SubtitleService] Error searching subtitles: $e');
      return [];
    }
  }

  /// Select the best subtitles for playback
  /// Returns up to engCount English subtitles and otherCount in other languages
  /// Default: 5 English + 5 other languages = 10 total
  static List<SubtitleForPlayer> selectForPlayer(
    List<SubtitleItem> subs, {
    int engCount = 5,
    int otherCount = 5,
  }) {
    if (subs.isEmpty) return [];

    // Normalize language for comparison
    String normalizeLang(SubtitleItem s) {
      return (s.language ?? s.display ?? '').toLowerCase();
    }

    // Score encoding preference
    int scoreEncoding(SubtitleItem s) {
      final enc = (s.encoding ?? '').toLowerCase();
      if (enc.contains('utf')) return 2;
      if (enc.contains('ascii')) return 1;
      return 0;
    }

    // Separate English and other language subtitles
    final english = subs
        .where((s) => normalizeLang(s).startsWith('en'))
        .toList();
    final others = subs
        .where((s) => !normalizeLang(s).startsWith('en'))
        .toList();

    // Sort by encoding preference and select top English
    english.sort((a, b) => scoreEncoding(b).compareTo(scoreEncoding(a)));
    final selectedEnglish = english.take(engCount).toList();

    // Select others with unique languages, preferring good encodings
    others.sort((a, b) => scoreEncoding(b).compareTo(scoreEncoding(a)));
    final selectedOthers = <SubtitleItem>[];
    final seenLanguages = <String>{};

    for (final s in others) {
      final lang = normalizeLang(s).isEmpty ? 'unknown' : normalizeLang(s);
      if (!seenLanguages.contains(lang)) {
        selectedOthers.add(s);
        seenLanguages.add(lang);
      }
      if (selectedOthers.length >= otherCount) break;
    }

    // Combine and format for player
    final result = <SubtitleForPlayer>[
      ...selectedEnglish.map(
        (s) => SubtitleForPlayer(
          lang: (s.language ?? s.display ?? '')
              .toLowerCase()
              .split('_')[0]
              .substring(0, 2),
          label: s.display ?? s.language ?? s.format ?? 'Subtitle',
          url: s.url,
        ),
      ),
      ...selectedOthers.map(
        (s) => SubtitleForPlayer(
          lang: (s.language ?? s.display ?? '')
              .toLowerCase()
              .split('_')[0]
              .substring(0, 2),
          label: s.display ?? s.language ?? s.format ?? 'Subtitle',
          url: s.url,
        ),
      ),
    ];

    return result;
  }
}
