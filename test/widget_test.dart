import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:setflow/data/db/app_database.dart';
import 'package:setflow/data/workout_repository.dart';
import 'package:setflow/main.dart';
import 'package:setflow/theme/theme_controller.dart';

void main() {
  testWidgets('App boots into the Today tab', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeController = await ThemeController.load();

    // Back the app with a throwaway in-memory database seeded from SampleData.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = WorkoutRepository(db);
    await repository.seedIfEmpty();
    final appData = await repository.loadAll();

    await tester.pumpWidget(
      SetFlowApp(themeController: themeController, appData: appData),
    );
    await tester.pumpAndSettle();

    // Today tab is the default landing screen.
    expect(find.text("Today's workout"), findsOneWidget);
    expect(find.text('Start Workout'), findsOneWidget);

    // Bottom navigation exposes the main tabs.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Workouts'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
