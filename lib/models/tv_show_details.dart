import 'package:sonix_hub/models/episode.dart';

class Season {
  final int seasonNumber;
  final String name;
  final int episodeCount;
  final String? posterPath;
  final String airDate;
  final List<Episode>? episodes;

  Season({
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
    this.posterPath,
    required this.airDate,
    this.episodes,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      seasonNumber: json['season_number'] as int? ?? 0,
      name: json['name'] as String? ?? 'Season ${json['season_number']}',
      episodeCount: json['episode_count'] as int? ?? 0,
      posterPath: json['poster_path'] as String?,
      airDate: json['air_date'] as String? ?? 'N/A',
      episodes: json.containsKey('episodes') && json['episodes'] is List
          ? (json['episodes'] as List)
                .map((e) => Episode.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
    );
  }
}

class TVShowDetails {
  final int id;
  final String name;
  final int numberOfSeasons;
  final int numberOfEpisodes;
  final List<Season> seasons;
  final String status;
  final String? nextEpisodeToAir;
  final String? lastEpisodeToAir;
  final String originalLanguage;
  final String? posterPath;
  final String? backdropPath;
  final String overview;
  final double voteAverage;
  final String? firstAirDate;
  final List<int> genreIds;

  TVShowDetails({
    required this.id,
    required this.name,
    required this.numberOfSeasons,
    required this.numberOfEpisodes,
    required this.seasons,
    required this.status,
    this.nextEpisodeToAir,
    this.lastEpisodeToAir,
    this.originalLanguage = '',
    this.posterPath,
    this.backdropPath,
    this.overview = '',
    this.voteAverage = 0.0,
    this.firstAirDate,
    this.genreIds = const [],
  });

  factory TVShowDetails.fromJson(Map<String, dynamic> json) {
    return TVShowDetails(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      numberOfSeasons: json['number_of_seasons'] as int? ?? 0,
      numberOfEpisodes: json['number_of_episodes'] as int? ?? 0,
      seasons:
          (json['seasons'] as List?)
              ?.map((s) => Season.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      status: json['status'] as String? ?? 'Unknown',
      nextEpisodeToAir: json['next_episode_to_air']?['name'] as String?,
      lastEpisodeToAir: json['last_episode_to_air']?['name'] as String?,
      originalLanguage: json['original_language'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      overview: json['overview'] as String? ?? '',
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      firstAirDate: json['first_air_date'] as String?,
      genreIds: json['genres'] != null
          ? (json['genres'] as List)
                .map((g) => (g as Map<String, dynamic>)['id'] as int)
                .toList()
          : [],
    );
  }
}
