import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eight_count/main.dart';

void main() {
  testWidgets('Main screen renders brand mark and all 3 preset cards',
      (WidgetTester tester) async {
    // Phone-portrait viewport — layout is designed for phones, not the 800x600 default.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const EightCountApp());
    await tester.pumpAndSettle();

    // Brand mark
    expect(find.text('8 COUNT'), findsOneWidget);
    expect(find.text('EVERY ROUND COUNTS'), findsOneWidget);

    // Preset cards
    expect(find.text('BOXING'), findsOneWidget);
    expect(find.text('SMOKER'), findsOneWidget);
    expect(find.text('CUSTOM'), findsOneWidget);

    // Locked cards show PRO pill (2 locked cards = 2 pills)
    expect(find.text('PRO'), findsNWidgets(2));

    // Language toggle present
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('ES'), findsOneWidget);
  });
}
