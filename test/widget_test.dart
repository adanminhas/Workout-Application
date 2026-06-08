import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:setflow/main.dart';
import 'package:setflow/theme/theme_controller.dart';

void main() {
  testWidgets('App boots into the Today tab', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeController = await ThemeController.load();

    await tester.pumpWidget(SetFlowApp(themeController: themeController));
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
