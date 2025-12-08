import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const _prefKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  double _textScaleFactor = 1.0;
  double get textScaleFactor => _textScaleFactor;

  ThemeService() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_prefKey) ?? 'system';
      if (s == 'light') {
        _themeMode = ThemeMode.light;
      } else if (s == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }

      final size = prefs.getString('text_size') ?? 'normal';
      if (size == 'small') {
        _textScaleFactor = 0.85;
      } else if (size == 'large') {
        _textScaleFactor = 1.15;
      } else {
        _textScaleFactor = 1.0;
      }

      notifyListeners();
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = mode == ThemeMode.light
          ? 'light'
          : (mode == ThemeMode.dark ? 'dark' : 'system');
      await prefs.setString(_prefKey, s);
    } catch (_) {}
  }

  Future<void> setTextScale(String size) async {
    if (size == 'small') {
      _textScaleFactor = 0.85;
    } else if (size == 'large') {
      _textScaleFactor = 1.15;
    } else {
      _textScaleFactor = 1.0;
    }

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('text_size', size);
    } catch (_) {}
  }
}
