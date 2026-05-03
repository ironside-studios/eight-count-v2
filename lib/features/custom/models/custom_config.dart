import 'package:flutter/foundation.dart';

/// Immutable user-defined preset for the Custom feature. Persisted via
/// [CustomPresetService] in shared_preferences under one of three slot
/// keys. Slots that haven't been written yet are represented by an
/// "empty" config (name == '') — distinguished from saved configs by
/// the [isSaved] getter.
@immutable
class CustomConfig {
  const CustomConfig({
    required this.name,
    required this.rounds,
    required this.workSeconds,
    required this.restSeconds,
    required this.slotIndex,
    required this.lastModified,
  });

  factory CustomConfig.empty(int slotIndex) => CustomConfig(
        name: '',
        rounds: 5,
        workSeconds: 90,
        restSeconds: 30,
        slotIndex: slotIndex,
        lastModified: DateTime.now(),
      );

  factory CustomConfig.fromJson(Map<String, dynamic> json) => CustomConfig(
        name: json['name'] as String,
        rounds: json['rounds'] as int,
        workSeconds: json['workSeconds'] as int,
        restSeconds: json['restSeconds'] as int,
        slotIndex: json['slotIndex'] as int,
        lastModified:
            DateTime.fromMillisecondsSinceEpoch(json['lastModified'] as int),
      );

  final String name;
  final int rounds;
  final int workSeconds;
  final int restSeconds;
  final int slotIndex;
  final DateTime lastModified;

  bool get isSaved => name.trim().isNotEmpty;

  /// Total work + rest seconds for the configured workout (45s
  /// pre-countdown EXCLUDED). Rounds × work + (rounds-1) × rest, since
  /// the final round has no rest after it.
  int get totalWorkoutSeconds =>
      (rounds * workSeconds) + ((rounds - 1) * restSeconds);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'rounds': rounds,
        'workSeconds': workSeconds,
        'restSeconds': restSeconds,
        'slotIndex': slotIndex,
        'lastModified': lastModified.millisecondsSinceEpoch,
      };

  CustomConfig copyWith({
    String? name,
    int? rounds,
    int? workSeconds,
    int? restSeconds,
    int? slotIndex,
    DateTime? lastModified,
  }) {
    return CustomConfig(
      name: name ?? this.name,
      rounds: rounds ?? this.rounds,
      workSeconds: workSeconds ?? this.workSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      slotIndex: slotIndex ?? this.slotIndex,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  // --- Validators (return null if valid, error string otherwise) ---

  /// Allows alphanumerics, spaces, and Latin-1 / Latin Extended-A
  /// accented characters (covers EN + ES). Trims before length check.
  static final RegExp _nameAllowedChars =
      RegExp(r'^[a-zA-Z0-9\sÀ-ſ]+$');

  static String? validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Name cannot be empty';
    if (trimmed.length > 30) return 'Name must be 30 characters or fewer';
    if (!_nameAllowedChars.hasMatch(trimmed)) {
      return 'Name can only contain letters, numbers, and spaces';
    }
    return null;
  }

  static String? validateRounds(int rounds) {
    if (rounds < 1) return 'Rounds must be at least 1';
    if (rounds > 30) return 'Rounds must be 30 or fewer';
    return null;
  }

  static String? validateWorkSeconds(int workSeconds) {
    if (workSeconds < 10) return 'Work must be at least 10 seconds';
    if (workSeconds > 600) return 'Work must be 600 seconds or fewer';
    return null;
  }

  static String? validateRestSeconds(int restSeconds) {
    if (restSeconds < 5) return 'Rest must be at least 5 seconds';
    if (restSeconds > 300) return 'Rest must be 300 seconds or fewer';
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomConfig &&
        other.name == name &&
        other.rounds == rounds &&
        other.workSeconds == workSeconds &&
        other.restSeconds == restSeconds &&
        other.slotIndex == slotIndex &&
        other.lastModified == lastModified;
  }

  @override
  int get hashCode => Object.hash(
        name,
        rounds,
        workSeconds,
        restSeconds,
        slotIndex,
        lastModified,
      );
}
