import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFF121212);
  static const Color card = Color(0xFF1E1E1E);
  static const Color cardHigh = Color(0xFF2A2A2A);
  static const Color accent = Color(0xFF1DB954);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3);
}

class AppTheme {
  AppTheme._();

  /// VibePlay is dark-only (Material Design 3).
  static ThemeData get dark {
    const ColorScheme scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.black,
      secondary: AppColors.accent,
      onSecondary: Colors.black,
      surface: AppColors.card,
      onSurface: Colors.white,
      error: Color(0xFFCF6679),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: Color(0xFF4D4D4D),
        thumbColor: Colors.white,
        overlayColor: Color(0x331DB954),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        modalBackgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(color: AppColors.cardHigh),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardHigh,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
    );
  }
}
