import 'package:flutter/material.dart';

class AppTheme {
  static const _darkColorScheme = ColorScheme(
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

  static const _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF006C50),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFBFF4DF),
    onPrimaryContainer: Color(0xFF002116),
    secondary: Color(0xFF7A5600),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFDEA0),
    onSecondaryContainer: Color(0xFF271900),
    tertiary: Color(0xFF006879),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFA8EDFF),
    onTertiaryContainer: Color(0xFF001F26),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFFCF8FF),
    onSurface: Color(0xFF1D1B20),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF6F0F7),
    surfaceContainer: Color(0xFFF0EAF1),
    surfaceContainerHigh: Color(0xFFEAE4EB),
    surfaceContainerHighest: Color(0xFFE4DFE5),
    outline: Color(0xFF79747E),
    outlineVariant: Color(0xFFCAC4D0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF322F35),
    onInverseSurface: Color(0xFFF5EFF7),
    inversePrimary: Color(0xFF9EEBCF),
  );

  static ThemeData get light {
    return _themeFor(_lightColorScheme);
  }

  static ThemeData get dark {
    return _themeFor(_darkColorScheme);
  }

  static ThemeData _themeFor(ColorScheme colorScheme) {
    final textTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
    ).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outlineVariant),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
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
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: colorScheme.outline),
        hintStyle: TextStyle(color: colorScheme.outline),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: colorScheme.secondaryContainer,
        disabledColor: colorScheme.surfaceContainerLow,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.onSecondaryContainer),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCheckmark: true,
        checkmarkColor: colorScheme.onSecondaryContainer,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.secondaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onSecondaryContainer);
          }
          return IconThemeData(color: colorScheme.onSurface);
        }),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(color: colorScheme.onSurface, fontSize: 12),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
