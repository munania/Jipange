import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:state_notifier/state_notifier.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  // Initialize with system default, will be updated in _loadTheme

  ThemeMode get themeMode => state;

  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  static const String _themeKey = 'theme_mode';

  // Load saved theme on initialization
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(_themeKey);

    if (themeModeString != null) {
      ThemeMode mode;
      switch (themeModeString) {
        case 'ThemeMode.light':
          mode = ThemeMode.light;
          break;
        case 'ThemeMode.dark':
          mode = ThemeMode.dark;
          break;
        default:
          mode = ThemeMode.system;
      }
      state = mode;
    }
  }

  // Set and save theme
  Future<void> setTheme(ThemeMode themeMode) async {
    state = themeMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeMode.toString());
  }
}
