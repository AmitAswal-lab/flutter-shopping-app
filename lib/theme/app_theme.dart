import 'package:flutter/material.dart';

class AppTheme {
  static const _colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF9EEBCF),
    onPrimary: Color(0xFF062018),
    primaryContainer: Color(0xFF0C5C46),
    onPrimaryContainer: Color(0xFFC9FBE8),
    secondary: Color(0xFFF2C15B),
    onSecondary: Color(0xFF2A1B00),
    secondaryContainer: Color(0xFF5A3D08),
    onSecondaryContainer: Color(0xFFFFE4A6),
    tertiary: Color(0xFF7DD7E8),
    onTertiary: Color(0xFF002026),
    tertiaryContainer: Color(0xFF164D57),
    onTertiaryContainer: Color(0xFFB8F1FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    surface: Color(0xFF121116),
    onSurface: Color(0xFFE8E1EA),
    surfaceContainerLowest: Color(0xFF0D0C10),
    surfaceContainerLow: Color(0xFF19171D),
    surfaceContainer: Color(0xFF1F1D24),
    surfaceContainerHigh: Color(0xFF2A2730),
    surfaceContainerHighest: Color(0xFF35313B),
    outline: Color(0xFF928A9A),
    outlineVariant: Color(0xFF4B4554),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE8E1EA),
    onInverseSurface: Color(0xFF302D35),
    inversePrimary: Color(0xFF006C50),
  );

  static ThemeData get dark {
    final textTheme = ThemeData.dark(useMaterial3: true).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: _colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: _colorScheme.surface,
        foregroundColor: _colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: _colorScheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _colorScheme.primary,
          foregroundColor: _colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _colorScheme.primary,
          side: BorderSide(color: _colorScheme.outlineVariant),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _colorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: _colorScheme.outline),
        hintStyle: TextStyle(color: _colorScheme.outline),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: _colorScheme.secondaryContainer,
        disabledColor: _colorScheme.surfaceContainerLow,
        labelStyle: TextStyle(color: _colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(
          color: _colorScheme.onSecondaryContainer,
        ),
        side: BorderSide(color: _colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCheckmark: true,
        checkmarkColor: _colorScheme.onSecondaryContainer,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _colorScheme.surfaceContainer,
        indicatorColor: _colorScheme.secondaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: _colorScheme.onSecondaryContainer);
          }
          return IconThemeData(color: _colorScheme.onSurface);
        }),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(color: _colorScheme.onSurface, fontSize: 12),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(
        color: _colorScheme.outlineVariant,
        thickness: 1,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: _colorScheme.onSurface,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
