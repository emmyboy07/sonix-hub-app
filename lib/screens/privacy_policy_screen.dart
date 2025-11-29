import 'package:flutter/material.dart';
import '../config/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: AppTheme.darkBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: November 2024',
              style: TextStyle(color: AppTheme.lightGray, fontSize: 12),
            ),
            const SizedBox(height: 24),
            _buildPolicySection(
              'Introduction',
              'Sonix Hub is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and otherwise process your information.',
            ),
            _buildPolicySection(
              'Information We Collect',
              'Account Information: Name, email address, phone number, and profile preferences. Device Information: Device type, operating system, unique device identifiers. Usage Information: Watched content, search history, and viewing patterns.',
            ),
            _buildPolicySection(
              'How We Use Information',
              'To provide and maintain our services, to process transactions, to send promotional communications, to improve our platform, and to comply with legal obligations.',
            ),
            _buildPolicySection(
              'Data Security',
              'We implement industry-standard security measures including encryption, secure servers, and regular security audits to protect your personal information.',
            ),
            _buildPolicySection(
              'Your Rights',
              'You have the right to access, update, correct, or delete your personal information at any time through your account settings. You can also opt-out of promotional communications.',
            ),
            _buildPolicySection(
              'Cookies and Tracking',
              'We use cookies and similar tracking technologies to enhance your experience, remember preferences, and analyze platform usage.',
            ),
            _buildPolicySection(
              'Third-Party Sharing',
              'We do not sell your personal information. We may share data with service providers who assist us in operating our platform.',
            ),
            _buildPolicySection(
              'Contact Us',
              'If you have questions about this Privacy Policy, please contact us at privacy@sonixhub.app or through our support page.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static Widget _buildPolicySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: AppTheme.lightGray,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
