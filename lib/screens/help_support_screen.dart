import 'package:flutter/material.dart';
import '../config/theme.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I reset my password?',
      'answer':
          'Go to the login screen and tap "Forgot Password". Enter your email and follow the instructions sent to your mailbox.',
    },
    {
      'question': 'How do I download content?',
      'answer':
          'Open any movie or episode, tap the Download button, select quality, and it will start downloading.',
    },
    {
      'question': 'Can I watch offline?',
      'answer':
          'Yes! Download content with your Standard or Premium subscription and watch offline anytime.',
    },
    {
      'question': 'How many devices can I use?',
      'answer':
          'Basic: 1 device, Standard: 2 devices, Premium: 4 devices simultaneously.',
    },
    {
      'question': 'How do I cancel my subscription?',
      'answer':
          'Go to Profile > Subscriptions > Manage Subscription and tap Cancel.',
    },
  ];

  int? _expandedIndex;

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.mediumBlack,
          title: Text(
            'Contact Support',
            style: TextStyle(color: AppTheme.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.email, color: AppTheme.primaryRed),
                  title: Text('Email', style: TextStyle(color: AppTheme.white)),
                  subtitle: Text(
                    'support@sonixhub.app',
                    style: TextStyle(color: AppTheme.lightGray),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: Icon(Icons.phone, color: AppTheme.primaryRed),
                  title: Text('Phone', style: TextStyle(color: AppTheme.white)),
                  subtitle: Text(
                    '+1 (555) 123-4567',
                    style: TextStyle(color: AppTheme.lightGray),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: Icon(Icons.chat, color: AppTheme.primaryRed),
                  title: Text(
                    'Live Chat',
                    style: TextStyle(color: AppTheme.white),
                  ),
                  subtitle: Text(
                    'Available 24/7',
                    style: TextStyle(color: AppTheme.lightGray),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: AppTheme.primaryRed),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppTheme.darkBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.mediumBlack,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: AppTheme.primaryRed,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need Help?',
                          style: TextStyle(
                            color: AppTheme.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'We\'re here to help. Contact us anytime.',
                          style: TextStyle(
                            color: AppTheme.lightGray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _contactSupport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Contact',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Frequently Asked Questions',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._faqs.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, String> faq = entry.value;
              bool isExpanded = _expandedIndex == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.mediumBlack,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      faq['question'] ?? '',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppTheme.primaryRed,
                    ),
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _expandedIndex = expanded ? index : null;
                      });
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          faq['answer'] ?? '',
                          style: TextStyle(
                            color: AppTheme.lightGray,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.mediumBlack.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryRed.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Version',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sonix Hub v2.0.0',
                    style: TextStyle(color: AppTheme.lightGray, fontSize: 13),
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
