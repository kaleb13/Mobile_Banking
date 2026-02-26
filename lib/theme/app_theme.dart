import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF0D739F); // Success/Income/Primary
  static const Color accentBlue = Color(0xFF87C0DA); // Lighter accent
  static const Color mintGreen = Color(0xFF3EB489); // Trending up / positive
  static const Color alertRed = Color(0xFFE11D48); // Expense
  static const Color surfaceDark = Color(0xFF121417); // Card background
  static const Color surfaceLight = Color(0xFF1C1F24); // Card elevated
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9CA3AF);
  static const Color borderSubtle = Color(0x33FFFFFF);

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0A0B0D), // dark top
      Color(0xFF0F171A), // deep blue-black middle
      Color(0xFF121417), // dark surface
      Color(0xFF0A0B0D), // pure dark
    ],
    stops: [0.0, 0.4, 0.7, 1.0],
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: const Color(0xFF0A0B0D),
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
          backgroundColor: AppColors.primaryBlue,
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
