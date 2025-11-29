import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/movies_provider.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../models/movie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? title;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.title,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: widget.title != null
            ? Text(
                widget.title!,
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      body: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
      ),
    );
  }
}

class CastScreen extends StatefulWidget {
  final int personId;
  const CastScreen({super.key, required this.personId});

  @override
  State<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends State<CastScreen> {
  bool bioExpanded = false;
  String activeTab = 'movies';

  @override
  void initState() {
    super.initState();
    // Fetch person details here using provider or any state management
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MoviesProvider>(
        context,
        listen: false,
      ).fetchPersonDetails(widget.personId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MoviesProvider>(
      builder: (context, provider, child) {
        final person = provider.personDetails;
        if (provider.isLoadingPerson) {
          return Scaffold(
            backgroundColor: AppTheme.darkBlack,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRed),
            ),
          );
        }
        if (person == null) {
          return Scaffold(
            backgroundColor: AppTheme.darkBlack,
            body: Center(
              child: Text(
                'Failed to load cast details',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppTheme.darkBlack,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image and Back Button
                  Stack(
                    children: [
                      SizedBox(
                        height: 400,
                        width: double.infinity,
                        child:
                            (person.profilePath != null &&
                                person.profilePath!.isNotEmpty)
                            ? Image.network(
                                person.profilePath!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(color: Colors.grey[900]),
                              )
                            : Container(color: Colors.grey[900]),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Details Card
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (person.birthday != null &&
                            person.birthday!.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.cake, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                person.birthday!,
                                style: TextStyle(color: Colors.white),
                              ),
                              if (person.age != null)
                                Text(
                                  ' (${person.age} years old)',
                                  style: TextStyle(color: AppTheme.primaryRed),
                                ),
                            ],
                          ),
                        if (person.placeOfBirth != null &&
                            person.placeOfBirth!.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                person.placeOfBirth!,
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.trending_up, color: AppTheme.primaryRed),
                            SizedBox(width: 4),
                            Text(
                              'Popularity: ${person.popularity.toStringAsFixed(1)}',
                              style: TextStyle(color: Colors.white),
                            ),
                            SizedBox(width: 16),
                            Icon(Icons.movie, color: AppTheme.primaryRed),
                            SizedBox(width: 4),
                            Text(
                              'Known Credits: ${person.knownCredits}',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            if (person.twitterId != null &&
                                person.twitterId!.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  Icons.alternate_email,
                                  color: AppTheme.primaryRed,
                                ),
                                onPressed: () => _launchURL(
                                  'https://twitter.com/${person.twitterId}',
                                ),
                              ),
                            if (person.instagramId != null &&
                                person.instagramId!.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  Icons.camera_alt,
                                  color: AppTheme.primaryRed,
                                ),
                                onPressed: () => _launchURL(
                                  'https://instagram.com/${person.instagramId}',
                                ),
                              ),
                            if (person.facebookId != null &&
                                person.facebookId!.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  Icons.facebook,
                                  color: AppTheme.primaryRed,
                                ),
                                onPressed: () => _launchURL(
                                  'https://facebook.com/${person.facebookId}',
                                ),
                              ),
                            if ((person.twitterId == null ||
                                    person.twitterId!.isEmpty) &&
                                (person.instagramId == null ||
                                    person.instagramId!.isEmpty) &&
                                (person.facebookId == null ||
                                    person.facebookId!.isEmpty))
                              Text(
                                'No social links available',
                                style: TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Biography
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biography',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          bioExpanded
                              ? person.biography
                              : (person.biography.length > 300
                                    ? '${person.biography.substring(0, 300)}...'
                                    : person.biography),
                          style: TextStyle(color: Colors.white70),
                        ),
                        if (person.biography.length > 300)
                          TextButton(
                            onPressed: () =>
                                setState(() => bioExpanded = !bioExpanded),
                            child: Text(
                              bioExpanded ? 'Read Less' : 'Read More',
                              style: TextStyle(color: AppTheme.primaryRed),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Photos Gallery
                  if (person.images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Photos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          SizedBox(
                            height: 140,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: person.images.length,
                              separatorBuilder: (_, __) => SizedBox(width: 12),
                              itemBuilder: (context, idx) {
                                final img = person.images[idx];
                                final imageUrl =
                                    '${AppConfig.tmdbImageBaseUrl}${img.filePath}';
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FullScreenImageViewer(
                                          imageUrl: imageUrl,
                                          title: person.name,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      width: 100,
                                      height: 140,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          Container(
                                            color: AppTheme.mediumBlack,
                                          ),
                                      errorWidget: (context, url, error) =>
                                          Icon(
                                            Icons.broken_image,
                                            color: AppTheme.lightGray,
                                          ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (person.images.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 24),
                      child: Text(
                        'No photos available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  // Known For
                  if (person.knownFor.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Known For',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          SizedBox(
                            height: 220,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: person.knownFor.length,
                              separatorBuilder: (_, __) => SizedBox(width: 12),
                              itemBuilder: (context, idx) {
                                final item = person.knownFor[idx];
                                final imageUrl = item.posterPath != null
                                    ? '${AppConfig.tmdbImageBaseUrl}${item.posterPath}'
                                    : null;
                                final title = item.title ?? item.name ?? '';
                                final character = item.character ?? 'Unknown Role';

                                return GestureDetector(
                                  onTap: () {
                                    // Navigate to details screen
                                    final movie = Movie(
                                      id: item.id,
                                      title: title,
                                      posterPath: item.posterPath ?? '',
                                      backdropPath: '',
                                      overview: '',
                                      voteAverage: 0.0,
                                      releaseDate: item.releaseDate ?? '',
                                      genreIds: [],
                                      mediaType: item.title != null
                                          ? 'movie'
                                          : 'tv',
                                    );
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DetailsScreen(movie: movie),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 100,
                                          height: 140,
                                          color: AppTheme.mediumBlack,
                                          child: imageUrl != null
                                              ? CachedNetworkImage(
                                                  imageUrl: imageUrl,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Container(
                                                        color: AppTheme
                                                            .mediumBlack,
                                                      ),
                                                  errorWidget: (context, url,
                                                          error) =>
                                                      Icon(
                                                        Icons.movie,
                                                        color: AppTheme
                                                            .lightGray,
                                                        size: 40,
                                                      ),
                                                )
                                              : Icon(
                                                  Icons.movie,
                                                  color: AppTheme.lightGray,
                                                  size: 40,
                                                ),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      SizedBox(
                                        width: 100,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              character,
                                              style: TextStyle(
                                                color: AppTheme.primaryRed,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Tabs for Movies and TV Shows
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 24,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => activeTab = 'movies'),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: activeTab == 'movies'
                                  ? AppTheme.primaryRed
                                  : Colors.grey[900],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Movies (${person.movieCredits.length})',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setState(() => activeTab = 'tv'),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: activeTab == 'tv'
                                  ? AppTheme.primaryRed
                                  : Colors.grey[900],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'TV Shows (${person.tvCredits.length})',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (activeTab == 'movies')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: person.movieCredits
                            .map(
                              (movie) => GestureDetector(
                                onTap: () {
                                  final movieObj = Movie(
                                    id: movie.id,
                                    title: movie.title ?? '',
                                    posterPath: movie.posterPath ?? '',
                                    backdropPath: '',
                                    overview: '',
                                    voteAverage: 0.0,
                                    releaseDate: movie.releaseDate ?? '',
                                    genreIds: [],
                                    mediaType: 'movie',
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DetailsScreen(movie: movieObj),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 100,
                                        height: 140,
                                        color: AppTheme.mediumBlack,
                                        child: movie.posterPath != null &&
                                                movie.posterPath!.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl:
                                                    '${AppConfig.tmdbImageBaseUrl}${movie.posterPath}',
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    Container(
                                                      color: AppTheme
                                                          .mediumBlack,
                                                    ),
                                                errorWidget: (context, url,
                                                        error) =>
                                                    Icon(
                                                      Icons.movie,
                                                      color: AppTheme
                                                          .lightGray,
                                                      size: 40,
                                                    ),
                                              )
                                            : Icon(
                                                Icons.movie,
                                                color: AppTheme.lightGray,
                                                size: 40,
                                              ),
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    SizedBox(
                                      width: 100,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            movie.title ?? '',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                          if (movie.character != null &&
                                              movie.character!.isNotEmpty)
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(top: 4),
                                              child: Text(
                                                movie.character ?? '',
                                                style: TextStyle(
                                                  color: AppTheme.primaryRed,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (activeTab == 'tv')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: person.tvCredits
                            .map(
                              (show) => GestureDetector(
                                onTap: () {
                                  final tvShow = Movie(
                                    id: show.id,
                                    title: show.name ?? '',
                                    posterPath: show.posterPath ?? '',
                                    backdropPath: '',
                                    overview: '',
                                    voteAverage: 0.0,
                                    releaseDate: show.firstAirDate ?? '',
                                    genreIds: [],
                                    mediaType: 'tv',
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DetailsScreen(movie: tvShow),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 100,
                                        height: 140,
                                        color: AppTheme.mediumBlack,
                                        child: show.posterPath != null &&
                                                show.posterPath!.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl:
                                                    '${AppConfig.tmdbImageBaseUrl}${show.posterPath}',
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    Container(
                                                      color: AppTheme
                                                          .mediumBlack,
                                                    ),
                                                errorWidget: (context, url,
                                                        error) =>
                                                    Icon(
                                                      Icons.tv,
                                                      color: AppTheme
                                                          .lightGray,
                                                      size: 40,
                                                    ),
                                              )
                                            : Icon(
                                                Icons.tv,
                                                color: AppTheme.lightGray,
                                                size: 40,
                                              ),
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    SizedBox(
                                      width: 100,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            show.name ?? '',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                          if (show.character != null &&
                                              show.character!.isNotEmpty)
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(top: 4),
                                              child: Text(
                                                show.character ?? '',
                                                style: TextStyle(
                                                  color: AppTheme.primaryRed,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }
}
