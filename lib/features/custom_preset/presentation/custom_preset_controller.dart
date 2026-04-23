import 'package:flutter/foundation.dart';

import '../data/custom_preset_repository.dart';
import '../domain/custom_preset.dart';

/// App-wide holder for the user's saved custom presets.
///
/// Singleton pattern matches the existing `localeService` / `audioService`
/// wiring in `lib/main.dart` — import [customPresetController] directly
/// from any widget that needs it and wrap consumers in an
/// `AnimatedBuilder(animation: customPresetController, …)` to pick up
/// change notifications.
class CustomPresetController extends ChangeNotifier {
  CustomPresetController({CustomPresetRepository? repository})
      : _repository = repository ?? CustomPresetRepository();

  final CustomPresetRepository _repository;

  List<CustomPreset> _presets = <CustomPreset>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<CustomPreset> get presets => List<CustomPreset>.unmodifiable(_presets);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// True while the saved list has spare slots.
  bool get canCreateNew =>
      _presets.length < CustomPresetRepository.kMaxSlots;

  /// First-load hook. Call from the list screen's `initState` or the app's
  /// startup sequence. Safe to call multiple times — reads are idempotent.
  Future<void> loadPresets() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _presets = await _repository.loadAll();
    } catch (e) {
      _errorMessage = 'Failed to load workouts';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a new preset or replaces an existing one by id.
  /// Returns `true` on success; `false` if capacity is exceeded or the
  /// repo throws. Error messages are set on [errorMessage] for UI display.
  Future<bool> savePreset(CustomPreset preset) async {
    _errorMessage = null;

    // Capacity check — only enforced on net-new inserts.
    final existingIdx = _presets.indexWhere((p) => p.id == preset.id);
    if (existingIdx < 0 && !canCreateNew) {
      _errorMessage = 'Workout slots full — delete one to add another';
      notifyListeners();
      return false;
    }

    try {
      await _repository.save(preset);
      final next = List<CustomPreset>.from(_presets);
      if (existingIdx >= 0) {
        next[existingIdx] = preset;
      } else {
        next.add(preset);
      }
      _presets = next;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save workout';
      notifyListeners();
      return false;
    }
  }

  Future<void> deletePreset(String id) async {
    try {
      await _repository.delete(id);
      _presets = _presets.where((p) => p.id != id).toList(growable: false);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete workout';
      notifyListeners();
    }
  }
}

/// App-wide singleton — lazy-initialised on first access, same pattern as
/// `localeService` and `audioService`.
final CustomPresetController customPresetController =
    CustomPresetController();
