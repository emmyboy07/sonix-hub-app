class Movie {
  final int id;
  final String title;
  final String posterPath;
  final String backdropPath;
  final String overview;
  final double voteAverage;
  final String releaseDate;
  final List<int> genreIds;
  final String mediaType; // 'movie' or 'tv'
  final String originalLanguage;

  Movie({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    required this.overview,
    required this.voteAverage,
    required this.releaseDate,
    required this.genreIds,
    this.mediaType = 'movie',
    this.originalLanguage = '',
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    // Handle both movies and TV shows
    final isTV = json['media_type'] == 'tv';

    // For backward compatibility, check if this was saved as a TV show
    // Try 'name' first (from API), fall back to 'title' (saved format)
    String title;
    if (isTV) {
      title =
          (json['name'] as String?) ?? (json['title'] as String?) ?? 'Unknown';
    } else {
      title =
          (json['title'] as String?) ?? (json['name'] as String?) ?? 'Unknown';
    }

    // Handle genres - TMDB API returns either genre_ids (search) or genres (details)
    List<int> genreIds = [];
    if (json['genre_ids'] != null) {
      // Search endpoint format - already has genre_ids as list of ints
      genreIds = List<int>.from(json['genre_ids'] as List? ?? []);
    } else if (json['genres'] != null) {
      // Detailed endpoint format - has genres as list of objects with 'id'
      final genres = json['genres'] as List?;
      if (genres != null) {
        genreIds = genres
            .where((g) => g is Map<String, dynamic> && g['id'] != null)
            .map<int>((g) => (g as Map<String, dynamic>)['id'] as int)
            .toList();
      }
    }

    return Movie(
      id: json['id'] as int? ?? 0,
      title: title,
      posterPath: json['poster_path'] as String? ?? '',
      backdropPath: json['backdrop_path'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      voteAverage: (json['vote_average'] is int)
          ? (json['vote_average'] as int).toDouble()
          : (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseDate: isTV
          ? (json['first_air_date'] as String? ??
                (json['release_date'] as String? ?? ''))
          : (json['release_date'] as String? ??
                (json['first_air_date'] as String? ?? '')),
      genreIds: genreIds,
      mediaType: json['media_type'] as String? ?? 'movie',
      originalLanguage: json['original_language'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'overview': overview,
      'vote_average': voteAverage,
      'release_date': releaseDate,
      'genre_ids': genreIds,
      'media_type': mediaType,
      'original_language': originalLanguage,
    };
  }

  Movie copyWith({
    int? id,
    String? title,
    String? posterPath,
    String? backdropPath,
    String? overview,
    double? voteAverage,
    String? releaseDate,
    List<int>? genreIds,
    String? mediaType,
    String? originalLanguage,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      overview: overview ?? this.overview,
      voteAverage: voteAverage ?? this.voteAverage,
      releaseDate: releaseDate ?? this.releaseDate,
      genreIds: genreIds ?? this.genreIds,
      mediaType: mediaType ?? this.mediaType,
      originalLanguage: originalLanguage ?? this.originalLanguage,
    );
  }
}
