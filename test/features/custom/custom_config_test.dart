import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/features/custom/models/custom_config.dart';

void main() {
  group('CustomConfig.totalWorkoutSeconds', () {
    test('5 rounds × 90s work + 4 rounds × 30s rest = 570s', () {
      final c = CustomConfig.empty(0).copyWith(
        rounds: 5,
        workSeconds: 90,
        restSeconds: 30,
      );
      expect(c.totalWorkoutSeconds, 570);
    });

    test('1 round × 60s work, no rest factor = 60s', () {
      final c = CustomConfig.empty(0).copyWith(
        rounds: 1,
        workSeconds: 60,
        restSeconds: 30,
      );
      expect(c.totalWorkoutSeconds, 60,
          reason: 'rounds=1 → no rest periods are subtracted');
    });

    test('30 rounds × 600s work + 29 × 300s rest = 26700s (max bound)', () {
      final c = CustomConfig.empty(0).copyWith(
        rounds: 30,
        workSeconds: 600,
        restSeconds: 300,
      );
      expect(c.totalWorkoutSeconds, 30 * 600 + 29 * 300);
    });

    test('1 round × 10s work + 5s rest = 10s (min bounds, rest unused)', () {
      final c = CustomConfig.empty(0).copyWith(
        rounds: 1,
        workSeconds: 10,
        restSeconds: 5,
      );
      expect(c.totalWorkoutSeconds, 10);
    });

    test('12 rounds × 180s work + 11 × 60s rest = 2820s (Boxing parity)', () {
      final c = CustomConfig.empty(0).copyWith(
        rounds: 12,
        workSeconds: 180,
        restSeconds: 60,
      );
      expect(c.totalWorkoutSeconds, 2820);
    });
  });

  group('CustomConfig.validateName', () {
    test('empty string is rejected', () {
      expect(CustomConfig.validateName(''), isNotNull);
      expect(CustomConfig.validateName('   '), isNotNull);
    });
    test('30-char name is accepted', () {
      expect(CustomConfig.validateName('a' * 30), isNull);
    });
    test('31-char name is rejected', () {
      expect(CustomConfig.validateName('a' * 31), isNotNull);
    });
    test('alphanumeric + spaces + accented letters accepted', () {
      expect(CustomConfig.validateName('Heavy Bag 12'), isNull);
      expect(CustomConfig.validateName('Día de Boxeo'), isNull);
    });
    test('special characters rejected', () {
      expect(CustomConfig.validateName('Heavy@Bag'), isNotNull);
      expect(CustomConfig.validateName('Bag!'), isNotNull);
    });
  });

  group('CustomConfig.validateRounds / validateWorkSeconds / '
      'validateRestSeconds', () {
    test('rounds bounds (1..30)', () {
      expect(CustomConfig.validateRounds(0), isNotNull);
      expect(CustomConfig.validateRounds(1), isNull);
      expect(CustomConfig.validateRounds(30), isNull);
      expect(CustomConfig.validateRounds(31), isNotNull);
    });
    test('workSeconds bounds (10..600)', () {
      expect(CustomConfig.validateWorkSeconds(9), isNotNull);
      expect(CustomConfig.validateWorkSeconds(10), isNull);
      expect(CustomConfig.validateWorkSeconds(600), isNull);
      expect(CustomConfig.validateWorkSeconds(601), isNotNull);
    });
    test('restSeconds bounds (5..300)', () {
      expect(CustomConfig.validateRestSeconds(4), isNotNull);
      expect(CustomConfig.validateRestSeconds(5), isNull);
      expect(CustomConfig.validateRestSeconds(300), isNull);
      expect(CustomConfig.validateRestSeconds(301), isNotNull);
    });
  });

  group('CustomConfig.toJson / fromJson round-trip', () {
    test('saved config survives a round trip', () {
      // Use a local DateTime — `fromMillisecondsSinceEpoch` defaults to
      // local, so a DateTime.utc(...) original would compare unequal
      // even with identical epoch ms. The CustomConfig contract is
      // "JSON preserves the instant in time"; tests pin that with
      // matching timezones rather than introducing isUtc plumbing.
      final original = CustomConfig(
        name: 'Heavy Bag',
        rounds: 8,
        workSeconds: 120,
        restSeconds: 45,
        slotIndex: 2,
        lastModified: DateTime(2026, 4, 30, 12, 30),
      );
      final json = original.toJson();
      final restored = CustomConfig.fromJson(json);
      expect(restored, equals(original));
      // Sanity: instant in time matches regardless of timezone label.
      expect(
        restored.lastModified.millisecondsSinceEpoch,
        original.lastModified.millisecondsSinceEpoch,
      );
    });
  });

  group('CustomConfig.copyWith immutability', () {
    test('copyWith produces a new instance and does not mutate the original',
        () {
      final original = CustomConfig.empty(0);
      final copy = original.copyWith(name: 'Test');
      expect(copy.name, 'Test');
      expect(original.name, '');
      expect(identical(original, copy), isFalse);
    });
    test('copyWith with no args returns equal-but-not-identical config', () {
      final original = CustomConfig.empty(1);
      final copy = original.copyWith();
      expect(copy, equals(original));
      expect(identical(original, copy), isFalse);
    });
  });

  group('CustomConfig.isSaved', () {
    test('empty name returns false', () {
      expect(CustomConfig.empty(0).isSaved, isFalse);
      expect(CustomConfig.empty(0).copyWith(name: '   ').isSaved, isFalse);
    });
    test('non-empty trimmed name returns true', () {
      expect(CustomConfig.empty(0).copyWith(name: 'Bag').isSaved, isTrue);
      expect(
          CustomConfig.empty(0).copyWith(name: '  Bag  ').isSaved, isTrue);
    });
  });
}
