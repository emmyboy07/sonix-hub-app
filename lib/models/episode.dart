class Episode {
  final int episodeNumber;
  final String name;
  final String overview;
  final int? runtime;
  final String? airDate;
  final String? stillPath;

  Episode({
    required this.episodeNumber,
    required this.name,
    required this.overview,
    this.runtime,
    this.airDate,
    this.stillPath,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      episodeNumber: json['episode_number'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      runtime: json['runtime'] as int?,
      airDate: json['air_date'] as String?,
      stillPath: json['still_path'] as String?,
    );
  }
}
