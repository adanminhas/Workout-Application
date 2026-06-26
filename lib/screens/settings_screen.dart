import 'package:flutter/material.dart';

import '../data/workout_prefs.dart';
import '../theme/theme_controller.dart';

/// Settings tab: Appearance (theme mode + accent color + high contrast) and
/// Workout (sound, haptics, keep screen awake).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.themeController});

  final ThemeController themeController;

  /// Curated seed colors. The first is the app default (teal).
  static const List<Color> _palette = [
    ThemeController.defaultSeed,
    Color(0xFF00ACC1), // cyan
    Color(0xFF1E88E5), // blue
    Color(0xFF3949AB), // indigo
    Color(0xFF8E24AA), // purple
    Color(0xFFD81B60), // pink
    Color(0xFFE53935), // red
    Color(0xFFF4511E), // deep orange
    Color(0xFFFFB300), // amber
    Color(0xFF43A047), // green
    Color(0xFF6D4C41), // brown
    Color(0xFF546E7A), // blue grey
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Appearance', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),

              Text('Theme', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Dark'),
                  ),
                ],
                selected: {themeController.themeMode},
                onSelectionChanged: (s) =>
                    themeController.setThemeMode(s.first),
              ),

              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('High contrast (black & white)'),
                subtitle:
                    const Text('Maximum legibility; ignores accent color'),
                value: themeController.highContrast,
                onChanged: themeController.setHighContrast,
              ),

              // Accent options are meaningless in grayscale, so hide them.
              if (!themeController.highContrast) ...[
                const SizedBox(height: 24),
                Text('Accent color', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final color in _palette)
                      _Swatch(
                        color: color,
                        selected: color.toARGB32() ==
                            themeController.seedColor.toARGB32(),
                        onTap: () => themeController.setSeedColor(color),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Custom color', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _HuePicker(
                  color: themeController.seedColor,
                  onChanged: themeController.setSeedColor,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => themeController
                      .setSeedColor(ThemeController.defaultSeed),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset accent to default'),
                ),
              ],

              const SizedBox(height: 32),
              Text('Workout', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const _WorkoutPrefsSection(),
            ],
          ),
        );
      },
    );
  }
}

/// Toggles for the in-workout experience, backed by [WorkoutPrefs].
class _WorkoutPrefsSection extends StatefulWidget {
  const _WorkoutPrefsSection();

  @override
  State<_WorkoutPrefsSection> createState() => _WorkoutPrefsSectionState();
}

class _WorkoutPrefsSectionState extends State<_WorkoutPrefsSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.volume_up_outlined),
          title: const Text('Sound'),
          subtitle: const Text('Countdown ticks and a finish chime'),
          value: WorkoutPrefs.sound,
          onChanged: (v) => setState(() => WorkoutPrefs.sound = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.vibration),
          title: const Text('Vibration'),
          subtitle: const Text('Haptic feedback on sets and timers'),
          value: WorkoutPrefs.haptics,
          onChanged: (v) => setState(() => WorkoutPrefs.haptics = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.screen_lock_portrait_outlined),
          title: const Text('Keep screen awake'),
          subtitle: const Text('Stay on while a workout is running'),
          value: WorkoutPrefs.keepAwake,
          onChanged: (v) => setState(() => WorkoutPrefs.keepAwake = v),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white)
            : null,
      ),
    );
  }
}

/// A hue slider for picking an arbitrary accent color. Saturation/value are
/// fixed to values that make a pleasant Material seed; ColorScheme.fromSeed
/// derives the full palette from it.
class _HuePicker extends StatelessWidget {
  const _HuePicker({required this.color, required this.onChanged});

  final Color color;
  final ValueChanged<Color> onChanged;

  static Color _fromHue(double hue) =>
      HSVColor.fromAHSV(1, hue, 0.72, 0.88).toColor();

  @override
  Widget build(BuildContext context) {
    final hue = HSVColor.fromColor(color).hue;
    return Row(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 0,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: hue,
                  min: 0,
                  max: 360,
                  onChanged: (h) => onChanged(_fromHue(h)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
        ),
      ],
    );
  }
}
