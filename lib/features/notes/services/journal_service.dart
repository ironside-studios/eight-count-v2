import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/journal_entry.dart';

/// Persistence layer for [JournalEntry] over [SharedPreferences].
///
/// Storage layout:
/// - `journal.entries.v1`: JSON-encoded `List<Map<String, dynamic>>` of
///   all entries in arbitrary order. Sort happens on read.
/// - `journal.schema.version`: string `"1"`. Reserved for migrations.
///
/// Concurrency:
/// All write paths (`create`, `update`, `delete`) are serialized
/// through [_writeQueue] so two simultaneous awaits don't clobber
/// each other's encoded list. Reads hit the in-memory cache and do
/// not touch disk.
class JournalService {
  /// Constructor accepts an explicit [SharedPreferences] for tests.
  /// Production code should use [JournalService.create].
  JournalService(this._prefs);

  /// Production factory: resolves [SharedPreferences] internally.
  static Future<JournalService> create() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return JournalService(prefs);
  }

  static const String entriesKey = 'journal.entries.v1';
  static const String schemaVersionKey = 'journal.schema.version';
  static const String currentSchemaVersion = '1';

  final SharedPreferences _prefs;

  final Map<String, JournalEntry> _cache = <String, JournalEntry>{};

  final StreamController<List<JournalEntry>> _controller =
      StreamController<List<JournalEntry>>.broadcast();

  /// Tail of the serialized write queue. Each mutation chains itself
  /// onto this future so disk writes happen one at a time even when
  /// callers fire many in parallel.
  Future<void> _writeQueue = Future<void>.value();

  bool _initialized = false;

  /// Loads persisted entries into the in-memory cache. Safe to call
  /// multiple times; subsequent calls are no-ops.
  Future<void> init() async {
    if (_initialized) return;
    final String? version = _prefs.getString(schemaVersionKey);
    if (version == null) {
      // First run — stamp the schema version so we know which format
      // future migrations are reading from.
      await _prefs.setString(schemaVersionKey, currentSchemaVersion);
    } else if (version != currentSchemaVersion) {
      debugPrint(
        'JournalService: schema version mismatch '
        '(found "$version", expected "$currentSchemaVersion"). '
        'Continuing with current parser; consider running a migration.',
      );
    }

    final String? raw = _prefs.getString(entriesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        for (final dynamic item in decoded) {
          final entry =
              JournalEntry.fromJson(item as Map<String, dynamic>);
          _cache[entry.id] = entry;
        }
      } catch (e, st) {
        debugPrint(
          'JournalService: failed to parse entries, treating as empty: $e\n$st',
        );
        _cache.clear();
      }
    }
    _initialized = true;
    _emit();
  }

  /// Returns all entries sorted descending by [JournalEntry.workoutDate].
  /// Ties are broken by [JournalEntry.createdAt] descending.
  Future<List<JournalEntry>> getAll() async {
    _ensureInitialized();
    return _sorted(_cache.values);
  }

  Future<JournalEntry?> getById(String id) async {
    _ensureInitialized();
    return _cache[id];
  }

  /// Inclusive on both bounds. [start] and [end] are compared against
  /// [JournalEntry.workoutDate] as-is — callers are responsible for
  /// passing date-only values if they want whole-day semantics.
  Future<List<JournalEntry>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    _ensureInitialized();
    final Iterable<JournalEntry> filtered = _cache.values.where((e) {
      return !e.workoutDate.isBefore(start) && !e.workoutDate.isAfter(end);
    });
    return _sorted(filtered);
  }

  /// Case-sensitive tag match.
  Future<List<JournalEntry>> getByTag(String tag) async {
    _ensureInitialized();
    return _sorted(_cache.values.where((e) => e.tags.contains(tag)));
  }

  /// Persists [entry] and emits on [watchAll]. Returns the entry as
  /// stored (currently identical to the argument).
  ///
  /// Named `add` rather than `create` because the static factory
  /// [JournalService.create] occupies the constructor-style name and
  /// Dart forbids a static and instance member sharing it.
  Future<JournalEntry> add(JournalEntry entry) async {
    _ensureInitialized();
    return _enqueueWrite(() async {
      _cache[entry.id] = entry;
      await _flush();
      _emit();
      return entry;
    });
  }

  /// Persists an updated copy of [entry] with [JournalEntry.updatedAt]
  /// bumped to UTC `now`. Throws [StateError] if the id is unknown.
  Future<JournalEntry> update(JournalEntry entry) async {
    _ensureInitialized();
    return _enqueueWrite(() async {
      if (!_cache.containsKey(entry.id)) {
        throw StateError(
          'JournalService.update: no entry with id ${entry.id}',
        );
      }
      final JournalEntry stamped =
          entry.copyWith(updatedAt: DateTime.now().toUtc());
      _cache[stamped.id] = stamped;
      await _flush();
      _emit();
      return stamped;
    });
  }

  /// Removes the entry with [id]. No-op if it doesn't exist.
  Future<void> delete(String id) async {
    _ensureInitialized();
    await _enqueueWrite(() async {
      if (_cache.remove(id) != null) {
        await _flush();
        _emit();
      }
    });
  }

  /// Broadcast stream of the full sorted list. Emits the current
  /// snapshot immediately to new subscribers, then again on every
  /// successful mutation.
  Stream<List<JournalEntry>> watchAll() async* {
    _ensureInitialized();
    yield _sorted(_cache.values);
    yield* _controller.stream;
  }

  /// Closes the broadcast controller. Tests may call directly; app
  /// lifecycle owners may call from dispose paths.
  Future<void> dispose() async {
    await _controller.close();
  }

  Future<T> _enqueueWrite<T>(Future<T> Function() task) {
    final Completer<T> completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _flush() async {
    final List<Map<String, dynamic>> payload =
        _cache.values.map((e) => e.toJson()).toList(growable: false);
    await _prefs.setString(entriesKey, jsonEncode(payload));
  }

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(_sorted(_cache.values));
  }

  List<JournalEntry> _sorted(Iterable<JournalEntry> source) {
    final List<JournalEntry> list = source.toList()
      ..sort((a, b) {
        final int byDate = b.workoutDate.compareTo(a.workoutDate);
        if (byDate != 0) return byDate;
        return b.createdAt.compareTo(a.createdAt);
      });
    return List<JournalEntry>.unmodifiable(list);
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'JournalService.init() must be awaited before any other call.',
      );
    }
  }
}
