import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/core/navigation/route_observer.dart';
import 'package:eight_count/features/home/widgets/matrix_rain_background.dart';

void main() {
  testWidgets('MatrixRainBackground mounts and disposes cleanly',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: MatrixRainBackground(),
          ),
        ),
      ),
    );

    expect(find.byType(MatrixRainBackground), findsOneWidget);

    // Pump a couple of frames to let the LayoutBuilder + Ticker drive
    // the first paint cycle.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    // Disposal: pump an empty widget to remove the rain widget.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(find.byType(MatrixRainBackground), findsNothing);
  });

  testWidgets(
      'MatrixRainBackground subscribes to routeObserver when mounted '
      'inside a navigator that uses it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routeObserver],
        home: const Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: MatrixRainBackground(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    // The widget should be in the tree and the routeObserver should
    // have it as a subscriber. We can't introspect the observer's
    // private _listeners map, so we just verify the widget mounted
    // without throwing — if subscription failed, didChangeDependencies
    // would have surfaced an error in the test harness.
    expect(find.byType(MatrixRainBackground), findsOneWidget);

    // Tear down — must not throw on unsubscribe.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });

  testWidgets('MatrixRainBackground tolerates a route push then pop',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [routeObserver],
        home: const Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: MatrixRainBackground(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(MatrixRainBackground), findsOneWidget);

    // Push a second route — RouteAware.didPushNext should fire on the
    // background widget, pausing its ticker. Cannot pumpAndSettle (the
    // rain widget's Ticker never idles); pump fixed durations to let
    // the route transition animation complete.
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('next'))),
      ),
    );
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('next'), findsOneWidget);

    // Pop back — didPopNext should fire and resume the ticker.
    navKey.currentState!.pop();
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byType(MatrixRainBackground), findsOneWidget);
  });
}
