import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- PREMIUM DESIGN SYSTEM ---

  // Light Mode Palette
  static const Color lightPrimary = Color(0xFF2563EB); // Vibrant Royal Blue
  static const Color lightElectricPurple = Color(0xFF8B5CF6);
  static const Color lightSecondary = Color(0xFFF59E0B);
  static const Color lightBackground = Color(0xFFF8FAFC); // Very Soft Gray
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightAccent = Color(0xFF10B981);
  static const Color lightText = Color(0xFF0F172A); // Slate 900

  // Dark Mode Palette
  static const Color darkPrimary = Color(0xFF3B82F6); // Bright Blue
  static const Color darkElectricPurple = Color(0xFFA78BFA);
  static const Color darkSecondary = Color(0xFFFBBF24);
  static const Color darkBackground = Color(0xFF020617); // Rich Darker Slate
  static const Color darkSurface = Color(0xFF0F172A); // Slate 900
  static const Color darkAccent = Color(0xFF34D399);
  static const Color darkText = Color(0xFFF1F5F9);

  // Spacing & Radius
  static const double gridUnit = 8.0;
  static const double cardRadius = 20.0; // Rounder cards
  static const double smallRadius = 10.0;
  static const double buttonRadius = 12.0; // Rounder buttons
  static const double modalRadius = 32.0;

  // Shadow System
  static List<BoxShadow> get premiumShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  // Light Theme
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBackground,
        colorScheme: const ColorScheme.light(
          primary: lightPrimary,
          secondary: lightSecondary,
          surface: lightSurface,
          onSurface: lightText,
          error: Color(0xFFEF4444),
          onPrimary: Colors.white,
          outline: Color(0xFFE2E8F0), // Subtle borders
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFF1F5F9), // Very subtle divider
          thickness: 1,
          space: 1,
        ),
        textTheme: _buildTextTheme(lightText, Colors.black54),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: lightText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
            side: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius),
            ),
            textStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      );

  // Dark Theme
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: darkPrimary,
          secondary: darkSecondary,
          surface: darkSurface,
          onSurface: darkText,
          error: Color(0xFFF87171),
          onPrimary: Colors.white,
          outline: Color(0xFF1E293B), // Subtle borders
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF1E293B), // Very subtle divider
          thickness: 1,
          space: 1,
        ),
        textTheme: _buildTextTheme(darkText, Colors.white70),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: darkText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius),
            ),
            textStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      );

  // Typography Builder
  static TextTheme _buildTextTheme(Color mainColor, Color secondaryColor) {
    const fallbackFonts = [
      'Inter',
      'Roboto',
      'Segoe UI',
      'Arial',
      'Noto Sans Devanagari',
    ];

    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: mainColor,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: mainColor,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: mainColor,
      ),
      bodyLarge: GoogleFonts.roboto(fontSize: 16, color: mainColor),
      bodyMedium: GoogleFonts.roboto(fontSize: 14, color: mainColor),
      labelSmall: GoogleFonts.spaceGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        letterSpacing: 0.5,
      ),
    ).apply(
      // Use fallback fonts for better international and system compatibility
      fontFamilyFallback: fallbackFonts,
    );
  }
}
