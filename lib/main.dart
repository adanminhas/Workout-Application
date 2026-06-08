import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = await ThemeController.load();
  runApp(SetFlowApp(themeController: themeController));
}

class SetFlowApp extends StatelessWidget {
  const SetFlowApp({super.key, required this.themeController});

  final ThemeController themeController;

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
          home: HomeShell(themeController: themeController),
        );
      },
    );
  }
}
