import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../services/tmdb_service.dart';

class OnboardingItem {
  final String title;
  final String description;
  final String? posterPath;
  final String? backdropPath;

  OnboardingItem({
    required this.title,
    required this.description,
    this.posterPath,
    this.backdropPath,
  });
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentPage = 0;
  List<OnboardingItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 1.1,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0.0, 0.3),
      end: Offset(0.0, 0.0),
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _loadOnboardingMovies();
  }

  Future<void> _loadOnboardingMovies() async {
    try {
      final trendingMovies = await TMDBService.getTrendingMovies();
      final topMovies = await TMDBService.getTopRatedMovies();

      setState(() {
        _items = [
          OnboardingItem(
            title: 'Welcome to Sonix Hub',
            description: 'Your Ultimate Entertainment Destination',
            backdropPath: trendingMovies.isNotEmpty
                ? trendingMovies[0].backdropPath
                : null,
          ),
          OnboardingItem(
            title: 'Unlimited Movies',
            description: 'Stream thousands of blockbusters and hidden gems',
            backdropPath: trendingMovies.isNotEmpty
                ? trendingMovies[1].backdropPath
                : null,
          ),
          OnboardingItem(
            title: 'Personalized For You',
            description: 'Get recommendations tailored to your taste',
            backdropPath: topMovies.isNotEmpty
                ? topMovies[0].backdropPath
                : null,
          ),
          OnboardingItem(
            title: 'Watch Anywhere',
            description: 'Download and enjoy offline anytime, anywhere',
            backdropPath: topMovies.isNotEmpty
                ? topMovies[1].backdropPath
                : null,
          ),
        ];
        _isLoading = false;
      });
      _playAnimations();
    } catch (e) {
      setState(() {
        _items = [
          OnboardingItem(
            title: 'Welcome to Sonix Hub',
            description: 'Your Ultimate Entertainment Destination',
          ),
          OnboardingItem(
            title: 'Unlimited Movies',
            description: 'Stream thousands of blockbusters and hidden gems',
          ),
          OnboardingItem(
            title: 'Personalized For You',
            description: 'Get recommendations tailored to your taste',
          ),
          OnboardingItem(
            title: 'Watch Anywhere',
            description: 'Download and enjoy offline anytime, anywhere',
          ),
        ];
        _isLoading = false;
      });
      _playAnimations();
    }
  }

  void _playAnimations() {
    _scaleController.forward();
    _fadeController.forward();
    _slideController.forward();
  }

  void _resetAnimations() {
    _scaleController.forward(from: 0.0);
    _fadeController.forward(from: 0.0);
    _slideController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
    } catch (e) {
      print('Error saving onboarding state: $e');
    }

    if (mounted) {
      widget.onComplete();
    }
  }

  void _nextPage() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Widget _buildPage(OnboardingItem item, int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image
        if (item.backdropPath != null)
          ScaleTransition(
            scale: _scaleAnimation,
            child: CachedNetworkImage(
              imageUrl: '${AppConfig.tmdbImageBaseUrl}${item.backdropPath}',
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(color: AppTheme.mediumBlack),
              errorWidget: (context, url, error) =>
                  Container(color: AppTheme.mediumBlack),
            ),
          )
        else
          Container(color: AppTheme.mediumBlack),

        // Dark Overlay with Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.5),
                Colors.black.withOpacity(0.9),
              ],
            ),
          ),
        ),

        // Content
        FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip Button at Top
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: AppTheme.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Center Content
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Icon/Circle
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryRed.withOpacity(0.2),
                            border: Border.all(
                              color: AppTheme.primaryRed,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryRed.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _getIconForIndex(index),
                              color: AppTheme.primaryRed,
                              size: 50,
                            ),
                          ),
                        ),
                        SizedBox(height: 40),
                        // Title
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 16),
                        // Description
                        Text(
                          item.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.lightGray,
                            fontSize: 16,
                            height: 1.6,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Section with Dots and Button
                  Column(
                    children: [
                      // Progress Indicator Dots
                      SizedBox(
                        height: 8,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _items.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            return Expanded(
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: _currentPage == index
                                      ? AppTheme.primaryRed
                                      : AppTheme.white.withOpacity(0.3),
                                ),
                                child: _currentPage == index
                                    ? Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          color: AppTheme.primaryRed,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primaryRed
                                                  .withOpacity(0.6),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 24),
                      // Next Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryRed.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _currentPage == _items.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.movie;
      case 1:
        return Icons.play_circle_outline;
      case 2:
        return Icons.favorite_border;
      case 3:
        return Icons.download;
      default:
        return Icons.movie;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _items.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.darkBlack,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryRed),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: AppTheme.lightGray, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
          _resetAnimations();
        },
        physics: NeverScrollableScrollPhysics(),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          return _buildPage(_items[index], index);
        },
      ),
    );
  }
}
