import 'package:flutter/material.dart';

import 'data/db/app_database.dart';
import 'data/workout_repository.dart';
import 'screens/home_shell.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = await ThemeController.load();

  // Open the on-device SQLite database, seed it from SampleData on first
  // launch, then load a snapshot the screens read from (Phase 2).
  final repository = WorkoutRepository(AppDatabase());
  await repository.seedIfEmpty();
  final appData = await repository.loadAll();

  runApp(SetFlowApp(themeController: themeController, appData: appData));
}

class SetFlowApp extends StatelessWidget {
  const SetFlowApp({
    super.key,
    required this.themeController,
    required this.appData,
  });

  final ThemeController themeController;
  final AppData appData;

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
          home: HomeShell(themeController: themeController, appData: appData),
        );
      },
    );
  }
}
