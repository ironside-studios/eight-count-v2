import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/video_settings.dart';

/// Singleton owner of the user's Video Pack preferences. Pattern matches
/// `lib/features/custom/services/custom_preset_service.dart` — private
/// named constructor + `static final ServiceName instance = ServiceName._()`.
///
/// Persisted under SharedPreferences key `video_settings_v1`. Settings
/// are loaded lazily on first [loadSettings] call; [saveSettings] writes
/// through immediately so every UI toggle persists without an explicit
/// Save button.
class VideoSettingsService {
  VideoSettingsService._();

  static final VideoSettingsService instance = VideoSettingsService._();

  static const String _prefsKey = 'video_settings_v1';

  /// Loads the user's saved settings, falling back to [VideoSettings.defaults]
  /// if the prefs key is absent or malformed.
  Future<VideoSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return VideoSettings.defaults();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return VideoSettings.fromJson(json);
    } catch (e) {
      debugPrint(
        'VideoSettingsService: failed to parse stored settings, falling '
        'back to defaults: $e',
      );
      return VideoSettings.defaults();
    }
  }

  /// Persists [settings] under the well-known prefs key. Idempotent —
  /// safe to call on every UI change.
  Future<void> saveSettings(VideoSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
  }
}
