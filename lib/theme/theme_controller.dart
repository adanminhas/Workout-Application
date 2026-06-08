import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's theme preferences (light/dark/system + accent seed color)
/// and persists them locally with shared_preferences. Listen to this to rebuild
/// [MaterialApp] when the choice changes.
class ThemeController extends ChangeNotifier {
  ThemeController._(this._prefs, this._themeMode, this._seedColor);

  static const _kThemeMode = 'theme_mode';
  static const _kSeedColor = 'seed_color';

  /// Default accent — teal ("moving through sets").
  static const Color defaultSeed = Color(0xFF00897B);

  final SharedPreferences _prefs;
  ThemeMode _themeMode;
  Color _seedColor;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  /// Loads saved preferences (or sensible defaults) before the app builds.
  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = ThemeMode.values[
        (prefs.getInt(_kThemeMode) ?? ThemeMode.system.index)
            .clamp(0, ThemeMode.values.length - 1)];
    final seed = Color(prefs.getInt(_kSeedColor) ?? defaultSeed.toARGB32());
    return ThemeController._(prefs, mode, seed);
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  void setSeedColor(Color color) {
    if (color.toARGB32() == _seedColor.toARGB32()) return;
    _seedColor = color;
    _prefs.setInt(_kSeedColor, color.toARGB32());
    notifyListeners();
  }

  ThemeData themeFor(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
      ),
      useMaterial3: true,
    );
  }
}
