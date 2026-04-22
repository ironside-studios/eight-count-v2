import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eight_count/main.dart';
import 'package:eight_count/features/settings/presentation/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Home screen renders 8 COUNT + 3 preset cards, no EN/ES toggle',
      (WidgetTester tester) async {
    // Phone-portrait viewport — layout is designed for phones, not the 800x600 default.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const EightCountApp());
    await tester.pumpAndSettle();

    // Brand mark present; subtitle removed this step.
    expect(find.text('8 COUNT'), findsOneWidget);
    expect(find.text('EVERY ROUND COUNTS'), findsNothing);

    // EN/ES toggle removed from home (moved into SettingsScreen).
    expect(find.text('EN'), findsNothing);
    expect(find.text('ES'), findsNothing);

    // Preset cards still render.
    expect(find.text('BOXING'), findsOneWidget);
    expect(find.text('SMOKER'), findsOneWidget);
    expect(find.text('CUSTOM'), findsOneWidget);
    expect(find.text('PRO'), findsNWidgets(2));
  });

  testWidgets('Settings screen shows ENGLISH / ESPAÑOL and updates on tap',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('LANGUAGE'), findsOneWidget);
    expect(find.text('ENGLISH'), findsOneWidget);
    expect(find.text('ESPAÑOL'), findsOneWidget);

    // Tap ESPAÑOL; widget should rebuild without throwing.
    await tester.tap(find.text('ESPAÑOL'));
    await tester.pumpAndSettle();

    expect(find.text('ESPAÑOL'), findsOneWidget);
  });
}
