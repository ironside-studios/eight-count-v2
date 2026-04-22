import 'package:flutter_test/flutter_test.dart';
import 'package:eight_count/core/utils/time_format.dart';

void main() {
  group('formatMmSs', () {
    test('above 60s renders M:SS', () {
      expect(formatMmSs(180), '3:00');
      expect(formatMmSs(157), '2:37');
      expect(formatMmSs(60), '1:00');
      expect(formatMmSs(2820), '47:00');
    });

    test('below 60s renders :SS with leading colon', () {
      expect(formatMmSs(59), ':59');
      expect(formatMmSs(11), ':11');
      expect(formatMmSs(1), ':01');
      expect(formatMmSs(0), ':00');
    });

    test('clamps negative input to :00', () {
      expect(formatMmSs(-5), ':00');
    });
  });
}
