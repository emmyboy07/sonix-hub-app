import 'package:flutter/material.dart';
import '../config/theme.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final List<Map<String, dynamic>> _subscriptionPlans = [
    {
      'name': 'Free',
      'price': 'Free',
      'features': [
        'Everything Free',
        'Standard Quality',
        'Standard Subtitles',
        'Streaming Only',
        '1 Device',
      ],
      'isActive': true,
    },
    {
      'name': 'Premium',
      'priceVariants': [
        {
          'duration': 'Monthly',
          'price': '₦1,500',
          'totalPrice': '₦1,500/month',
          'period': 'per month',
          'savings': null,
          'savingsPercent': null,
        },
        {
          'duration': '3 Months',
          'price': '₦3,800',
          'totalPrice': '₦3,800',
          'period': 'for 3 months',
          'savings': '₦700',
          'savingsPercent': '15%',
        },
        {
          'duration': '6 Months',
          'price': '₦7,200',
          'totalPrice': '₦7,200',
          'period': 'for 6 months',
          'savings': '₦2,800',
          'savingsPercent': '28%',
        },
        {
          'duration': '1 Year',
          'price': '₦13,200',
          'totalPrice': '₦13,200',
          'period': 'for 1 year',
          'savings': '₦6,600',
          'savingsPercent': '33%',
        },
      ],
      'features': [
        'HD Video Quality',
        'Quality Subtitles',
        'External Downloads',
        'Fast Playback Speed',
        'Multiple Concurrent Downloads',
        'Ads Free',
      ],
      'isActive': false,
    },
  ];

  int _selectedPriceVariant = 0;

  Future<void> _upgradePlan(String planName, String price) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.mediumBlack,
          title: Text(
            'Upgrade to $planName',
            style: TextStyle(color: AppTheme.white),
          ),
          content: Text(
            'This will upgrade your subscription to $price.',
            style: TextStyle(color: AppTheme.lightGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.lightGray),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.white),
                        const SizedBox(width: 12),
                        Text('Upgraded to $planName successfully'),
                      ],
                    ),
                    backgroundColor: Colors.green.withOpacity(0.8),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
              child: Text(
                'Upgrade',
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
        title: const Text('Subscriptions'),
        backgroundColor: AppTheme.darkBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Subscription',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Free Plan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Currently Active',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                    ),
                    child: Text(
                      'Manage Subscription',
                      style: TextStyle(color: AppTheme.primaryRed),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Available Plans',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._subscriptionPlans.map((plan) {
              if (plan['isActive']) {
                return const SizedBox.shrink();
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.mediumBlack,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryRed, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          plan['name'],
                          style: TextStyle(
                            color: AppTheme.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Best Value',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Price variants selection
                    Text(
                      'Choose Your Plan',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(plan['priceVariants'] as List<Map<String, dynamic>>)
                        .asMap()
                        .entries
                        .map((entry) {
                          final index = entry.key;
                          final variant = entry.value;
                          final isSelected = _selectedPriceVariant == index;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPriceVariant = index;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryRed.withOpacity(0.15)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryRed
                                        : Colors.white.withOpacity(0.2),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          variant['duration'],
                                          style: TextStyle(
                                            color: AppTheme.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          variant['period'],
                                          style: TextStyle(
                                            color: AppTheme.lightGray,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          variant['price'],
                                          style: TextStyle(
                                            color: AppTheme.primaryRed,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (variant['savings'] != null) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Save ${variant['savings']} (${variant['savingsPercent']})',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    const SizedBox(height: 20),
                    // Features list
                    Text(
                      'Features Included',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(plan['features'] as List<String>).map(
                      (feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryRed,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              feature,
                              style: TextStyle(
                                color: AppTheme.lightGray,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _upgradePlan(
                          plan['name'],
                          _subscriptionPlans[1]['priceVariants'][_selectedPriceVariant]['totalPrice'],
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Upgrade Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
