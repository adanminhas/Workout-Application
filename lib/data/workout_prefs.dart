import 'package:shared_preferences/shared_preferences.dart';

/// Device-local toggles for the in-workout experience (Phase 7 polish). These
/// only need to be read when a workout runs and written from Settings, so a
/// lightweight static holder over [SharedPreferences] is enough — no reactive
/// propagation like [ThemeController] needs.
///
/// Getters tolerate being read before [init] (return defaults), so widgets
/// built in tests without `main()` don't crash.
class WorkoutPrefs {
  WorkoutPrefs._();

  static SharedPreferences? _prefs;

  static const _kSound = 'workout_sound';
  static const _kHaptics = 'workout_haptics';
  static const _kKeepAwake = 'workout_keep_awake';

  /// Caches the SharedPreferences instance. Call once during startup.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get sound => _prefs?.getBool(_kSound) ?? true;
  static set sound(bool v) => _prefs?.setBool(_kSound, v);

  static bool get haptics => _prefs?.getBool(_kHaptics) ?? true;
  static set haptics(bool v) => _prefs?.setBool(_kHaptics, v);

  static bool get keepAwake => _prefs?.getBool(_kKeepAwake) ?? true;
  static set keepAwake(bool v) => _prefs?.setBool(_kKeepAwake, v);
}
