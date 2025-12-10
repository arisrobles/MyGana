import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  system,
  light,
  dark,
  sakura,
  matcha,
  sunset,
  ocean,
  lavender,
  autumn,
  fuji,
  blueLight,
}

class ThemeProvider extends ChangeNotifier {
  static const String _themePreferenceKey = 'theme_mode';

  AppThemeMode _appThemeMode = AppThemeMode.system;

  ThemeProvider() {
    _loadThemePreference();
  }

  AppThemeMode get appThemeMode => _appThemeMode;

  ThemeMode get themeMode {
    switch (_appThemeMode) {
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
      case AppThemeMode.sakura:
      case AppThemeMode.matcha:
      case AppThemeMode.sunset:
      case AppThemeMode.ocean:
      case AppThemeMode.lavender:
      case AppThemeMode.autumn:
      case AppThemeMode.fuji:
      case AppThemeMode.blueLight:
        return ThemeMode.light; // All custom themes are treated as light mode
      case AppThemeMode.system:
      return ThemeMode.system;
    }
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_themePreferenceKey) ?? 0;
    if (index < AppThemeMode.values.length) {
      _appThemeMode = AppThemeMode.values[index];
    } else {
      _appThemeMode = AppThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePreferenceKey, _appThemeMode.index);
  }

  void setAppTheme(AppThemeMode mode) {
    _appThemeMode = mode;
    _saveThemePreference();
    notifyListeners();
  }

  void toggleDarkLightTheme() {
    if (_appThemeMode == AppThemeMode.dark) {
      _appThemeMode = AppThemeMode.light;
    } else {
      _appThemeMode = AppThemeMode.dark;
    }
    _saveThemePreference();
    notifyListeners();
  }

  // Get theme name for display
  String getThemeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'Default';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.sakura:
        return 'Sakura';
      case AppThemeMode.matcha:
        return 'Matcha';
      case AppThemeMode.sunset:
        return 'Sunset';
      case AppThemeMode.ocean:
        return 'Ocean';
      case AppThemeMode.lavender:
        return 'Lavender';
      case AppThemeMode.autumn:
        return 'Autumn';
      case AppThemeMode.fuji:
        return 'Fuji';
      case AppThemeMode.blueLight:
        return 'Blue Light';
      }
  }

  // Get theme description for display
  String getThemeDescription(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'Follow device theme settings';
      case AppThemeMode.light:
        return 'Clean and bright interface';
      case AppThemeMode.dark:
        return 'Easy on the eyes in low light';
      case AppThemeMode.sakura:
        return 'Inspired by cherry blossoms';
      case AppThemeMode.matcha:
        return 'Calming green tea colors';
      case AppThemeMode.sunset:
        return 'Warm orange and red tones';
      case AppThemeMode.ocean:
        return 'Deep blue and teal colors';
      case AppThemeMode.lavender:
        return 'Soft purple and lavender hues';
      case AppThemeMode.autumn:
        return 'Warm fall colors';
      case AppThemeMode.fuji:
        return 'Japanese mountain inspired';
      case AppThemeMode.blueLight:
        return 'Fresh blue tones';
      }
  }

  // Get theme icon for display
  IconData getThemeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.phone_android;
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.sakura:
        return Icons.spa;
      case AppThemeMode.matcha:
        return Icons.eco;
      case AppThemeMode.sunset:
        return Icons.wb_sunny;
      case AppThemeMode.ocean:
        return Icons.water;
      case AppThemeMode.lavender:
        return Icons.color_lens;
      case AppThemeMode.autumn:
        return Icons.forest;
      case AppThemeMode.fuji:
        return Icons.landscape;
      case AppThemeMode.blueLight:
        return Icons.palette;
      }
  }

  void setTheme(String themeId) {}
}