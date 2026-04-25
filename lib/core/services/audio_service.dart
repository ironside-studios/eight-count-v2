// ============================================================================
// AUDIOSERVICE — LOCKED 2026-04-25
// ============================================================================
// Hardware-verified on Samsung S23 Ultra (SM-S918U):
//   - Test A: Boxing rest ghost — PASS
//   - Test B: Main-screen ghost — PASS
//   - Test C: Force-close survival — PASS
// Original lock 2026-04-20. Unlocked 2026-04-23 for ghost timer fix
// (commit 54f9477). Re-locked 2026-04-25 after S23 device verification.
// DO NOT MODIFY without explicit project owner request.
// ============================================================================

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

// TEMP: Step 5.3 — ALL audio muted pending re-recording session (bells, wood_clack, whistle).
// User is re-recording all cues with iPhone 17 Pro Max + Dolby On for consistent quality.
// Set false to re-enable. Files at assets/audio/ remain preloaded.
const bool kAudioMuted = false;

/// Audio cue dispatcher.
///
/// Cue contract (stable string identifiers so asset paths stay data-driven):
///   - 'wood_clack'    11s warning marker before phase expiry
///   - 'bell_start'    work-phase entry bell
///   - 'bell_end'      workout-complete bell
///   - 'whistle_long'  rest-phase entry whistle
///
/// Priority (see [_priority]):
///   bell_end > bell_start > whistle_long > wood_clack
///
/// Queue / overlap rule (applied in [play]):
///   - No current cue → play immediately.
///   - New cue priority > current priority → preempt: stop current, play new.
///   - Else, if current has > 200ms remaining → stop current, play new.
///   - Else (≤ 200ms remaining) → queue the new cue. Only one queue slot —
///     a later call replaces an earlier queued cue (last-write-wins).
///     The queued cue plays when the current cue ends naturally.
///
/// Race safety: all [play] calls are funnelled through [_playChain] so the
/// queue / priority state machine always sees a consistent snapshot, even
/// under rapid-fire invocation.
///
/// Lifecycle (Step 5.4 — ghost-timer fix):
///   Production code uses [AudioService.instance] exclusively. The
///   [WidgetsBindingObserver] mixin hooks `AppLifecycleState.detached` so
///   force-close triggers [stopAll], preventing `just_audio`'s native
///   `ExoPlayer` from outliving the Dart VM. [stopAll] is also called from
///   `TimerScreen.dispose` so orphaned cues sitting in the serial chain
///   never fire on the home screen after a workout ends.
class AudioService with WidgetsBindingObserver {
  /// Generative constructor. Production code should use [AudioService.instance]
  /// exclusively — this ctor is still callable so test subclasses can extend
  /// `AudioService` via the standard implicit `super()` pattern.
  AudioService() {
    // Test contexts that don't call `TestWidgetsFlutterBinding.ensureInitialized`
    // will throw when `WidgetsBinding.instance` is read; swallow so the
    // subclass can still be constructed without a binding.
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      /* No WidgetsBinding available — test context without binding init. */
    }
  }

  /// App-wide singleton. Lazy-initialised on first access (Dart's standard
  /// top-level `final` semantics). Every production caller routes through
  /// this — the unnamed constructor stays callable only so that in-repo
  /// test subclasses can extend the class without refactoring.
  static final AudioService instance = AudioService();

  // --- Cue durations (normalized in Phase 1, 2026-04-23) ---
  // Reference values for cue-scheduling math. Not wired to playback logic
  // yet — runtime `player.duration` is still read from the loaded asset
  // via `remainingFor(...)`. These constants exist so callers (engine,
  // tests, future scheduler) have a stable source of truth that doesn't
  // require loading the asset to consult.
  static const Duration bellStartDuration = Duration(milliseconds: 2976);
  static const Duration bellEndDuration = Duration(milliseconds: 3264);
  static const Duration whistleLongDuration = Duration(milliseconds: 936);
  static const Duration whistleDoubleDuration = Duration(milliseconds: 2040);
  static const Duration woodClackDuration = Duration(milliseconds: 1896);

  // --- Static maps: cue identity, priority, asset path ---

  static const Map<String, int> _priority = <String, int>{
    'wood_clack': 1,
    'whistle_long': 2,
    'bell_start': 3,
    'bell_end': 4,
  };

  static const Map<String, String> _assetPath = <String, String>{
    'bell_start': 'assets/audio/bell_start.mp3',
    'bell_end': 'assets/audio/bell_end.mp3',
    'wood_clack': 'assets/audio/wood_clack.mp3',
    'whistle_long': 'assets/audio/whistle_long.mp3',
  };

  // --- Owned state ---

  final Map<String, AudioPlayer> _players = <String, AudioPlayer>{};
  final Map<String, StreamSubscription<ProcessingState>> _subscriptions =
      <String, StreamSubscription<ProcessingState>>{};

  String? _currentCue;
  String? _queuedCue;
  bool _disposed = false;

  /// Set by [stopAll] before flushing. Every in-flight [_executePlay] and
  /// [handlePlaybackCompleted] early-returns while this is true, so futures
  /// already `.then`'d onto [_playChain] become no-ops. Reset to false at
  /// the end of [stopAll] so the service is reusable for the next workout.
  bool _cancelled = false;

  Future<void> _playChain = Future<void>.value();

  /// Currently-playing cue, or null if silent.
  String? get currentCue => _currentCue;

  /// Contents of the single queue slot (or null).
  String? get queuedCue => _queuedCue;

  /// Drains any in-flight [play] invocations. Used by tests to deterministically
  /// await the full effect of an async queue mutation.
  @visibleForTesting
  Future<void> settle() => _playChain;

  // --- Public API ---

  /// Preloads all four cue players. Must be called once at app startup before
  /// the workout engine is allowed to fire [play].
  Future<void> init() async {
    if (_disposed) {
      throw StateError('AudioService: init() called after dispose()');
    }
    await loadPlayers();
  }

  /// Dispatches a cue. Returns a Future that completes when the queue/priority
  /// logic has fully settled for this call (playback itself is fire-and-forget).
  Future<void> play(String cueName) {
    if (!_assetPath.containsKey(cueName)) {
      throw ArgumentError.value(
        cueName,
        'cueName',
        'Unknown audio cue. Known cues: ${_assetPath.keys.join(', ')}',
      );
    }
    final Future<void> task = _playChain.then((_) => _executePlay(cueName));
    // Tail of the chain must never reject, or rapid-succession calls would
    // carry a rejection forward. Swallow errors for chain continuity; the
    // caller's `task` future still rejects if _executePlay throws.
    _playChain = task.catchError((Object _) {});
    return task;
  }

  /// Halts all playback and cancels any queued / in-flight cues.
  ///
  /// Called on `TimerScreen.dispose` (so orphaned cues never fire on the
  /// home screen after a workout ends) and on
  /// `AppLifecycleState.detached` (so force-close doesn't leave
  /// `just_audio`'s native `ExoPlayer` still playing). Idempotent and
  /// reusable — the service is ready for the next workout once this
  /// returns.
  Future<void> stopAll() async {
    _cancelled = true;
    _currentCue = null;
    _queuedCue = null;
    for (final player in _players.values) {
      try {
        await player.stop();
      } catch (_) {
        /* Player may already be stopped or disposed — teardown is best-effort. */
      }
    }
    _playChain = Future<void>.value();
    _cancelled = false;
  }

  /// Releases all players + subscriptions; cancels any queued/current cue.
  /// Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _queuedCue = null;
    final String? wasCurrent = _currentCue;
    _currentCue = null;

    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {
      /* No binding available — same guard as the constructor. */
    }

    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();

    if (wasCurrent != null) {
      try {
        await stopPlayback(wasCurrent);
      } catch (_) {
        /* Swallow — we're tearing down anyway. */
      }
    }

    for (final player in _players.values) {
      try {
        await player.dispose();
      } catch (_) {
        /* Same — teardown is best-effort. */
      }
    }
    _players.clear();
  }

  // --- App lifecycle ---

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop ONLY on detached (process teardown). On `paused` / `inactive`
    // the app may still need cues to ring through the lock screen or
    // during a phone call — this is a boxing timer, not a media app.
    if (state == AppLifecycleState.detached) {
      unawaited(stopAll());
    }
  }

  // --- Hooks: overridable by test subclasses to stub out the platform layer ---

  /// Creates the four [AudioPlayer]s, loads their assets, and wires a
  /// completion listener per player. Subclasses in tests override this to
  /// no-op so `just_audio` is never invoked.
  @protected
  Future<void> loadPlayers() async {
    for (final entry in _assetPath.entries) {
      try {
        final AudioPlayer player = AudioPlayer();
        await player.setAsset(entry.value);
        _players[entry.key] = player;
        _subscriptions[entry.key] =
            player.processingStateStream.listen((ProcessingState state) {
          if (state == ProcessingState.completed) {
            handlePlaybackCompleted(entry.key);
          }
        });
      } catch (e) {
        throw StateError(
          'AudioService: failed to load asset "${entry.value}" '
          'for cue "${entry.key}": $e',
        );
      }
    }
  }

  /// Seeks to 0 and plays the cue's player. Fire-and-forget — the returned
  /// Future completes after seek + play kickoff, not after playback ends.
  @protected
  Future<void> startPlayback(String cueName) async {
    // Step 5.3 (revised): kill switch for ALL audio output pending the
    // re-recording pass. Cues still flow through priority/queue so the
    // state machine is unaffected — only the actual player.play() is
    // skipped. Flip `kAudioMuted` to `false` once new assets ship.
    if (kAudioMuted) return;
    final AudioPlayer? player = _players[cueName];
    if (player == null) return;
    await player.seek(Duration.zero);
    unawaited(player.play());
  }

  /// Stops the cue's player.
  @protected
  Future<void> stopPlayback(String cueName) async {
    final AudioPlayer? player = _players[cueName];
    if (player == null) return;
    await player.stop();
  }

  /// `duration - position` for the cue's player, guarded against unknown
  /// durations and negative values.
  @protected
  Duration remainingFor(String cueName) {
    final AudioPlayer? player = _players[cueName];
    if (player == null) return Duration.zero;
    final Duration? total = player.duration;
    if (total == null) return Duration.zero;
    final Duration rem = total - player.position;
    return rem.isNegative ? Duration.zero : rem;
  }

  /// Called when the currently-playing cue reaches its natural end. Real
  /// subclasses trigger this from a `processingStateStream` listener; test
  /// subclasses call it directly to simulate a cue finishing.
  @protected
  void handlePlaybackCompleted(String cueName) {
    if (_cancelled) return;
    if (_disposed) return;
    if (_currentCue != cueName) return; // stale notification
    _currentCue = null;
    final String? promoted = _queuedCue;
    _queuedCue = null;
    if (promoted != null) {
      final Future<void> task =
          _playChain.then((_) => _executePlay(promoted));
      _playChain = task.catchError((Object _) {});
    }
  }

  // --- Internals ---

  Future<void> _executePlay(String newCue) async {
    if (_cancelled) return;
    if (_disposed) return;
    final int newPrio = _priority[newCue]!;

    // Case 1: nothing playing.
    if (_currentCue == null) {
      await startPlayback(newCue);
      _currentCue = newCue;
      return;
    }

    final String current = _currentCue!;
    final int currentPrio = _priority[current]!;

    // Case 2: higher-priority cue preempts. Drops any queued cue too.
    if (newPrio > currentPrio) {
      _currentCue = null;
      _queuedCue = null;
      await stopPlayback(current);
      await startPlayback(newCue);
      _currentCue = newCue;
      return;
    }

    // Case 3: same or lower priority → 200ms queue rule.
    final Duration remaining = remainingFor(current);
    if (remaining > const Duration(milliseconds: 200)) {
      _currentCue = null;
      await stopPlayback(current);
      await startPlayback(newCue);
      _currentCue = newCue;
    } else {
      // Last-write-wins for the single queue slot.
      _queuedCue = newCue;
    }
  }
}
