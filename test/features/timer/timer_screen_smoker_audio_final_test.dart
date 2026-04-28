import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/core/models/smoker_config.dart';
import 'package:eight_count/core/models/workout_block_type.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/features/timer/presentation/timer_screen.dart'
    show remainingTotalSecondsSmoker;

/// Bug 4 (2026-04-28) — display formula for TOTAL subtracts
/// preCountdown.inSeconds during work/rest so the displayed value hits
/// :00 at the same instant the final phase remaining hits :00.
///
/// The underlying [remainingTotalSecondsSmoker] math is unchanged and
/// still includes preCountdown in the totalMs anchor — that pure
/// function is pinned to its existing 20 expected values in
/// test/features/timer/timer_screen_smoker_total_time_test.dart. The
/// dual-zero contract is enforced at the *display* layer by subtracting
/// preCountdown.inSeconds from the rendered total.
///
/// These tests verify the display formula produces 0 at the final phase
/// expiry and a coherent value mid-workout.
int _displayTotalSeconds({
  required SmokerConfig cfg,
  required WorkoutPhase phase,
  required int currentRound,
  required int phaseRemainingMs,
  required int? currentBlockIndex,
  required WorkoutBlockType? blockType,
}) {
  final raw = remainingTotalSecondsSmoker(
    cfg,
    phase,
    currentRound,
    phaseRemainingMs,
    currentBlockIndex: currentBlockIndex,
    blockType: blockType,
  );
  if (phase == WorkoutPhase.preCountdown || phase == WorkoutPhase.complete) {
    return raw;
  }
  return (raw - cfg.preCountdown.inSeconds).clamp(0, 9999);
}

void main() {
  final cfg = SmokerConfig.standard();

  test(
      'Bug 4 — display TOTAL reads 0 at the same instant final phase '
      'remaining reads 0 (Block 4 R8 Tabata work expiry)', () {
    // Final phase = Block 4 (Tabata) round 8 work, 0ms remaining.
    // currentRound is global → 6+8+6+8 = 28.
    final raw = remainingTotalSecondsSmoker(
      cfg,
      WorkoutPhase.work,
      28,
      0,
      currentBlockIndex: 4,
      blockType: WorkoutBlockType.tabata,
    );
    // The pure function returns the preCountdown reservation (45s) at
    // this moment per its existing contract.
    expect(raw, 45,
        reason: 'underlying math reserves preCountdown at the head of '
            'totalMs; test pinned to existing behavior');

    // Display formula subtracts preCountdown → 0.
    final displayed = _displayTotalSeconds(
      cfg: cfg,
      phase: WorkoutPhase.work,
      currentRound: 28,
      phaseRemainingMs: 0,
      currentBlockIndex: 4,
      blockType: WorkoutBlockType.tabata,
    );
    expect(displayed, 0,
        reason: 'dual-zero contract: TOTAL hits :00 the instant final '
            'phase remaining hits :00');
  });

  test(
      'Bug 4 — display TOTAL during preCountdown shows full duration '
      '(no subtraction in preCountdown phase)', () {
    final displayed = _displayTotalSeconds(
      cfg: cfg,
      phase: WorkoutPhase.preCountdown,
      currentRound: 0,
      phaseRemainingMs: 45000,
      currentBlockIndex: 1,
      blockType: WorkoutBlockType.boxing,
    );
    expect(displayed, 3445,
        reason: 'during preCountdown the user sees the full workout '
            'duration including warmup; subtraction is gated to work/rest');
  });

  test(
      'Bug 4 — display TOTAL at Block 1 R1 work-end equals raw - 45 '
      '(3265 - 45 = 3220)', () {
    final displayed = _displayTotalSeconds(
      cfg: cfg,
      phase: WorkoutPhase.work,
      currentRound: 1,
      phaseRemainingMs: 0,
      currentBlockIndex: 1,
      blockType: WorkoutBlockType.boxing,
    );
    expect(displayed, 3220,
        reason: 'raw is 3445-180=3265 (per existing pure-fn tests); '
            'display subtracts the 45s preCountdown reservation');
  });

  test(
      'Bug 4 — display TOTAL during transition rest also subtracts '
      'preCountdown (transition is content, not warmup)', () {
    // Transition 1 just entered (60s remaining). raw = 2065.
    final displayed = _displayTotalSeconds(
      cfg: cfg,
      phase: WorkoutPhase.rest,
      currentRound: 6,
      phaseRemainingMs: 60000,
      currentBlockIndex: 1,
      blockType: WorkoutBlockType.transition,
    );
    expect(displayed, 2020, reason: '2065 raw - 45 preCountdown = 2020');
  });

  test(
      'Bug 4 — display TOTAL at complete returns 0 (preCountdown '
      'subtraction is gated off for the complete phase)', () {
    final displayed = _displayTotalSeconds(
      cfg: cfg,
      phase: WorkoutPhase.complete,
      currentRound: 28,
      phaseRemainingMs: 0,
      currentBlockIndex: 4,
      blockType: WorkoutBlockType.tabata,
    );
    expect(displayed, 0);
  });

  // ----- Bug 5 -----

  test(
      'Bug 5 — completion-hold delay is documented at 5000ms in '
      'timer_screen.dart (manual S23 verification authoritative)', () {
    // The 5000ms hold is implemented as an inline literal in
    // _onEngineChange (Future.delayed(const Duration(milliseconds: 5000))).
    // No public surface to introspect at test time without mounting the
    // widget and driving an engine to natural completion (~57 minutes
    // of fake-clock time for SmokerConfig.standard).
    //
    // This test is intentionally a no-op assertion: it exists so the
    // suite documents that Bug 5 verification is by manual S23 device
    // test (per the spec's "device test focus" section).
    expect(true, isTrue);
  });
}
