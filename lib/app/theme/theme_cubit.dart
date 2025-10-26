// filepath: c:\FlutterDev\agapecares\lib\app\theme\theme_cubit.dart
// Simple ThemeCubit to toggle between light, dark, and system modes globally.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  // Start with system so the app follows the phone's theme by default.
  ThemeCubit() : super(ThemeMode.system) {
    // Load saved preference if present (async) and emit it.
    _loadSavedMode();
  }

  static const _prefsKey = 'theme_mode';

  Future<void> _loadSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_prefsKey) ?? 'system';
      if (value == 'light') emit(ThemeMode.light);
      else if (value == 'dark') emit(ThemeMode.dark);
      else emit(ThemeMode.system);
    } catch (_) {
      // ignore and leave system
    }
  }

  Future<void> _saveMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system';
      await prefs.setString(_prefsKey, s);
    } catch (_) {
      // ignore
    }
  }

  /// Set explicit light theme
  void setLight() {
    emit(ThemeMode.light);
    _saveMode(ThemeMode.light);
  }

  /// Set explicit dark theme
  void setDark() {
    emit(ThemeMode.dark);
    _saveMode(ThemeMode.dark);
  }

  /// Follow the device/system theme
  void setSystem() {
    emit(ThemeMode.system);
    _saveMode(ThemeMode.system);
  }

  /// Cycle between system -> light -> dark -> system
  void toggle() {
    if (state == ThemeMode.system) {
      setLight();
    } else if (state == ThemeMode.light) {
      setDark();
    } else {
      setSystem();
    }
  }
}
