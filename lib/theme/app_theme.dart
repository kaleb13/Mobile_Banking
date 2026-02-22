import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color backgroundTop = Color(0xFF0F2027); // Dark teal
  static const Color backgroundBottom = Color(0xFF203A43);
  static const Color primaryTeal = Color(0xFF0D9488); // Success/Income
  static const Color alertRed = Color(0xFFE11D48); // Expense
  static const Color surfaceDark = Color(0xFF1E1E1E); // Card background
  static const Color surfaceLight = Color(0xFF2A2A2A); // Card elevated
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9CA3AF);
  static const Color borderSubtle = Color(0x33FFFFFF);

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF051114), // very dark green top
      Color(0xFF0B1416), // near black middle
      Color(0xFF131313), // dark bottom surface
      Color(0xFF0F0F0F), // pure dark
    ],
    stops: [0.0, 0.4, 0.7, 1.0],
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryTeal,
      scaffoldBackgroundColor: AppColors.backgroundTop,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: AppColors.textWhite,
        displayColor: AppColors.textWhite,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: AppColors.textWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
