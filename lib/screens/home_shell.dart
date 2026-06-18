import 'package:flutter/material.dart';

import '../data/workout_repository.dart';
import '../theme/theme_controller.dart';
import 'exercises_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';
import 'workouts_screen.dart';

/// Bottom-navigation shell hosting Today / Workouts / Exercises / History /
/// Settings.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.themeController,
    required this.repository,
  });

  final ThemeController themeController;
  final WorkoutRepository repository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TodayScreen(repository: widget.repository),
      WorkoutsScreen(repository: widget.repository),
      ExercisesScreen(repository: widget.repository),
      HistoryScreen(repository: widget.repository),
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
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'History',
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
