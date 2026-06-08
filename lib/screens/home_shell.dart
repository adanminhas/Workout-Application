import 'package:flutter/material.dart';

import '../data/workout_repository.dart';
import '../theme/theme_controller.dart';
import 'exercises_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';
import 'workouts_screen.dart';

/// Bottom-navigation shell hosting the Phase 1 tabs plus Settings.
/// A History tab arrives with Phase 6.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.themeController,
    required this.appData,
  });

  final ThemeController themeController;
  final AppData appData;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TodayScreen(appData: widget.appData),
      WorkoutsScreen(appData: widget.appData),
      ExercisesScreen(appData: widget.appData),
      SettingsScreen(themeController: widget.themeController),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Workouts',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Exercises',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
