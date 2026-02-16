import 'package:flutter/material.dart';

/// Centralized class to provide the application's theme data.
class AppTheme {
  // Define custom colors to match the app's branding
  static const Color _primaryTeal = Color(0xFF0D9488);
  static const Color _secondaryCyan = Color(0xFF06B6D4);
  static const Color _accentTealLight = Color(0xFF14B8A6);
  
  // Light Theme Colors
  static const Color _lightScaffoldBg = Color(0xFFF3F4F6); // Gray 100/50 mix
  static const Color _lightCardBg = Colors.white;
  static const Color _lightTextPrimary = Color(0xFF111827); // Gray 900
  static const Color _lightTextSecondary = Color(0xFF6B7280); // Gray 500

  // Dark Theme Colors
  static const Color _darkScaffoldBg = Color(0xFF1F2937); // Gray 800
  static const Color _darkCardBg = Color(0xFF374151); // Gray 700
  static const Color _darkTextPrimary = Colors.white;
  static const Color _darkTextSecondary = Colors.white70;

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: _primaryTeal,
      scaffoldBackgroundColor: _lightScaffoldBg,
      
      colorScheme: const ColorScheme.light(
        primary: _primaryTeal,
        secondary: _secondaryCyan,
        surface: _lightCardBg,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _lightTextPrimary,
        tertiary: _accentTealLight,
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(color: _lightTextPrimary, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: _lightTextPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: _lightTextPrimary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: _lightTextPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: _lightTextPrimary),
        bodyMedium: TextStyle(color: _lightTextSecondary),
        labelLarge: TextStyle(color: _lightTextPrimary), // Button text
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: _lightTextPrimary),
        titleTextStyle: TextStyle(
          color: _lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),

      iconTheme: const IconThemeData(
        color: _primaryTeal,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightCardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _primaryTeal, width: 2),
        ),
        labelStyle: const TextStyle(color: _lightTextSecondary),
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: _primaryTeal,
      scaffoldBackgroundColor: _darkScaffoldBg,

      colorScheme: const ColorScheme.dark(
        primary: _primaryTeal,
        secondary: _secondaryCyan,
        surface: _darkCardBg,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _darkTextPrimary,
        tertiary: _accentTealLight,
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(color: _darkTextPrimary, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: _darkTextPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: _darkTextPrimary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: _darkTextPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: _darkTextPrimary),
        bodyMedium: TextStyle(color: _darkTextSecondary),
        labelLarge: TextStyle(color: _darkTextPrimary),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: _darkTextPrimary),
        titleTextStyle: TextStyle(
          color: _darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),

      iconTheme: const IconThemeData(
        color: _primaryTeal,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkCardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade700, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade700, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _primaryTeal, width: 2),
        ),
        labelStyle: const TextStyle(color: _darkTextSecondary),
        hintStyle: TextStyle(color: Colors.grey.shade500),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }
}
