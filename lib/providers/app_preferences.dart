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
  static const _recentSearchesKey = 'recent_searches';
  static const _maxRecentSearches = 5;

  final SharedPreferences _preferences;
  AppThemePreference _themePreference;
  List<String> _recentSearches;

  AppPreferences._(
    this._preferences,
    this._themePreference,
    this._recentSearches,
  );

  AppThemePreference get themePreference => _themePreference;
  ThemeMode get themeMode => _themePreference.themeMode;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  static Future<AppPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    return AppPreferences._(
      preferences,
      AppThemePreference.fromValue(preferences.getString(_themePreferenceKey)),
      preferences.getStringList(_recentSearchesKey) ?? const <String>[],
    );
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    if (_themePreference == preference) return;

    _themePreference = preference;
    notifyListeners();
    await _preferences.setString(_themePreferenceKey, preference.value);
  }

  Future<void> addRecentSearch(String query) async {
    final nextSearch = query.trim();
    if (nextSearch.isEmpty) return;

    final updatedSearches = [
      nextSearch,
      ..._recentSearches.where(
        (search) => search.toLowerCase() != nextSearch.toLowerCase(),
      ),
    ].take(_maxRecentSearches).toList(growable: false);

    _recentSearches = updatedSearches;
    notifyListeners();
    await _preferences.setStringList(_recentSearchesKey, updatedSearches);
  }

  Future<void> clearRecentSearches() async {
    if (_recentSearches.isEmpty) return;

    _recentSearches = const <String>[];
    notifyListeners();
    await _preferences.remove(_recentSearchesKey);
  }

  Future<void> removeRecentSearch(String query) async {
    final nextSearches = _recentSearches
        .where((search) => search.toLowerCase() != query.trim().toLowerCase())
        .toList(growable: false);
    if (nextSearches.length == _recentSearches.length) return;

    _recentSearches = nextSearches;
    notifyListeners();
    await _preferences.setStringList(_recentSearchesKey, nextSearches);
  }
}
