import 'package:flutter/material.dart';
import '../config/theme.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: const Text('About Us'),
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
                      color: AppTheme.primaryRed,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'SH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sonix Hub',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'v2.0.0',
                    style: TextStyle(color: AppTheme.lightGray, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'About Sonix Hub',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sonix Hub is a premium streaming application that brings you the latest movies and TV shows in stunning quality. Our platform is designed to provide an exceptional viewing experience with a vast library of content from around the world.',
              style: TextStyle(
                color: AppTheme.lightGray,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Key Features',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._buildFeatureList(),
            const SizedBox(height: 24),
            Text(
              'Our Mission',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'To provide world-class entertainment to audiences worldwide by offering a seamless streaming experience with high-quality content across all devices.',
              style: TextStyle(
                color: AppTheme.lightGray,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Contact Information',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContactInfo('Website:', 'www.sonixhub.app'),
                  const SizedBox(height: 12),
                  _buildContactInfo('Email:', 'info@sonixhub.app'),
                  const SizedBox(height: 12),
                  _buildContactInfo('Support:', 'support@sonixhub.app'),
                  const SizedBox(height: 12),
                  _buildContactInfo('Phone:', '+1 (555) 123-4567'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '© 2024 Sonix Hub. All rights reserved.',
                style: TextStyle(color: AppTheme.lightGray, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static List<Widget> _buildFeatureList() {
    final features = [
      '4K and HDR streaming quality',
      'Download content for offline viewing',
      'Multiple device support',
      'Personalized recommendations',
      'Release date reminders',
      '24/7 customer support',
    ];

    return features.map((feature) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.primaryRed, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                feature,
                style: TextStyle(color: AppTheme.lightGray, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  static Widget _buildContactInfo(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value, style: TextStyle(color: AppTheme.primaryRed)),
        ),
      ],
    );
  }
}
