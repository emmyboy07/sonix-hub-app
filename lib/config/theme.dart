import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryRed = Color(0xFFE50914); // Netflix Red
  static const Color darkBlack = Color(0xFF000000); // Pure black
  static const Color mediumBlack = Color(0xFF000000); // Pure black
  static const Color lightGray = Color(0xFFB3B3B3);
  static const Color accentRed = Color(0xFFFF0000);
  static const Color redAccent = Color(0xFFFF0000); // Alias for accentRed
  static const Color white = Colors.white;

  // Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: primaryRed,
        secondary: accentRed,
        surface: mediumBlack,
        error: Colors.red,
      ),
      scaffoldBackgroundColor: darkBlack,
      appBarTheme: AppBarTheme(
        backgroundColor: darkBlack,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: lightGray, fontSize: 16),
        bodyMedium: TextStyle(color: lightGray, fontSize: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: mediumBlack,
        selectedItemColor: primaryRed,
        unselectedItemColor: lightGray,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      iconTheme: IconThemeData(color: white),
    );
  }
}
