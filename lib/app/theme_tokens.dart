import 'package:flutter/material.dart';

class BackofficeTheme {
  static const colorPrimary = Color(0xFF2B6E6A);
  static const colorSurface = Color(0xFFFFFBF7);
  static const colorBackground = Color(0xFFF8F1E8);
  static const colorTextPrimary = Color(0xFF23313F);
  static const colorBorder = Color(0xFFD2E3E1);
  static const colorError = Color(0xFFC0392B);

  static const Map<String, _PaletteTone> _palette = {
    'blush': _PaletteTone(
      sixty: Color(0xFFFFF0F5),
      thirty: Color(0xFFF8C7D8),
      accent: Color(0xFFD94F82),
    ),
    'coastal': _PaletteTone(
      sixty: Color(0xFFEAF4F8),
      thirty: Color(0xFFBBD6E3),
      accent: Color(0xFF1E6F8C),
    ),
    'sunset': _PaletteTone(
      sixty: Color(0xFFF9EFE5),
      thirty: Color(0xFFD9BBA0),
      accent: Color(0xFFB4542D),
    ),
    'garden': _PaletteTone(
      sixty: Color(0xFFEEF5EC),
      thirty: Color(0xFFC4D9B8),
      accent: Color(0xFF3F7F4A),
    ),
    'lavender': _PaletteTone(
      sixty: Color(0xFFF3F0FF),
      thirty: Color(0xFFD7CCFF),
      accent: Color(0xFF6C4BC8),
    ),
    'sunflower': _PaletteTone(
      sixty: Color(0xFFFFF8E8),
      thirty: Color(0xFFFDE2A4),
      accent: Color(0xFFC27A00),
    ),
    'slate': _PaletteTone(
      sixty: Color(0xFFF1F5F9),
      thirty: Color(0xFFCBD5E1),
      accent: Color(0xFF334155),
    ),
    'american_flag': _PaletteTone(
      sixty: Color(0xFFF5F8FF),
      thirty: Color(0xFFE3EAFB),
      accent: Color(0xFFB22234),
    ),
    'christmas': _PaletteTone(
      sixty: Color(0xFFF4FBF5),
      thirty: Color(0xFFD4EED6),
      accent: Color(0xFFC62828),
    ),
    'saint_valentine': _PaletteTone(
      sixty: Color(0xFFFFF1F6),
      thirty: Color(0xFFFBCADD),
      accent: Color(0xFFE11D48),
    ),
    'saint_patrick': _PaletteTone(
      sixty: Color(0xFFF2FAF3),
      thirty: Color(0xFFCBECCF),
      accent: Color(0xFF0F8A3B),
    ),
  };

  static ThemeData forPalette(String paletteKey) {
    final tone =
        _palette[paletteKey] ??
        const _PaletteTone(
          sixty: colorBackground,
          thirty: colorSurface,
          accent: colorPrimary,
        );
    final primary = tone.accent;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      surface: colorSurface,
      error: colorError,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colorBackground,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: colorTextPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: colorTextPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: colorTextPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF54606F)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF637285)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorSurface,
        foregroundColor: colorTextPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colorSurface,
        elevation: 0,
        shadowColor: primary.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: const Color(0xFFE7DDD2)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorTextPrimary,
          side: const BorderSide(color: Color(0xFFE2D8CD)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tone.thirty,
        selectedColor: primary.withValues(alpha: 0.18),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          color: colorTextPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorSurface,
        indicatorColor: primary.withValues(alpha: 0.22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFEFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE6DDD2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE6DDD2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
      dividerColor: const Color(0xFFEBE3D9),
    );
  }

  static ThemeData get light => forPalette('blush');
}

class _PaletteTone {
  const _PaletteTone({
    required this.sixty,
    required this.thirty,
    required this.accent,
  });

  final Color sixty;
  final Color thirty;
  final Color accent;
}
