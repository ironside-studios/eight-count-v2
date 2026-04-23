import 'package:uuid/uuid.dart';

/// User-defined workout preset. Saved into one of 3 slots on device.
///
/// `preCountdownSeconds` is intentionally not editable in the UI — 45s is
/// the app-wide warmup contract. Stored in JSON anyway so future flex is
/// possible without a schema migration.
class CustomPreset {
  CustomPreset({
    required this.id,
    required this.name,
    required this.rounds,
    required this.workSeconds,
    required this.restSeconds,
    required this.createdAt,
    required this.updatedAt,
    this.preCountdownSeconds = kLockedPreCountdownSeconds,
  });

  /// Factory for brand-new presets. Generates a v4 UUID and stamps both
  /// createdAt and updatedAt to the same moment.
  factory CustomPreset.create({
    required String name,
    required int rounds,
    required int workSeconds,
    required int restSeconds,
  }) {
    final now = DateTime.now().toUtc();
    return CustomPreset(
      id: const Uuid().v4(),
      name: name,
      rounds: rounds,
      workSeconds: workSeconds,
      restSeconds: restSeconds,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory CustomPreset.fromJson(Map<String, dynamic> json) {
    return CustomPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      rounds: (json['rounds'] as num).toInt(),
      workSeconds: (json['workSeconds'] as num).toInt(),
      restSeconds: (json['restSeconds'] as num).toInt(),
      preCountdownSeconds: (json['preCountdownSeconds'] as num?)?.toInt() ??
          kLockedPreCountdownSeconds,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String id;
  final String name;
  final int rounds;
  final int workSeconds;
  final int restSeconds;
  final int preCountdownSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  // --- Validation bounds (all inclusive) ---
  static const int kMinRounds = 1;
  static const int kMaxRounds = 50;
  static const int kMinWorkSeconds = 10;
  static const int kMaxWorkSeconds = 1800; // 30:00
  static const int kMinRestSeconds = 10;
  static const int kMaxRestSeconds = 300; // 5:00
  static const int kMaxNameLength = 24;
  static const int kLockedPreCountdownSeconds = 45;

  /// Returns a human-readable error message, or null if all fields are valid.
  /// Used by the editor to gate the Save button and surface SnackBar errors.
  static String? validate({
    required String name,
    required int rounds,
    required int workSeconds,
    required int restSeconds,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Name cannot be empty';
    }
    if (trimmed.length > kMaxNameLength) {
      return 'Name must be $kMaxNameLength characters or fewer';
    }
    if (rounds < kMinRounds || rounds > kMaxRounds) {
      return 'Rounds must be between $kMinRounds and $kMaxRounds';
    }
    if (workSeconds < kMinWorkSeconds || workSeconds > kMaxWorkSeconds) {
      return 'Work duration out of range';
    }
    if (restSeconds < kMinRestSeconds || restSeconds > kMaxRestSeconds) {
      return 'Rest duration out of range';
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'rounds': rounds,
        'workSeconds': workSeconds,
        'restSeconds': restSeconds,
        'preCountdownSeconds': preCountdownSeconds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  CustomPreset copyWith({
    String? name,
    int? rounds,
    int? workSeconds,
    int? restSeconds,
    DateTime? updatedAt,
  }) {
    return CustomPreset(
      id: id,
      name: name ?? this.name,
      rounds: rounds ?? this.rounds,
      workSeconds: workSeconds ?? this.workSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      preCountdownSeconds: preCountdownSeconds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomPreset &&
        other.id == id &&
        other.name == name &&
        other.rounds == rounds &&
        other.workSeconds == workSeconds &&
        other.restSeconds == restSeconds &&
        other.preCountdownSeconds == preCountdownSeconds &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        rounds,
        workSeconds,
        restSeconds,
        preCountdownSeconds,
        createdAt,
        updatedAt,
      );
}
