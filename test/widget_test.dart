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

  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpAndNavigateToSettings(
    WidgetTester tester, {
    required Locale initialLocale,
    required String expectedHomeBoxing,
    required String expectedSettingsTitle,
    required String expectedLanguageLabel,
  }) async {
    setPhoneViewport(tester);

    await localeService.setLocale(initialLocale);

    await tester.pumpWidget(const EightCountApp());
    await tester.pumpAndSettle();

    expect(find.text('8 COUNT'), findsOneWidget);
    expect(find.text(expectedHomeBoxing), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.settings));
    await tester.pumpAndSettle();

    expect(find.text(expectedSettingsTitle), findsOneWidget);
    expect(find.text(expectedLanguageLabel), findsOneWidget);
    expect(find.text('ENGLISH'), findsOneWidget);
    expect(find.text('ESPAÑOL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('Home screen — EN strings render, no EN/ES toggle, no subtitle',
      (WidgetTester tester) async {
    setPhoneViewport(tester);

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

  testWidgets('Gear → SettingsScreen navigates without crash (en)',
      (WidgetTester tester) async {
    await pumpAndNavigateToSettings(
      tester,
      initialLocale: const Locale('en'),
      expectedHomeBoxing: 'BOXING',
      expectedSettingsTitle: 'SETTINGS',
      expectedLanguageLabel: 'LANGUAGE',
    );
  });

  testWidgets('Gear → SettingsScreen navigates without crash (es)',
      (WidgetTester tester) async {
    await pumpAndNavigateToSettings(
      tester,
      initialLocale: const Locale('es'),
      expectedHomeBoxing: 'BOXEO',
      expectedSettingsTitle: 'AJUSTES',
      expectedLanguageLabel: 'IDIOMA',
    );

    // Tapping ENGLISH inside the Spanish-mode settings screen
    // flips the whole app back to English.
    await tester.tap(find.text('ENGLISH'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(localeService.current, const Locale('en'));
    expect(find.text('SETTINGS'), findsOneWidget);
  });

  testWidgets('Switching locale at runtime updates rendered text',
      (WidgetTester tester) async {
    setPhoneViewport(tester);

    await tester.pumpWidget(const EightCountApp());
    await tester.pumpAndSettle();

    expect(find.text('BOXING'), findsOneWidget);
    expect(find.text('BOXEO'), findsNothing);

    await localeService.setLocale(const Locale('es'));
    await tester.pumpAndSettle();

    expect(find.text('BOXING'), findsNothing);
    expect(find.text('BOXEO'), findsOneWidget);
    expect(find.text('QUEMADOR'), findsOneWidget);
    expect(find.text('PERSONALIZADO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
