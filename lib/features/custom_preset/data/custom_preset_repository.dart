import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/custom_preset.dart';

/// SharedPreferences-backed store for user-defined workout presets.
///
/// The whole list lives under a single JSON-encoded key so a single
/// read/write covers the whole feature. Reads tolerate corruption: a JSON
/// decode failure logs via [debugPrint] and returns an empty list, never
/// throws.
class CustomPresetRepository {
  CustomPresetRepository();

  static const String _storageKey = 'custom_presets_v1';

  /// Free-tier cap. The list screen hides the "+" create row once this
  /// many presets are saved; the controller exposes [canCreateNew] which
  /// reads from the same value.
  static const int kMaxSlots = 3;

  Future<List<CustomPreset>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return <CustomPreset>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <CustomPreset>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CustomPreset.fromJson)
          .toList(growable: false);
    } catch (e, st) {
      debugPrint('CustomPresetRepository.loadAll: $e\n$st');
      return <CustomPreset>[];
    }
  }

  /// Adds a new preset or replaces an existing one (matched by [preset.id]).
  Future<void> save(CustomPreset preset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await loadAll();
      final idx = current.indexWhere((p) => p.id == preset.id);
      final List<CustomPreset> next = List<CustomPreset>.from(current);
      if (idx >= 0) {
        next[idx] = preset;
      } else {
        next.add(preset);
      }
      await prefs.setString(_storageKey, _encode(next));
    } catch (e, st) {
      debugPrint('CustomPresetRepository.save: $e\n$st');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await loadAll();
      final next = current.where((p) => p.id != id).toList(growable: false);
      await prefs.setString(_storageKey, _encode(next));
    } catch (e, st) {
      debugPrint('CustomPresetRepository.delete: $e\n$st');
      rethrow;
    }
  }

  Future<bool> hasCapacity() async {
    final current = await loadAll();
    return current.length < kMaxSlots;
  }

  static String _encode(List<CustomPreset> presets) =>
      jsonEncode(presets.map((p) => p.toJson()).toList(growable: false));
}
