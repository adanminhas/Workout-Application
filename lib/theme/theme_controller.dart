import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's theme preferences (light/dark/system + accent seed color)
/// and persists them locally with shared_preferences. Listen to this to rebuild
/// [MaterialApp] when the choice changes.
class ThemeController extends ChangeNotifier {
  ThemeController._(
    this._prefs,
    this._themeMode,
    this._seedColor,
    this._highContrast,
  );

  static const _kThemeMode = 'theme_mode';
  static const _kSeedColor = 'seed_color';
  static const _kHighContrast = 'high_contrast';

  /// Default accent — teal ("moving through sets").
  static const Color defaultSeed = Color(0xFF00897B);

  final SharedPreferences _prefs;
  ThemeMode _themeMode;
  Color _seedColor;
  bool _highContrast;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  /// When true the app uses a grayscale, maximum-contrast palette and ignores
  /// the accent color.
  bool get highContrast => _highContrast;

  /// Loads saved preferences (or sensible defaults) before the app builds.
  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = ThemeMode.values[
        (prefs.getInt(_kThemeMode) ?? ThemeMode.system.index)
            .clamp(0, ThemeMode.values.length - 1)];
    final seed = Color(prefs.getInt(_kSeedColor) ?? defaultSeed.toARGB32());
    final highContrast = prefs.getBool(_kHighContrast) ?? false;
    return ThemeController._(prefs, mode, seed, highContrast);
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

  void setHighContrast(bool value) {
    if (value == _highContrast) return;
    _highContrast = value;
    _prefs.setBool(_kHighContrast, value);
    notifyListeners();
  }

  ThemeData themeFor(Brightness brightness) {
    if (_highContrast) return _highContrastTheme(brightness);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
      ),
      useMaterial3: true,
    );
  }

  /// A true black-and-white, maximum-contrast theme. Surfaces are pure white
  /// (or pure black in dark mode) — the Material 3 elevation "surface tint"
  /// that normally greys white surfaces is removed, and cards get a hard
  /// border so they stay visible on a same-colour background.
  ThemeData _highContrastTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    final fg = isLight ? black : white; // text, lines, accents
    final bg = isLight ? white : black; // surfaces

    final scheme = ColorScheme(
      brightness: brightness,
      primary: fg,
      onPrimary: bg,
      primaryContainer: fg,
      onPrimaryContainer: bg,
      secondary: fg,
      onSecondary: bg,
      secondaryContainer: fg,
      onSecondaryContainer: bg,
      tertiary: fg,
      onTertiary: bg,
      tertiaryContainer: fg,
      onTertiaryContainer: bg,
      error: fg,
      onError: bg,
      errorContainer: fg,
      onErrorContainer: bg,
      surface: bg,
      onSurface: fg,
      surfaceDim: bg,
      surfaceBright: bg,
      surfaceContainerLowest: bg,
      surfaceContainerLow: bg,
      surfaceContainer: bg,
      surfaceContainerHigh: bg,
      surfaceContainerHighest: bg,
      onSurfaceVariant: fg,
      outline: fg,
      outlineVariant: fg,
      inverseSurface: fg,
      onInverseSurface: bg,
      inversePrimary: bg,
      surfaceTint: Colors.transparent,
      shadow: black,
      scrim: black,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      dividerColor: fg,
      cardTheme: CardThemeData(
        color: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: fg),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
