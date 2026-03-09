import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary     = Color(0xFF1B4332);
  static const primaryMid  = Color(0xFF40916C);
  static const primaryLight= Color(0xFFD8F3DC);
  static const accent      = Color(0xFF52B788);
  static const background  = Color(0xFFF9FAFB);
  static const surface     = Colors.white;
  static const textDark    = Color(0xFF111827);
  static const textGray    = Color(0xFF6B7280);
  static const error       = Color(0xFFEF4444);
  static const warning     = Color(0xFFF59E0B);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary:   AppColors.primary,
      secondary: AppColors.accent,
      surface:   AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textDark,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textDark,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, color: AppColors.textDark,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, color: AppColors.textGray,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: GoogleFonts.inter(color: AppColors.textGray),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      color: Colors.white,
    ),
  );
}

class AppConstants {
  // Replace with your actual Render backend URL
  static const apiBaseUrl = 'https://landvault-api.onrender.com';
}
