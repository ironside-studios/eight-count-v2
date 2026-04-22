import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eight_count/main.dart';
import 'package:eight_count/core/services/locale_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Reset the singleton between tests so locale state doesn't leak.
    await localeService.setLocale(const Locale('en'));
  });

  Future<void> pumpAndNavigateToSettings(
    WidgetTester tester,
    Locale initialLocale,
  ) async {
    // Phone-portrait viewport — layout is designed for phones, not the 800x600 default.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await localeService.setLocale(initialLocale);

    await tester.pumpWidget(const EightCountApp());
    await tester.pumpAndSettle();

    expect(find.text('8 COUNT'), findsOneWidget);

    // Tap the Lucide gear icon — this is the path that previously crashed
    // with "No MaterialLocalizations found" before the delegates were wired.
    await tester.tap(find.byIcon(LucideIcons.settings));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('LANGUAGE'), findsOneWidget);
    expect(find.text('ENGLISH'), findsOneWidget);
    expect(find.text('ESPAÑOL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('Home screen renders 8 COUNT + 3 preset cards, no EN/ES toggle',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const EightCountApp());
    await tester.pumpAndSettle();

    expect(find.text('8 COUNT'), findsOneWidget);
    expect(find.text('EVERY ROUND COUNTS'), findsNothing);
    expect(find.text('EN'), findsNothing);
    expect(find.text('ES'), findsNothing);
    expect(find.text('BOXING'), findsOneWidget);
    expect(find.text('SMOKER'), findsOneWidget);
    expect(find.text('CUSTOM'), findsOneWidget);
    expect(find.text('PRO'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gear → SettingsScreen navigates without MaterialLocalizations crash (en)',
      (WidgetTester tester) async {
    await pumpAndNavigateToSettings(tester, const Locale('en'));
  });

  testWidgets('Gear → SettingsScreen navigates without MaterialLocalizations crash (es)',
      (WidgetTester tester) async {
    await pumpAndNavigateToSettings(tester, const Locale('es'));

    // And confirm the toggle still works end-to-end after navigating in es.
    await tester.tap(find.text('ENGLISH'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(localeService.current, const Locale('en'));
  });
}
