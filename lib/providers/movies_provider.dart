import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonix_hub/models/movie.dart';
import '../services/tmdb_service.dart';
import 'dart:convert';
import 'dart:async';

import '../models/person_details.dart';

class MoviesProvider extends ChangeNotifier {
  List<Movie> _trendingMovies = [];
  List<Movie> _topRatedMovies = [];
  List<Movie> _popularMovies = [];
  List<Movie> _upcomingMovies = [];
  final List<Movie> _favouriteMovies = [];
  List<Movie> _searchResults = [];

  // Person details state
  PersonDetails? _personDetails;
  bool _isLoadingPerson = false;
  String? _personErrorMessage;

  bool _isLoading = false;
  String? _errorMessage;

  // Debounce timer for search
  Timer? _searchDebounce;

  // Getters
  List<Movie> get trendingMovies => _trendingMovies;
  List<Movie> get topRatedMovies => _topRatedMovies;
  List<Movie> get popularMovies => _popularMovies;
  List<Movie> get upcomingMovies => _upcomingMovies;
  List<Movie> get favouriteMovies => _favouriteMovies;
  List<Movie> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  PersonDetails? get personDetails => _personDetails;
  bool get isLoadingPerson => _isLoadingPerson;
  String? get personErrorMessage => _personErrorMessage;
  // Fetch person details for cast page
  Future<void> fetchPersonDetails(int personId) async {
    _isLoadingPerson = true;
    _personErrorMessage = null;
    notifyListeners();
    try {
      final details = await TMDBService.getPersonDetailsFull(personId);
      _personDetails = details;
    } catch (e) {
      _personErrorMessage = e.toString();
      _personDetails = null;
    }
    _isLoadingPerson = false;
    notifyListeners();
  }

  // Get movie list by type for optimized Consumer selector
  List<Movie> getMovieList(String type) {
    switch (type) {
      case 'trending':
        return _trendingMovies;
      case 'topRated':
        return _topRatedMovies;
      case 'popular':
        return _popularMovies;
      case 'upcoming':
        return _upcomingMovies;
      default:
        return [];
    }
  }

  MoviesProvider() {
    _loadFavourites();
  }

  // Load favourites from shared preferences
  Future<void> _loadFavourites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favouritesJson = prefs.getStringList('favourites') ?? [];
      _favouriteMovies.clear();
      for (final json in favouritesJson) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          _favouriteMovies.add(Movie.fromJson(map));
        } catch (e) {
          print('Error parsing favourite: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error loading favourites: $e');
    }
  }

  // Save favourites to shared preferences
  Future<void> _saveFavourites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favouritesJson = _favouriteMovies
          .map((m) => jsonEncode(m.toJson()))
          .toList();
      await prefs.setStringList('favourites', favouritesJson);
    } catch (e) {
      print('Error saving favourites: $e');
    }
  }

  // Load all movies
  Future<void> loadAllMovies() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadTrendingMovies(),
        _loadTopRatedMovies(),
        _loadPopularMovies(),
        _loadUpcomingMovies(),
      ]);
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadTrendingMovies() async {
    _trendingMovies = await TMDBService.getTrendingMovies();
  }

  Future<void> _loadTopRatedMovies() async {
    _topRatedMovies = await TMDBService.getTopRatedMovies();
  }

  Future<void> _loadPopularMovies() async {
    _popularMovies = await TMDBService.getPopularMovies();
  }

  Future<void> _loadUpcomingMovies() async {
    _upcomingMovies = await TMDBService.getUpcomingMovies();
  }

  Future<void> searchMovies(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    // Cancel previous search debounce
    _searchDebounce?.cancel();

    // Debounce search requests by 500ms to avoid excessive API calls
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      _isLoading = true;
      notifyListeners();

      try {
        _searchResults = await TMDBService.searchMovies(query);
      } catch (e) {
        _errorMessage = e.toString();
        _searchResults = [];
      }

      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addFavourite(Movie movie) async {
    if (!_favouriteMovies.any((m) => m.id == movie.id)) {
      _favouriteMovies.add(movie);
      await _saveFavourites();
      notifyListeners();
    }
  }

  Future<void> removeFavourite(int movieId) async {
    _favouriteMovies.removeWhere((m) => m.id == movieId);
    await _saveFavourites();
    notifyListeners();
  }

  bool isFavourite(int movieId) {
    return _favouriteMovies.any((m) => m.id == movieId);
  }

  List<Movie> getFavoriteMovies() {
    return _favouriteMovies;
  }
}
