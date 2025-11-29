import 'package:flutter/material.dart';
import '../config/theme.dart';

class PlaybackSettingsScreen extends StatefulWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  State<PlaybackSettingsScreen> createState() => _PlaybackSettingsScreenState();
}

class _PlaybackSettingsScreenState extends State<PlaybackSettingsScreen> {
  String _videoQuality = 'Auto';
  String _playbackSpeed = '1.0x';
  bool _autoplay = true;
  bool _continuePlaying = true;
  String _audioLanguage = 'English';

  final List<String> _qualityOptions = ['Auto', '480p', '720p', '1080p', '4K'];
  final List<String> _speedOptions = [
    '0.5x',
    '0.75x',
    '1.0x',
    '1.25x',
    '1.5x',
    '2.0x',
  ];
  final List<String> _audioLanguages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Italian',
    'Hindi',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: const Text('Playback Settings'),
        backgroundColor: AppTheme.darkBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Video Quality',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.mediumBlack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _videoQuality,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: AppTheme.mediumBlack,
                style: TextStyle(color: AppTheme.white),
                items: _qualityOptions.map((quality) {
                  return DropdownMenuItem<String>(
                    value: quality,
                    child: Text(quality),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _videoQuality = value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Video quality set to $value'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: AppTheme.primaryRed,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Playback Speed',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.mediumBlack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _playbackSpeed,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: AppTheme.mediumBlack,
                style: TextStyle(color: AppTheme.white),
                items: _speedOptions.map((speed) {
                  return DropdownMenuItem<String>(
                    value: speed,
                    child: Text(speed),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _playbackSpeed = value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Playback speed set to $value'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: AppTheme.primaryRed,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Audio Language',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.mediumBlack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _audioLanguage,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: AppTheme.mediumBlack,
                style: TextStyle(color: AppTheme.white),
                items: _audioLanguages.map((language) {
                  return DropdownMenuItem<String>(
                    value: language,
                    child: Text(language),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _audioLanguage = value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Audio language set to $value'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: AppTheme.primaryRed,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Preferences',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.mediumBlack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Autoplay',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Play next episode automatically',
                            style: TextStyle(
                              color: AppTheme.lightGray,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _autoplay,
                        onChanged: (value) {
                          setState(() => _autoplay = value);
                        },
                        activeThumbColor: AppTheme.primaryRed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Continue Playing',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Resume from last position',
                            style: TextStyle(
                              color: AppTheme.lightGray,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _continuePlaying,
                        onChanged: (value) {
                          setState(() => _continuePlaying = value);
                        },
                        activeThumbColor: AppTheme.primaryRed,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
