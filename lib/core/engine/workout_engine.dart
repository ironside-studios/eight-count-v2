import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/workout_config.dart';
import '../models/workout_phase.dart';
import '../models/workout_state.dart';
import '../services/audio_service.dart';

/// The workout state machine.
///
/// Architectural contract (non-negotiable, see Step 3.1 spec):
///   1. `remainingSeconds` is NEVER stored as mutable state. It is always
///      re-derived from DateTime math:
///          remaining = _phaseEndsAt.difference(_clock())
///      Ticker drives rebuilds, DateTime drives truth.
///   2. Audio cues never overlap — AudioService handles stop-before-play.
///      Engine just calls [AudioService.play].
///   3. wood_clack fires at remaining ≤ 11000ms (NOT 10000ms) so the 1.88s
///      clip finishes before bell_end at 0ms.
///   4. Phase-entry cues (bell_start, whistle_long, bell_end) fire from
///      [_advanceToPhase], NOT from the tick loop. Guarantees one fire
///      per phase regardless of tick frequency.
class WorkoutEngine extends ChangeNotifier {
  WorkoutEngine({
    required this.config,
    required this.audio,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final WorkoutConfig config;
  final AudioService audio;
  final DateTime Function() _clock;

  /// Engine public view of the injected clock (exposed for coherent tests).
  DateTime get clockNow => _clock();

  /// When the current phase began. Useful for debug overlays and
  /// coherent-time assertions in tests.
  @visibleForTesting
  DateTime? get phaseStartedAt => _phaseStartedAt;

  /// Absolute wall time at which the current phase expires. Exposed so the
  /// UI layer (Step 3.2) can bypass state-snapshot staleness if needed.
  @visibleForTesting
  DateTime? get phaseEndsAt => _phaseEndsAt;

  // --- Cue names (mirror AudioService contract) ---
  static const String cueWoodClack = 'wood_clack';
  static const String cueBellStart = 'bell_start';
  static const String cueBellEnd = 'bell_end';
  static const String cueWhistleLong = 'whistle_long';

  /// Remaining-time threshold (ms) at which the 11s warning cue fires.
  static const int warningThresholdMs = 11000;

  // --- Owned mutable state (never exposed as setters) ---
  WorkoutPhase _phase = WorkoutPhase.preCountdown;
  int _currentRound = 0;
  DateTime? _phaseStartedAt;
  DateTime? _phaseEndsAt;
  Duration? _pausedRemaining;
  bool _isPaused = false;
  bool _isStarted = false;
  bool _disposed = false;
  final Set<int> _firedCueMsThresholds = <int>{};

  Ticker? _ticker;

  // --- Public read-only state snapshot ---
  WorkoutState get state {
    final phaseDuration = _currentPhaseDuration();
    Duration remaining;

    if (_phase == WorkoutPhase.complete) {
      remaining = Duration.zero;
    } else if (_isPaused && _pausedRemaining != null) {
      remaining = _pausedRemaining!;
    } else if (_phaseEndsAt != null) {
      final diff = _phaseEndsAt!.difference(_clock());
      remaining = diff.isNegative ? Duration.zero : diff;
    } else {
      // Pre-start: report the full phase duration so UIs that mount before
      // start() see a sensible "about to begin" snapshot.
      remaining = phaseDuration;
    }

    return WorkoutState(
      phase: _phase,
      currentRound: _currentRound,
      totalRounds: config.totalRounds,
      phaseRemaining: remaining,
      phaseDuration: phaseDuration,
      isPaused: _isPaused,
    );
  }

  // --- Public API ---

  /// Begins the workout at the preCountdown phase.
  void start() {
    if (_isStarted || _disposed) return;
    _isStarted = true;
    _phase = WorkoutPhase.preCountdown;
    _currentRound = 0;
    _isPaused = false;
    _pausedRemaining = null;
    _firedCueMsThresholds.clear();
    final now = _clock();
    _phaseStartedAt = now;
    _phaseEndsAt = now.add(config.preCountdown);
    _ticker = Ticker(_onTick)..start();
    notifyListeners();
  }

  /// Captures the current remaining time and halts the ticker.
  /// No-op if the engine is already paused, not started, or complete.
  void pause() {
    if (!_isStarted || _isPaused || _phase == WorkoutPhase.complete) return;
    if (_phaseEndsAt == null) return;
    final diff = _phaseEndsAt!.difference(_clock());
    _pausedRemaining = diff.isNegative ? Duration.zero : diff;
    _isPaused = true;
    _ticker?.stop();
    notifyListeners();
  }

  /// Recomputes [phaseEndsAt] from the paused remaining and restarts the ticker.
  void resume() {
    if (!_isStarted || !_isPaused || _phase == WorkoutPhase.complete) return;
    if (_pausedRemaining == null) return;
    final now = _clock();
    _phaseEndsAt = now.add(_pausedRemaining!);
    _phaseStartedAt = now.subtract(_currentPhaseDuration() - _pausedRemaining!);
    _pausedRemaining = null;
    _isPaused = false;
    _ticker?.start();
    notifyListeners();
  }

  /// DEV-ONLY: force-advance past the current phase.
  void skipPhase() {
    if (!_isStarted || _phase == WorkoutPhase.complete) return;
    _advanceFromCurrentPhase();
    notifyListeners();
  }

  /// Short-circuit the workout to complete.
  ///
  /// By default fires bell_end — natural completion (final work round expiry,
  /// which also routes through the complete phase) keeps the triumphant
  /// ending cue.
  ///
  /// Pass `playCompletionCue: false` when the user abandons the workout
  /// (STOP → END dialog). Abandoning is not a completion; the bell would
  /// feel celebratory and wrong.
  void endWorkout({bool playCompletionCue = true}) {
    if (_disposed || _phase == WorkoutPhase.complete) return;
    _advanceToPhase(
      WorkoutPhase.complete,
      playCompletionCue: playCompletionCue,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  /// Exposed so tests can drive the state machine deterministically against
  /// an injected clock, without waiting for real frame callbacks.
  @visibleForTesting
  void debugTick() => _pollState();

  // --- Internals ---

  Duration _currentPhaseDuration() {
    switch (_phase) {
      case WorkoutPhase.preCountdown:
        return config.preCountdown;
      case WorkoutPhase.work:
        return config.workDuration;
      case WorkoutPhase.rest:
        return config.restDuration;
      case WorkoutPhase.complete:
        return Duration.zero;
    }
  }

  void _onTick(Duration _) => _pollState();

  void _pollState() {
    if (_disposed || _isPaused) return;
    if (_phase == WorkoutPhase.complete) return;
    if (_phaseEndsAt == null) return;

    final remainingMs = _phaseEndsAt!.difference(_clock()).inMilliseconds;

    // Step 5.3 Fix 1: skip the 11s warning cue when the phase itself is
    // shorter than (or exactly at) the threshold — otherwise a short work
    // or rest round would fire wood_clack at phase entry instead of as a
    // pre-expiry warning. Guard is strict `>`, so phaseDuration == 11000ms
    // also suppresses.
    final int phaseDurationMs = _currentPhaseDuration().inMilliseconds;
    if (phaseDurationMs > warningThresholdMs &&
        remainingMs <= warningThresholdMs &&
        !_firedCueMsThresholds.contains(warningThresholdMs)) {
      _firedCueMsThresholds.add(warningThresholdMs);
      audio.play(cueWoodClack);
    }

    if (remainingMs <= 0) {
      _advanceFromCurrentPhase();
    }

    notifyListeners();
  }

  void _advanceFromCurrentPhase() {
    switch (_phase) {
      case WorkoutPhase.preCountdown:
        _advanceToPhase(WorkoutPhase.work, round: 1);
        break;
      case WorkoutPhase.work:
        // Boxing cue contract: bell_end fires at the end of every work
        // phase — both non-final (work → rest) and final (work → complete).
        // We fire it HERE on the work-exit side so user-initiated END
        // (which routes through endWorkout → _advanceToPhase(complete, …))
        // stays silent.
        audio.play(cueBellEnd);
        if (_currentRound < config.totalRounds) {
          _advanceToPhase(WorkoutPhase.rest);
        } else {
          // Final round: skip the rest phase entirely. bell_end has already
          // fired above, so suppress the complete-entry cue to avoid a
          // double bell.
          _advanceToPhase(
            WorkoutPhase.complete,
            playCompletionCue: false,
          );
        }
        break;
      case WorkoutPhase.rest:
        _advanceToPhase(WorkoutPhase.work, round: _currentRound + 1);
        break;
      case WorkoutPhase.complete:
        break;
    }
  }

  void _advanceToPhase(
    WorkoutPhase newPhase, {
    int? round,
    bool playCompletionCue = true,
  }) {
    _phase = newPhase;
    if (round != null) _currentRound = round;
    _firedCueMsThresholds.clear();

    final now = _clock();
    _phaseStartedAt = now;
    final duration = _currentPhaseDuration();
    _phaseEndsAt = duration == Duration.zero ? now : now.add(duration);

    switch (newPhase) {
      case WorkoutPhase.work:
        audio.play(cueBellStart);
        break;
      case WorkoutPhase.rest:
        // Boxing cue contract: rest-entry is SILENT. whistle_long is
        // reserved for the Smoker preset (Step 6) — the asset is still
        // preloaded by AudioService but nothing fires it on Boxing.
        break;
      case WorkoutPhase.complete:
        // [playCompletionCue] is false on two paths:
        //   (1) user-initiated END (engine.endWorkout(playCompletionCue: false))
        //   (2) natural final-round completion (bell_end already fired
        //       on the work-exit side in _advanceFromCurrentPhase)
        if (playCompletionCue) {
          audio.play(cueBellEnd);
        }
        _ticker?.stop();
        break;
      case WorkoutPhase.preCountdown:
        break;
    }
  }
}
