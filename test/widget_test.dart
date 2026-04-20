import 'package:flutter_test/flutter_test.dart';
import 'package:eight_count/main.dart';

void main() {
  testWidgets('App launches and displays scaffold verification screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const EightCountApp());
    await tester.pumpAndSettle();

    expect(find.text('8 COUNT'), findsOneWidget);
    expect(find.text('Every Round Counts'), findsOneWidget);
    expect(find.text('V2 Scaffold OK'), findsOneWidget);
  });
}
