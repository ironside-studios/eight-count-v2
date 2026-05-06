import 'package:eight_count/features/notes/models/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JournalEntry.create', () {
    test('generates a UUID v4 id', () {
      final entry = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
      // UUID v4 canonical form: 8-4-4-4-12 hex with version nibble == 4
      // and variant nibble in {8,9,a,b}.
      final regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(regex.hasMatch(entry.id), isTrue, reason: 'id was ${entry.id}');
    });

    test('createdAt and updatedAt are UTC and equal at construction', () {
      final entry = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
      expect(entry.createdAt.isUtc, isTrue);
      expect(entry.updatedAt.isUtc, isTrue);
      expect(entry.updatedAt, entry.createdAt);
    });

    test('strips time from workoutDate to midnight', () {
      final entry = JournalEntry.create(
        workoutDate: DateTime(2026, 5, 6, 14, 32, 17),
      );
      expect(entry.workoutDate, DateTime(2026, 5, 6));
    });
  });

  group('copyWith', () {
    test('preserves id and createdAt, bumps updatedAt by default', () async {
      final original = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
      // Force a measurable gap so the updatedAt comparison is meaningful.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final copy = original.copyWith(preIntent: 'shadowboxing');
      expect(copy.id, original.id);
      expect(copy.createdAt, original.createdAt);
      expect(copy.updatedAt.isAfter(original.updatedAt), isTrue);
      expect(copy.preIntent, 'shadowboxing');
    });

    test('respects explicit updatedAt argument', () {
      final original = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
      final fixed = DateTime.utc(2026, 6, 1, 10, 0);
      final copy = original.copyWith(updatedAt: fixed, preIntent: 'x');
      expect(copy.updatedAt, fixed);
    });
  });

  group('JSON roundtrip', () {
    test('preserves all fields including non-null optionals', () {
      final entry = JournalEntry.create(
        workoutDate: DateTime(2026, 5, 6),
        preIntent: 'sharp jab tonight',
        postReflection: 'felt slow on the back foot',
        tags: <String>['boxing', 'jab'],
        moodRating: 4,
        photoPath: 'photos/abc.jpg',
        linkedWorkoutType: 'boxing',
      );
      final restored = JournalEntry.fromJson(entry.toJson());
      expect(restored, entry);
    });

    test('preserves null optional fields', () {
      final entry = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
      final restored = JournalEntry.fromJson(entry.toJson());
      expect(restored, entry);
      expect(restored.preIntent, isNull);
      expect(restored.postReflection, isNull);
      expect(restored.moodRating, isNull);
      expect(restored.photoPath, isNull);
      expect(restored.linkedWorkoutType, isNull);
      expect(restored.tags, isEmpty);
    });
  });

  group('validation', () {
    test('rejects oversized preIntent', () {
      expect(
        () => JournalEntry.create(
          workoutDate: DateTime(2026, 5, 6),
          preIntent: 'x' * (JournalEntry.maxPreIntentLength + 1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects oversized postReflection', () {
      expect(
        () => JournalEntry.create(
          workoutDate: DateTime(2026, 5, 6),
          postReflection: 'y' * (JournalEntry.maxPostReflectionLength + 1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects more than 10 tags', () {
      expect(
        () => JournalEntry.create(
          workoutDate: DateTime(2026, 5, 6),
          tags: List<String>.generate(11, (i) => 't$i'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a tag longer than 24 chars', () {
      expect(
        () => JournalEntry.create(
          workoutDate: DateTime(2026, 5, 6),
          tags: <String>['x' * 25],
        ),
        throwsArgumentError,
      );
    });

    test('rejects mood rating outside 1-5', () {
      expect(
        () => JournalEntry.create(
          workoutDate: DateTime(2026, 5, 6),
          moodRating: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => JournalEntry.create(
          workoutDate: DateTime(2026, 5, 6),
          moodRating: 6,
        ),
        throwsArgumentError,
      );
    });
  });

  group('equality', () {
    test('two entries with identical fields are equal', () {
      final base = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
      final clone = JournalEntry.fromJson(base.toJson());
      expect(clone, base);
      expect(clone.hashCode, base.hashCode);
    });

    test('full structural equality: same id but different fields are NOT equal',
        () {
      final base = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
      final mutated = base.copyWith(preIntent: 'changed');
      expect(mutated, isNot(equals(base)));
    });
  });
}
