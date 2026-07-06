import 'package:flutter/material.dart';

import 'data/db/app_database.dart';
import 'data/exercisedb_api.dart';
import 'data/workout_prefs.dart';
import 'data/workout_repository.dart';
import 'screens/home_shell.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = await ThemeController.load();
  await WorkoutPrefs.init();
  await ExerciseDbApi.init();

  // Open the on-device SQLite database and seed it from SampleData on first
  // launch. Screens read reactively via the repository's watch* streams.
  final repository = WorkoutRepository(AppDatabase());
  await repository.seedIfEmpty();

  runApp(SetFlowApp(
    themeController: themeController,
    repository: repository,
  ));
}

class SetFlowApp extends StatelessWidget {
  const SetFlowApp({
    super.key,
    required this.themeController,
    required this.repository,
  });

  final ThemeController themeController;
  final WorkoutRepository repository;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'SetFlow',
          debugShowCheckedModeBanner: false,
          theme: themeController.themeFor(Brightness.light),
          darkTheme: themeController.themeFor(Brightness.dark),
          themeMode: themeController.themeMode,
          home: HomeShell(
            themeController: themeController,
            repository: repository,
          ),
        );
      },
    );
  }
}
