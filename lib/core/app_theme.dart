import 'package:flutter/material.dart';

/// Centralized class to provide the application's theme data.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.grey[200],
      primaryColor: Colors.grey[100],
      colorScheme: ColorScheme.light(
        primary: Colors.grey[600]!,
        secondary: Colors.grey[500]!,
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: Colors.grey[800]),
        titleMedium: TextStyle(color: Colors.grey[900]),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide.none, // Use BorderSide.none if filled: true
        ),
        labelStyle: TextStyle(color: Colors.grey[700]),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[100],
        titleTextStyle: TextStyle(color: Colors.grey[800], fontSize: 20),
        iconTheme: IconThemeData(color: Colors.grey[800]),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[600],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.grey[600],
      ),
    );
  }
}
