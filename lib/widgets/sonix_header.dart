import 'package:flutter/material.dart';
import '../config/theme.dart';

class SonixHeader extends StatelessWidget {
  final VoidCallback onSearchPressed;

  const SonixHeader({super.key, required this.onSearchPressed});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: AppTheme.darkBlack,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Sonix ',
              style: TextStyle(
                color: AppTheme.primaryRed,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Hub',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            GestureDetector(
              onTap: onSearchPressed,
              child: Icon(Icons.search, color: AppTheme.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}
