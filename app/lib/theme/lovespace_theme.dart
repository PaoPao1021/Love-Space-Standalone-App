import 'package:flutter/material.dart';

abstract final class LoveSpaceColors {
  static const rose = Color(0xFFE85D75);
  static const pink = Color(0xFFF08A9B);
  static const blush = Color(0xFFF8F5F3);
  static const ink = Color(0xFF2D2729);
  static const mutedInk = Color(0xFF756A6D);
  static const border = Color(0xFFEDE7E8);
}

abstract final class LoveSpaceTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: LoveSpaceColors.rose,
          brightness: brightness,
          surface: dark ? const Color(0xFF2A1822) : Colors.white,
        ).copyWith(
          primary: dark ? const Color(0xFFF472B6) : LoveSpaceColors.rose,
          secondary: dark ? const Color(0xFFF9A8D4) : LoveSpaceColors.pink,
          surfaceContainerLowest: dark
              ? const Color(0xFF1E1118)
              : LoveSpaceColors.blush,
          outlineVariant: dark
              ? const Color(0xFF5B3B4B)
              : LoveSpaceColors.border,
          onSurface: dark ? const Color(0xFFFCE7F3) : LoveSpaceColors.ink,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      fontFamilyFallback: const [
        'PingFang SC',
        'Hiragino Sans GB',
        'Noto Sans SC',
        'Microsoft YaHei',
        'sans-serif',
      ],
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          height: 1.55,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: dark ? const Color(0xFFE5C7D5) : LoveSpaceColors.mutedInk,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? scheme.surface : const Color(0xFFF7F5F2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainerLowest,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: LoveSpaceColors.rose,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surface,
        indicatorColor: dark
            ? const Color(0xFF642747)
            : const Color(0xFFFFD7E7),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
