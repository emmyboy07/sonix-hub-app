class Cast {
  final int id;
  final String name;
  final String? profilePath;
  final String character;
  final int order;

  Cast({
    required this.id,
    required this.name,
    this.profilePath,
    required this.character,
    required this.order,
  });

  factory Cast.fromJson(Map<String, dynamic> json) {
    return Cast(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      profilePath: json['profile_path'] as String?,
      character: json['character'] as String? ?? 'Unknown',
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profile_path': profilePath,
      'character': character,
      'order': order,
    };
  }
}
