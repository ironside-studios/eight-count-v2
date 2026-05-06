import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Immutable journal entry tied to a workout date. Persisted via
/// [JournalService] in shared_preferences as one element of a
/// JSON-encoded list under `journal.entries.v1`.
///
/// Equality is full structural — two entries with the same id but
/// different content are NOT equal. Update detection in the UI must
/// rely on `updatedAt` (or `==`), not on id alone.
@immutable
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.workoutDate,
    this.preIntent,
    this.postReflection,
    this.tags = const <String>[],
    this.moodRating,
    this.photoPath,
    this.linkedWorkoutType,
  }) : assert(id != ''); // empty id is never valid

  /// Constructs a new entry, auto-generating [id] (UUID v4) and
  /// stamping [createdAt] / [updatedAt] to UTC `now`. [workoutDate] is
  /// normalized to midnight in its original (typically local) zone so
  /// date-range queries are inclusive of the whole day.
  factory JournalEntry.create({
    required DateTime workoutDate,
    String? preIntent,
    String? postReflection,
    List<String> tags = const <String>[],
    int? moodRating,
    String? photoPath,
    String? linkedWorkoutType,
  }) {
    final DateTime nowUtc = DateTime.now().toUtc();
    return JournalEntry._validated(
      id: const Uuid().v4(),
      createdAt: nowUtc,
      updatedAt: nowUtc,
      workoutDate: _stripTime(workoutDate),
      preIntent: preIntent,
      postReflection: postReflection,
      tags: List<String>.unmodifiable(tags),
      moodRating: moodRating,
      photoPath: photoPath,
      linkedWorkoutType: linkedWorkoutType,
    );
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry._validated(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      workoutDate: DateTime.parse(json['workoutDate'] as String),
      preIntent: json['preIntent'] as String?,
      postReflection: json['postReflection'] as String?,
      tags: List<String>.unmodifiable(
        (json['tags'] as List<dynamic>? ?? const <dynamic>[])
            .cast<String>(),
      ),
      moodRating: json['moodRating'] as int?,
      photoPath: json['photoPath'] as String?,
      linkedWorkoutType: json['linkedWorkoutType'] as String?,
    );
  }

  factory JournalEntry._validated({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime workoutDate,
    String? preIntent,
    String? postReflection,
    required List<String> tags,
    int? moodRating,
    String? photoPath,
    String? linkedWorkoutType,
  }) {
    if (preIntent != null && preIntent.length > maxPreIntentLength) {
      throw ArgumentError.value(
        preIntent.length,
        'preIntent.length',
        'must be <= $maxPreIntentLength',
      );
    }
    if (postReflection != null &&
        postReflection.length > maxPostReflectionLength) {
      throw ArgumentError.value(
        postReflection.length,
        'postReflection.length',
        'must be <= $maxPostReflectionLength',
      );
    }
    if (tags.length > maxTagsPerEntry) {
      throw ArgumentError.value(
        tags.length,
        'tags.length',
        'must be <= $maxTagsPerEntry',
      );
    }
    for (final String tag in tags) {
      if (tag.length > maxTagLength) {
        throw ArgumentError.value(
          tag,
          'tag',
          'each tag must be <= $maxTagLength chars',
        );
      }
    }
    if (moodRating != null && (moodRating < 1 || moodRating > 5)) {
      throw ArgumentError.value(moodRating, 'moodRating', 'must be 1-5');
    }
    return JournalEntry(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      workoutDate: workoutDate,
      preIntent: preIntent,
      postReflection: postReflection,
      tags: tags,
      moodRating: moodRating,
      photoPath: photoPath,
      linkedWorkoutType: linkedWorkoutType,
    );
  }

  static const int maxPreIntentLength = 500;
  static const int maxPostReflectionLength = 1000;
  static const int maxTagsPerEntry = 10;
  static const int maxTagLength = 24;

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime workoutDate;
  final String? preIntent;
  final String? postReflection;
  final List<String> tags;
  final int? moodRating;
  final String? photoPath;
  final String? linkedWorkoutType;

  /// Returns a copy with the given fields replaced. [id] and
  /// [createdAt] cannot be changed; [updatedAt] defaults to UTC `now`
  /// when any field is replaced (callers may still pass an explicit
  /// timestamp, e.g. for tests). All other fields fall back to the
  /// current value when their argument is omitted.
  ///
  /// Nullable fields cannot be cleared via copyWith — pass a sentinel
  /// or rebuild the entry from scratch if you need null. (None of the
  /// current call sites need clearing, so we keep the API simple.)
  JournalEntry copyWith({
    DateTime? updatedAt,
    DateTime? workoutDate,
    String? preIntent,
    String? postReflection,
    List<String>? tags,
    int? moodRating,
    String? photoPath,
    String? linkedWorkoutType,
  }) {
    return JournalEntry._validated(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      workoutDate:
          workoutDate != null ? _stripTime(workoutDate) : this.workoutDate,
      preIntent: preIntent ?? this.preIntent,
      postReflection: postReflection ?? this.postReflection,
      tags: tags != null
          ? List<String>.unmodifiable(tags)
          : this.tags,
      moodRating: moodRating ?? this.moodRating,
      photoPath: photoPath ?? this.photoPath,
      linkedWorkoutType: linkedWorkoutType ?? this.linkedWorkoutType,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'workoutDate': workoutDate.toIso8601String(),
        'preIntent': preIntent,
        'postReflection': postReflection,
        'tags': tags,
        'moodRating': moodRating,
        'photoPath': photoPath,
        'linkedWorkoutType': linkedWorkoutType,
      };

  static DateTime _stripTime(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalEntry &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.workoutDate == workoutDate &&
        other.preIntent == preIntent &&
        other.postReflection == postReflection &&
        listEquals(other.tags, tags) &&
        other.moodRating == moodRating &&
        other.photoPath == photoPath &&
        other.linkedWorkoutType == linkedWorkoutType;
  }

  @override
  int get hashCode => Object.hash(
        id,
        createdAt,
        updatedAt,
        workoutDate,
        preIntent,
        postReflection,
        Object.hashAll(tags),
        moodRating,
        photoPath,
        linkedWorkoutType,
      );
}
