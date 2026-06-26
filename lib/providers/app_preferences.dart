import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference {
  system('system', 'System'),
  light('light', 'Light'),
  dark('dark', 'Dark');

  final String value;
  final String label;

  const AppThemePreference(this.value, this.label);

  ThemeMode get themeMode {
    return switch (this) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
  }

  static AppThemePreference fromValue(String? value) {
    return AppThemePreference.values.firstWhere(
      (preference) => preference.value == value,
      orElse: () => AppThemePreference.system,
    );
  }
}

class AppPreferences extends ChangeNotifier {
  static const _themePreferenceKey = 'theme_preference';

  final SharedPreferences _preferences;
  AppThemePreference _themePreference;

  AppPreferences._(this._preferences, this._themePreference);

  AppThemePreference get themePreference => _themePreference;
  ThemeMode get themeMode => _themePreference.themeMode;

  static Future<AppPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    return AppPreferences._(
      preferences,
      AppThemePreference.fromValue(preferences.getString(_themePreferenceKey)),
    );
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    if (_themePreference == preference) return;

    _themePreference = preference;
    notifyListeners();
    await _preferences.setString(_themePreferenceKey, preference.value);
  }
}
