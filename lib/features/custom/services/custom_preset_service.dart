import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_config.dart';

/// Singleton owner of the user's three Custom-preset slots. Pattern
/// matches `lib/core/services/audio_service.dart` (`static final
/// CustomPresetService instance = CustomPresetService._()`).
///
/// Slots are stored under SharedPreferences keys
/// `custom_preset_slot_0/1/2`. Empty slots have NO key in prefs
/// (distinguished from saved-but-blank-name); the in-memory cache is
/// always exactly 3 entries with `CustomConfig.empty(i)` filling
/// unsaved positions.
class CustomPresetService {
  CustomPresetService._();

  static final CustomPresetService instance = CustomPresetService._();

  static const int _slotCount = 3;
  static const String _keyPrefix = 'custom_preset_slot_';

  final List<CustomConfig> _slots = <CustomConfig>[
    CustomConfig.empty(0),
    CustomConfig.empty(1),
    CustomConfig.empty(2),
  ];

  final StreamController<List<CustomConfig>> _slotsController =
      StreamController<List<CustomConfig>>.broadcast();

  bool _initialized = false;

  /// Reactive view of all 3 slots. Emits initial value on [init] and
  /// again on every [saveSlot] / [clearSlot]. UI should subscribe via
  /// a `StreamBuilder` over `Stream<List<CustomConfig>>` with
  /// `initialData: instance.getAllSlots()`.
  Stream<List<CustomConfig>> get slotsStream => _slotsController.stream;

  /// Loads all 3 slots from prefs. Must be awaited from `main()` before
  /// `runApp()` so the home screen never sees an uninitialized cache.
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < _slotCount; i++) {
      final raw = prefs.getString('$_keyPrefix$i');
      if (raw != null) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          _slots[i] = CustomConfig.fromJson(json);
        } catch (e) {
          debugPrint(
              'CustomPresetService: failed to parse slot $i, treating '
              'as empty: $e');
          _slots[i] = CustomConfig.empty(i);
        }
      } else {
        _slots[i] = CustomConfig.empty(i);
      }
    }
    _initialized = true;
    _emit();
  }

  /// Returns an immutable snapshot of all 3 slots in slot-index order.
  List<CustomConfig> getAllSlots() => List<CustomConfig>.unmodifiable(_slots);

  /// Returns the saved config at [index], or [CustomConfig.empty] if
  /// the slot has never been written.
  CustomConfig getSlot(int index) {
    _assertSlotIndex(index);
    return _slots[index];
  }

  /// Validates and persists [config] to its slot. Throws
  /// [ArgumentError] if any field fails validation.
  Future<void> saveSlot(CustomConfig config) async {
    _assertSlotIndex(config.slotIndex);
    final nameErr = CustomConfig.validateName(config.name);
    if (nameErr != null) throw ArgumentError(nameErr);
    final roundsErr = CustomConfig.validateRounds(config.rounds);
    if (roundsErr != null) throw ArgumentError(roundsErr);
    final workErr = CustomConfig.validateWorkSeconds(config.workSeconds);
    if (workErr != null) throw ArgumentError(workErr);
    final restErr = CustomConfig.validateRestSeconds(config.restSeconds);
    if (restErr != null) throw ArgumentError(restErr);

    final stamped = config.copyWith(lastModified: DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_keyPrefix${stamped.slotIndex}',
      jsonEncode(stamped.toJson()),
    );
    _slots[stamped.slotIndex] = stamped;
    _emit();
  }

  /// Removes the slot from prefs and resets the cache entry to
  /// [CustomConfig.empty].
  Future<void> clearSlot(int index) async {
    _assertSlotIndex(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$index');
    _slots[index] = CustomConfig.empty(index);
    _emit();
  }

  /// Closes the broadcast controller. Called from app dispose path if
  /// needed; tests may invoke directly.
  Future<void> dispose() async {
    await _slotsController.close();
  }

  void _emit() {
    _slotsController.add(List<CustomConfig>.unmodifiable(_slots));
  }

  void _assertSlotIndex(int i) {
    if (i < 0 || i >= _slotCount) {
      throw RangeError.range(i, 0, _slotCount - 1, 'slotIndex');
    }
  }
}
