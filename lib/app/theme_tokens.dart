import 'package:flutter/material.dart';

class BackofficeTheme {
  static const colorPrimary = Color(0xFF0D6E6E);
  static const colorSurface = Color(0xFFF6FBFA);
  static const colorBackground = Color(0xFFEEF5F4);
  static const colorTextPrimary = Color(0xFF123030);
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
      surface: tone.sixty,
      error: colorError,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: tone.sixty,
      appBarTheme: AppBarTheme(
        backgroundColor: tone.thirty,
        foregroundColor: colorTextPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: primary.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: primary.withValues(alpha: 0.22)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 3,
          shadowColor: primary.withValues(alpha: 0.30),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tone.thirty,
        indicatorColor: primary.withValues(alpha: 0.22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.22)),
        ),
      ),
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
