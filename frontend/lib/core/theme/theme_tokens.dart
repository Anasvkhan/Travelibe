import 'package:flutter/material.dart';

class ThemeTokens {
  // Brand Palette
  static const Color travelTeal = Color(0xFF004D40);  // Deep Travel Teal
  static const Color warmCoral = Color(0xFFFF6F61);  // Warm Coral
  static const Color sandCream = Color(0xFFF5F2EB);  // Sand/Cream
  
  // Neutral Colors
  static const Color charcoal = Color(0xFF2E2E2E);
  static const Color lightGray = Color(0xFFE0E0E0);
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // Typography
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: charcoal,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: charcoal,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: charcoal,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w300,
    color: Colors.grey,
  );

  // App Theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: travelTeal,
      scaffoldBackgroundColor: sandCream,
      colorScheme: ColorScheme.light(
        primary: travelTeal,
        secondary: warmCoral,
        surface: white,
        background: sandCream,
        onPrimary: white,
        onSecondary: white,
        onSurface: charcoal,
        onBackground: charcoal,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: travelTeal,
        foregroundColor: white,
        elevation: 0,
      ),
      buttonTheme: const ButtonThemeData(
        buttonColor: warmCoral,
        textTheme: ButtonTextTheme.primary,
      ),
    );
  }
}
