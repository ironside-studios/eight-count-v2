import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eight_count/features/custom/models/custom_config.dart';
import 'package:eight_count/features/custom/services/custom_preset_service.dart';

/// Hits the real CustomPresetService.instance singleton, which is the
/// only allowed pattern in production. Each test resets the underlying
/// SharedPreferences mock and re-runs init() so the service's in-memory
/// cache reflects an empty starting state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final svc = CustomPresetService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Reset slots by clearing each one (will hit the empty
    // SharedPreferences mock and reset the in-memory cache).
    await svc.clearSlot(0);
    await svc.clearSlot(1);
    await svc.clearSlot(2);
  });

  test('getAllSlots() returns 3 empty configs after clearing', () async {
    final slots = svc.getAllSlots();
    expect(slots.length, 3);
    for (int i = 0; i < 3; i++) {
      expect(slots[i].slotIndex, i);
      expect(slots[i].isSaved, isFalse);
    }
  });

  test('saveSlot persists and emits on stream', () async {
    final completer = Completer<List<CustomConfig>>();
    final sub = svc.slotsStream.listen(completer.complete);
    addTearDown(sub.cancel);

    final config = CustomConfig.empty(1).copyWith(
      name: 'Heavy Bag',
      rounds: 8,
      workSeconds: 120,
      restSeconds: 45,
    );
    await svc.saveSlot(config);

    final emitted = await completer.future
        .timeout(const Duration(seconds: 1));
    expect(emitted[1].name, 'Heavy Bag');
    expect(emitted[1].isSaved, isTrue);
    expect(svc.getSlot(1).name, 'Heavy Bag');

    // Persistence: a fresh prefs read should find the JSON.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('custom_preset_slot_1'), isNotNull);
  });

  test('clearSlot removes from prefs and emits empty config', () async {
    // First save a slot.
    await svc.saveSlot(CustomConfig.empty(0).copyWith(name: 'Test'));
    expect(svc.getSlot(0).isSaved, isTrue);

    // Now clear and watch the emit.
    final completer = Completer<List<CustomConfig>>();
    final sub = svc.slotsStream.listen(completer.complete);
    addTearDown(sub.cancel);

    await svc.clearSlot(0);
    final emitted = await completer.future
        .timeout(const Duration(seconds: 1));
    expect(emitted[0].isSaved, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('custom_preset_slot_0'), isNull);
  });

  test('slot indices remain stable across save/clear operations',
      () async {
    await svc.saveSlot(CustomConfig.empty(0).copyWith(name: 'Slot Zero'));
    await svc.saveSlot(CustomConfig.empty(2).copyWith(name: 'Slot Two'));
    expect(svc.getSlot(0).name, 'Slot Zero');
    expect(svc.getSlot(1).isSaved, isFalse);
    expect(svc.getSlot(2).name, 'Slot Two');

    await svc.clearSlot(0);
    expect(svc.getSlot(0).isSaved, isFalse);
    expect(svc.getSlot(2).name, 'Slot Two',
        reason: 'clearing slot 0 must not affect slot 2');
  });

  test('saveSlot rejects an invalid name with ArgumentError', () async {
    final bad = CustomConfig.empty(0).copyWith(name: '');
    expect(
      () => svc.saveSlot(bad),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('saveSlot rejects out-of-bounds rounds', () async {
    final bad = CustomConfig.empty(0).copyWith(name: 'OK', rounds: 31);
    expect(
      () => svc.saveSlot(bad),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('stream emits exactly once per save and once per clear', () async {
    final events = <List<CustomConfig>>[];
    final sub = svc.slotsStream.listen(events.add);
    addTearDown(sub.cancel);

    await svc.saveSlot(CustomConfig.empty(0).copyWith(name: 'A'));
    await svc.saveSlot(CustomConfig.empty(1).copyWith(name: 'B'));
    await svc.clearSlot(0);

    // Allow the stream microtasks to drain.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(events.length, 3,
        reason: '2 saves + 1 clear → 3 emissions');
  });
}
