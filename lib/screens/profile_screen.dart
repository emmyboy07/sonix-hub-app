import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import 'edit_profile_screen.dart';
import 'subscriptions_screen.dart';
import 'download_settings_screen.dart';
import 'playback_settings_screen.dart';
import 'comment_settings_screen.dart';
import 'help_support_screen.dart';
import 'about_us_screen.dart';
import 'privacy_policy_screen.dart';
import 'watch_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Guest User';
  String _userEmail = 'guest@sonixhub.app';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Guest User';
      _userEmail = prefs.getString('user_email') ?? 'guest@sonixhub.app';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppTheme.darkBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.mediumBlack,
                      border: Border.all(color: AppTheme.primaryRed, width: 3),
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppTheme.primaryRed,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userName,
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userEmail,
                    style: TextStyle(color: AppTheme.lightGray, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Account Settings',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileOption(
              context,
              'Edit Profile',
              Icons.edit,
              EditProfileScreen(),
            ),
            _buildProfileOption(
              context,
              'Watch History',
              Icons.history,
              WatchHistoryScreen(),
            ),
            _buildProfileOption(
              context,
              'Subscriptions',
              Icons.card_membership,
              SubscriptionsScreen(),
            ),
            _buildProfileOption(
              context,
              'Download Settings',
              Icons.download,
              DownloadSettingsScreen(),
            ),
            _buildProfileOption(
              context,
              'Playback Settings',
              Icons.play_circle_outline,
              PlaybackSettingsScreen(),
            ),
            _buildProfileOption(
              context,
              'Comment Settings',
              Icons.chat_outlined,
              CommentSettingsScreen(),
            ),
            const SizedBox(height: 24),
            Text(
              'More',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileOption(
              context,
              'Help & Support',
              Icons.help_outline,
              HelpSupportScreen(),
            ),
            _buildProfileOption(
              context,
              'About Us',
              Icons.info_outline,
              AboutUsScreen(),
            ),
            _buildProfileOption(
              context,
              'Privacy Policy',
              Icons.privacy_tip_outlined,
              PrivacyPolicyScreen(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context,
    String title,
    IconData icon,
    Widget screen,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.mediumBlack,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppTheme.primaryRed),
          title: Text(
            title,
            style: TextStyle(color: AppTheme.white, fontSize: 14),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: AppTheme.lightGray,
            size: 16,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => screen),
            ).then((_) {
              // Reload profile when returning from edit screen
              if (title == 'Edit Profile') {
                _loadUserProfile();
              }
            });
          },
        ),
      ),
    );
  }
}
