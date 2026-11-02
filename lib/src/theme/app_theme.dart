import 'package:flutter/material.dart';

/// Paleta y tema de Flash Drop (estructura visual inspirada en apps de
/// delivery tipo marketplace: tarjetas grandes, pills y navegación inferior).
class AppColors {
  static const primary = Color(0xFFFFB300);
  static const primaryDark = Color(0xFF8A5700);
  static const primarySoft = Color(0xFFFFF3CD);
  static const ink = Color(0xFF1E2025);
  static const muted = Color(0xFF7B8189);
  static const line = Color(0xFFE8EAED);
  static const surface = Colors.white;
  static const background = Color(0xFFF7F7F7);
  static const success = Color(0xFF12643D);
  static const star = Color(0xFFF5A623);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      useMaterial3: true,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        elevation: 12,
      ),
    );
  }
}
