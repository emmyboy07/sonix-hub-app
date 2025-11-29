import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/movies_provider.dart';
import '../widgets/movie_card.dart';
import 'details_screen.dart';
import '../widgets/sonix_header.dart';
import 'search_screen.dart';
import '../utils/page_transitions.dart';

class FavouriteScreen extends StatelessWidget {
  const FavouriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SonixHeader(
              onSearchPressed: () {
                navigateWithTransition(context, const SearchScreen());
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'My Favorites',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<MoviesProvider>(
                builder: (context, provider, child) {
                  if (provider.favouriteMovies.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite_outline,
                              color: AppTheme.primaryRed,
                              size: 80,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No Favourites Yet',
                              style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add movies to your favorites to see them here',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.lightGray,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: provider.favouriteMovies.length,
                    itemBuilder: (context, index) {
                      final movie = provider.favouriteMovies[index];
                      return GestureDetector(
                        onLongPress: () {
                          _showRemoveDialog(context, provider, movie);
                        },
                        child: MovieCard(
                          posterPath: movie.posterPath,
                          title: movie.title,
                          rating: movie.voteAverage,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DetailsScreen(movie: movie),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveDialog(
    BuildContext context,
    MoviesProvider provider,
    dynamic movie,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.mediumBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGray.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Remove from Favorites?',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  movie.title,
                  style: TextStyle(color: AppTheme.lightGray, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.primaryRed),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Cancel',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.primaryRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await provider.removeFavourite(movie.id);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Removed from favorites'),
                              backgroundColor: AppTheme.primaryRed,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Remove',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
