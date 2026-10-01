import 'package:flutter/material.dart';

enum HomeHubTheme { dark, flower }

abstract final class AppTheme {
  static ThemeData forMode(HomeHubTheme mode) {
    final isDark = mode == HomeHubTheme.dark;
    final scheme = isDark
        ? ColorScheme.fromSeed(
            seedColor: const Color(0xFF9ABF91),
            brightness: Brightness.dark,
            surface: const Color(0xFF171A18),
          )
        : ColorScheme.fromSeed(
            seedColor: const Color(0xFF68794D),
            brightness: Brightness.light,
            surface: const Color(0xFFF7F4E9),
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF101210)
          : const Color(0xFFF7F4E9),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1B201C) : const Color(0xFFFFFEF9),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
