import 'package:flutter/material.dart';

import 'screens/home_shell.dart';

void main() {
  runApp(const SetFlowApp());
}

class SetFlowApp extends StatelessWidget {
  const SetFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00897B), // teal — "moving through sets"
    );
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00897B),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'SetFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: colorScheme, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: darkColorScheme, useMaterial3: true),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
