import 'package:flutter/material.dart';

/// Randevu / iş uygulaması görünümü — nötr yüzeyler, düşük doygunluklu vurgu.
/// `light()` ve `dark()` aynı bileşen şablonunu paylaşır; renkler `ColorScheme`'den
/// çekildiğinden ekran kodu (Card, FilledButton, vb.) iki modda da otomatik adapte olur.
abstract final class AppTheme {
  // Light tonlari
  static const Color _ink = Color(0xFF1C2434);
  static const Color _muted = Color(0xFF5C6578);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _surfaceLight = Color(0xFFF2F4F7);

  // Dark tonlari (Material 3 onerilen kontrast araliklari)
  static const Color _accentDark = Color(0xFF60A5FA);
  static const Color _inkDark = Color(0xFFE6EAF2);
  static const Color _mutedDark = Color(0xFF9AA3B2);
  static const Color _surfaceDark = Color(0xFF14181F);
  static const Color _surfaceContainerDark = Color(0xFF1E232C);

  static ThemeData light() => _build(_lightScheme());
  static ThemeData dark() => _build(_darkScheme());

  static ColorScheme _lightScheme() => const ColorScheme.light(
        primary: _accent,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE8EEF9),
        onPrimaryContainer: _ink,
        secondary: _muted,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: _ink,
        onSurfaceVariant: _muted,
        outline: Color(0xFFD6DCE6),
        outlineVariant: Color(0xFFE6EAEF),
        surfaceContainerHighest: _surfaceLight,
        error: Color(0xFFB3261E),
        onError: Colors.white,
      );

  static ColorScheme _darkScheme() => const ColorScheme.dark(
        primary: _accentDark,
        onPrimary: Color(0xFF0B2545),
        primaryContainer: Color(0xFF1E3A5F),
        onPrimaryContainer: Color(0xFFD8E4F5),
        secondary: _mutedDark,
        onSecondary: Color(0xFF14181F),
        surface: _surfaceDark,
        onSurface: _inkDark,
        onSurfaceVariant: _mutedDark,
        outline: Color(0xFF3A424F),
        outlineVariant: Color(0xFF2A2F38),
        surfaceContainerHighest: _surfaceContainerDark,
        error: Color(0xFFF2B8B5),
        onError: Color(0xFF601410),
      );

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surfaceContainerHighest,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        height: 56,
        elevation: 2,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: -0.1,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        dividerColor: scheme.outlineVariant,
      ),
    );
  }
}
