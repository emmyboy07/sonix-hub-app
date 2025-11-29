class PersonDetails {
  final int id;
  final String name;
  final String? profilePath;
  final String biography;
  final String? birthday;
  final String? placeOfBirth;
  final double popularity;
  final List<PersonImage> images;
  final List<PersonCredit> movieCredits;
  final List<PersonCredit> tvCredits;
  final List<PersonCredit> knownFor;
  final String? twitterId;
  final String? instagramId;
  final String? facebookId;
  final String? backdropPath;

  PersonDetails({
    required this.id,
    required this.name,
    required this.profilePath,
    required this.biography,
    required this.birthday,
    required this.placeOfBirth,
    required this.popularity,
    required this.images,
    required this.movieCredits,
    required this.tvCredits,
    required this.knownFor,
    required this.twitterId,
    required this.instagramId,
    required this.facebookId,
    required this.backdropPath,
  });

  int? get age {
    if (birthday == null) return null;
    try {
      final birthDate = DateTime.parse(birthday!);
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  int get knownCredits => movieCredits.length + tvCredits.length;

  factory PersonDetails.fromJson(Map<String, dynamic> json) {
    return PersonDetails(
      id: json['id'],
      name: json['name'] ?? '',
      profilePath: json['profile_path'],
      biography: json['biography'] ?? '',
      birthday: json['birthday'],
      placeOfBirth: json['place_of_birth'],
      popularity: (json['popularity'] ?? 0).toDouble(),
      images: (json['images']?['profiles'] ?? [])
          .map<PersonImage>((img) => PersonImage.fromJson(img))
          .toList(),
      movieCredits: (json['movie_credits']?['cast'] ?? [])
          .map<PersonCredit>((c) => PersonCredit.fromJson(c))
          .toList(),
      tvCredits: (json['tv_credits']?['cast'] ?? [])
          .map<PersonCredit>((c) => PersonCredit.fromJson(c))
          .toList(),
      knownFor: (json['known_for'] ?? [])
          .map<PersonCredit>((c) => PersonCredit.fromJson(c))
          .toList(),
      twitterId: json['external_ids']?['twitter_id'],
      instagramId: json['external_ids']?['instagram_id'],
      facebookId: json['external_ids']?['facebook_id'],
      backdropPath: json['backdrop_path'],
    );
  }
}

class PersonImage {
  final String filePath;
  PersonImage({required this.filePath});
  factory PersonImage.fromJson(Map<String, dynamic> json) =>
      PersonImage(filePath: json['file_path']);
}

class PersonCredit {
  final int id;
  final String? title;
  final String? name;
  final String? posterPath;
  final String? character;
  final String? releaseDate;
  final String? firstAirDate;

  PersonCredit({
    required this.id,
    this.title,
    this.name,
    this.posterPath,
    this.character,
    this.releaseDate,
    this.firstAirDate,
  });

  factory PersonCredit.fromJson(Map<String, dynamic> json) => PersonCredit(
    id: json['id'],
    title: json['title'],
    name: json['name'],
    posterPath: json['poster_path'],
    character: json['character'],
    releaseDate: json['release_date'],
    firstAirDate: json['first_air_date'],
  );
}
