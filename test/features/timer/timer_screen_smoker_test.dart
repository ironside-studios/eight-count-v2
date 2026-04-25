import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/core/models/workout_block_type.dart';
import 'package:eight_count/features/timer/presentation/widgets/block_label.dart';
import 'package:eight_count/generated/l10n/app_localizations.dart';

/// Pump a BlockLabel inside a minimal MaterialApp so AppLocalizations is
/// resolvable. EN locale by default — BlockLabel reads l10n strings via
/// AppLocalizations.of(context).
Future<void> pumpBlockLabel(
  WidgetTester tester, {
  required int? currentBlockIndex,
  required WorkoutBlockType? blockType,
  int totalContentBlocks = 4,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
      home: Scaffold(
        body: BlockLabel(
          currentBlockIndex: currentBlockIndex,
          blockType: blockType,
          totalContentBlocks: totalContentBlocks,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Smoker B1 boxing: renders "BLOCK 1 OF 4" and "BOXING"',
      (tester) async {
    await pumpBlockLabel(
      tester,
      currentBlockIndex: 1,
      blockType: WorkoutBlockType.boxing,
    );
    expect(find.text('BLOCK 1 OF 4'), findsOneWidget);
    expect(find.text('BOXING'), findsOneWidget);
    expect(find.textContaining('TRANSITION'), findsNothing);
  });

  testWidgets('Smoker B2 tabata: renders "BLOCK 2 OF 4" and "TABATA"',
      (tester) async {
    await pumpBlockLabel(
      tester,
      currentBlockIndex: 2,
      blockType: WorkoutBlockType.tabata,
    );
    expect(find.text('BLOCK 2 OF 4'), findsOneWidget);
    expect(find.text('TABATA'), findsOneWidget);
  });

  testWidgets(
      'Transition between blocks: renders "TRANSITION → BLOCK 3" '
      '(next-index = currentIndex + 1)', (tester) async {
    await pumpBlockLabel(
      tester,
      currentBlockIndex: 2,
      blockType: WorkoutBlockType.transition,
    );
    expect(find.text('TRANSITION → BLOCK 3'), findsOneWidget);
    expect(find.text('BLOCK 2 OF 4'), findsNothing,
        reason: 'transition label replaces the content-block label');
  });

  testWidgets(
      'Non-Smoker (currentBlockIndex == null): renders nothing visible',
      (tester) async {
    await pumpBlockLabel(
      tester,
      currentBlockIndex: null,
      blockType: null,
    );
    expect(find.byType(Text), findsNothing,
        reason: 'BlockLabel collapses to SizedBox.shrink for non-Smoker');
    expect(find.textContaining('BLOCK'), findsNothing);
    expect(find.textContaining('TRANSITION'), findsNothing);
  });

  testWidgets('Spanish locale renders translated strings', (tester) async {
    await pumpBlockLabel(
      tester,
      currentBlockIndex: 1,
      blockType: WorkoutBlockType.boxing,
      locale: const Locale('es'),
    );
    expect(find.text('BLOQUE 1 DE 4'), findsOneWidget);
    expect(find.text('BOXEO'), findsOneWidget);
  });
}
