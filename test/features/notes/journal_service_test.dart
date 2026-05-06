import 'package:eight_count/features/notes/models/journal_entry.dart';
import 'package:eight_count/features/notes/services/journal_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<JournalService> newService() async {
    final prefs = await SharedPreferences.getInstance();
    final service = JournalService(prefs);
    await service.init();
    return service;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('create persists and getAll returns it', () async {
    final service = await newService();
    final entry = JournalEntry.create(
      workoutDate: DateTime(2026, 5, 6),
      preIntent: 'jab work',
    );
    await service.add(entry);
    final all = await service.getAll();
    expect(all, hasLength(1));
    expect(all.first.id, entry.id);
    await service.dispose();
  });

  test('persists across service instances', () async {
    final s1 = await newService();
    final entry = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
    await s1.add(entry);
    await s1.dispose();

    final s2 = await newService();
    final all = await s2.getAll();
    expect(all, hasLength(1));
    expect(all.first.id, entry.id);
    await s2.dispose();
  });

  test('update bumps updatedAt and persists', () async {
    final service = await newService();
    final entry = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
    await service.add(entry);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final updated =
        await service.update(entry.copyWith(preIntent: 'new note'));
    expect(updated.updatedAt.isAfter(entry.updatedAt), isTrue);
    final fetched = await service.getById(entry.id);
    expect(fetched, isNotNull);
    expect(fetched!.preIntent, 'new note');
    await service.dispose();
  });

  test('update throws when id is unknown', () async {
    final service = await newService();
    final phantom = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
    expect(() => service.update(phantom), throwsStateError);
    await service.dispose();
  });

  test('delete removes from getAll and getById', () async {
    final service = await newService();
    final entry = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
    await service.add(entry);
    await service.delete(entry.id);
    expect(await service.getById(entry.id), isNull);
    expect(await service.getAll(), isEmpty);
    await service.dispose();
  });

  test('getAll sorts descending by workoutDate', () async {
    final service = await newService();
    final older = JournalEntry.create(workoutDate: DateTime(2026, 1, 1));
    final newer = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
    await service.add(older);
    await service.add(newer);
    final all = await service.getAll();
    expect(all.map((e) => e.id).toList(), <String>[newer.id, older.id]);
    await service.dispose();
  });

  test('getByDateRange is inclusive on both bounds', () async {
    final service = await newService();
    final inside = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
    final lowerEdge = JournalEntry.create(workoutDate: DateTime(2026, 5, 1));
    final upperEdge = JournalEntry.create(workoutDate: DateTime(2026, 5, 10));
    final outside = JournalEntry.create(workoutDate: DateTime(2026, 4, 30));
    await service.add(inside);
    await service.add(lowerEdge);
    await service.add(upperEdge);
    await service.add(outside);

    final inRange = await service.getByDateRange(
      DateTime(2026, 5, 1),
      DateTime(2026, 5, 10),
    );
    final ids = inRange.map((e) => e.id).toSet();
    expect(ids, containsAll(<String>[inside.id, lowerEdge.id, upperEdge.id]));
    expect(ids, isNot(contains(outside.id)));
    await service.dispose();
  });

  test('getByTag is case-sensitive', () async {
    final service = await newService();
    final tagged = JournalEntry.create(
      workoutDate: DateTime(2026, 5, 6),
      tags: <String>['Boxing'],
    );
    final other = JournalEntry.create(
      workoutDate: DateTime(2026, 5, 6),
      tags: <String>['running'],
    );
    await service.add(tagged);
    await service.add(other);

    expect(
      (await service.getByTag('Boxing')).map((e) => e.id).toList(),
      <String>[tagged.id],
    );
    expect(await service.getByTag('boxing'), isEmpty);
    await service.dispose();
  });

  test('watchAll emits initial snapshot then on every mutation', () async {
    final service = await newService();
    final emitted = <List<JournalEntry>>[];
    final sub = service.watchAll().listen(emitted.add);

    // Allow the initial snapshot to land.
    await Future<void>.delayed(Duration.zero);
    expect(emitted, hasLength(1));
    expect(emitted.first, isEmpty);

    final entry = JournalEntry.create(workoutDate: DateTime(2026, 5, 6));
    await service.add(entry);
    final updated = await service.update(entry.copyWith(preIntent: 'x'));
    await service.delete(updated.id);
    // Let any micro-task hops settle.
    await Future<void>.delayed(Duration.zero);

    expect(emitted, hasLength(4));
    expect(emitted[1], hasLength(1));
    expect(emitted[2], hasLength(1));
    expect(emitted[3], isEmpty);

    await sub.cancel();
    await service.dispose();
  });

  test('concurrent creates serialize correctly', () async {
    final service = await newService();
    final entries = List<JournalEntry>.generate(
      5,
      (i) => JournalEntry.create(
        workoutDate: DateTime(2026, 5, i + 1),
        preIntent: 'note $i',
      ),
    );
    // Fire all 5 in parallel without awaiting between them.
    await Future.wait(entries.map((e) => service.add(e)));
    final all = await service.getAll();
    expect(all, hasLength(5));
    expect(
      all.map((e) => e.id).toSet(),
      entries.map((e) => e.id).toSet(),
    );

    // And the persisted form matches: re-load from a fresh service.
    await service.dispose();
    final reloaded = await newService();
    expect(await reloaded.getAll(), hasLength(5));
    await reloaded.dispose();
  });

  test('init stamps schema version on first run', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(JournalService.schemaVersionKey), isNull);
    final service = JournalService(prefs);
    await service.init();
    expect(
      prefs.getString(JournalService.schemaVersionKey),
      JournalService.currentSchemaVersion,
    );
    await service.dispose();
  });

  test('init tolerates a future schema version without crashing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      JournalService.schemaVersionKey: '99',
    });
    final prefs = await SharedPreferences.getInstance();
    final service = JournalService(prefs);
    await service.init();
    expect(await service.getAll(), isEmpty);
    await service.dispose();
  });

  test('calls before init throw StateError', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = JournalService(prefs);
    expect(() => service.getAll(), throwsStateError);
    await service.dispose();
  });
}
