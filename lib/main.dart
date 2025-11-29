import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'providers/movies_provider.dart';
import 'providers/comments_provider.dart';
import 'services/permission_handler_service.dart';
import 'services/background_release_checker.dart';
import 'services/update_service.dart';
import 'widgets/force_update_dialog.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/favourite_screen.dart';
import 'screens/live_tv_screen.dart';
import 'screens/download_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Configure Flutter image cache for faster memory-based image loading
  imageCache.maximumSize = 150; // Maximum number of images to keep in memory
  imageCache.maximumSizeBytes = 512 * 1024 * 1024; // 512 MB max cache size

  // Force plugin inclusion
  InAppWebView();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MoviesProvider()),
        ChangeNotifierProvider(create: (_) => CommentsProvider()),
      ],
      child: MaterialApp(
        title: 'Sonix Hub',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const _InitializeScreen(),
        routes: {
          '/home': (context) => const MainApp(),
          '/onboarding': (context) => OnboardingScreen(
            onComplete: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
          ),
        },
      ),
    );
  }
}

class _InitializeScreen extends StatefulWidget {
  const _InitializeScreen();

  @override
  State<_InitializeScreen> createState() => _InitializeScreenState();
}

class _InitializeScreenState extends State<_InitializeScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Request permissions first
      final permissionService = PermissionHandlerService();
      await permissionService.requestAllPermissions();
      debugPrint('✅ Permissions requested');

      // Initialize background release checker for notifications
      final backgroundChecker = BackgroundReleaseChecker();
      await backgroundChecker.initialize();
      debugPrint('✅ Background release checker initialized');

      // Check for app updates
      await _checkForUpdates();

      // Check onboarding status
      await _checkOnboardingStatus();
    } catch (e) {
      debugPrint('❌ Error initializing app: $e');
      await _checkOnboardingStatus();
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final updateResult = await UpdateService.checkForUpdate();
      if (updateResult != null && updateResult.needsUpdate && mounted) {
        // Wait for widget tree to be ready
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          debugPrint('📲 Update dialog shown');
          // Show update dialog and wait for user action
          await showDialog(
            context: context,
            barrierDismissible: !updateResult.isForceUpdate,
            builder: (context) => ForceUpdateDialog(
              versionInfo: updateResult.versionInfo,
              isForceUpdate: updateResult.isForceUpdate,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking for updates: $e');
      // Continue with app even if update check fails
    }
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isOnboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    if (mounted) {
      if (isOnboardingComplete) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.darkBlack,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const FavouriteScreen(),
      const LiveTVScreen(),
      const DownloadScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppTheme.mediumBlack.withOpacity(0.5),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomAppBar(
          color: AppTheme.darkBlack,
          elevation: 0,
          padding: EdgeInsets.zero,
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                context: context,
              ),
              _buildNavItem(
                icon: Icons.favorite_rounded,
                label: 'Favourite',
                index: 1,
                context: context,
              ),
              _buildNavItem(
                icon: Icons.live_tv_rounded,
                label: 'Live TV',
                index: 2,
                context: context,
              ),
              _buildNavItem(
                icon: Icons.download_rounded,
                label: 'Download',
                index: 3,
                context: context,
              ),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                index: 4,
                context: context,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required BuildContext context,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.primaryRed : AppTheme.lightGray,
            size: 24,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryRed : AppTheme.lightGray,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: isSelected ? 0.2 : 0,
            ),
          ),
        ],
      ),
    );
  }
}
