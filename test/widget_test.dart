import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:setflow/main.dart';

void main() {
  testWidgets('App boots into the Today tab', (WidgetTester tester) async {
    await tester.pumpWidget(const SetFlowApp());
    await tester.pumpAndSettle();

    // Today tab is the default landing screen.
    expect(find.text("Today's workout"), findsOneWidget);
    expect(find.text('Start Workout'), findsOneWidget);

    // Bottom navigation exposes all three Phase 1 tabs.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Workouts'), findsWidgets);
    expect(find.text('Exercises'), findsWidgets);
  });
}
