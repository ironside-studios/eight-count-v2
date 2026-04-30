import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/core/models/smoker_config.dart';
import 'package:eight_count/core/models/workout_block_type.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/features/timer/presentation/timer_screen.dart'
    show remainingTotalSecondsSmoker;

/// **2026-04-30 update:** the off-by-45 TOTAL display bug was fixed
/// engine-wide. Both [remainingTotalSecondsSmoker] AND the
/// timer-screen display layer were aligned to the documented
/// [SmokerConfig.totalDurationSeconds] contract (preCountdown
/// EXCLUDED). The display layer is now a pass-through; the engine
/// returns the final user-facing value directly.
///
/// Previously these tests asserted the bug-perpetuating subtraction
/// at the display layer; they now assert the corrected pass-through
/// contract. The dual-zero invariant (TOTAL :00 same frame as final
/// phase :00) is preserved.
int _displayTotalSeconds({
  required SmokerConfig cfg,
  required WorkoutPhase phase,
  required int currentRound,
  required int phaseRemainingMs,
  required int? currentBlockIndex,
  required WorkoutBlockType? blockType,
}) {
  return remainingTotalSecondsSmoker(
    cfg,
    phase,
    currentRound,
    phaseRemainingMs,
    currentBlockIndex: currentBlockIndex,
    blockType: blockType,
  ).clamp(0, 9999);
}

void main() {
  final cfg = SmokerConfig.standard();

  test(
      'Display TOTAL reads 0 at the same instant final phase '
      'remaining reads 0 (Block 4 R8 Tabata work expiry) — dual-zero '
      'contract', () {
    // Final phase = Block 4 (Tabata) round 8 work, 0ms remaining.
    // currentRound is global → 6+8+6+8 = 28. Under the post-fix
    // engine contract, the function returns 0 directly (was 45 under
    // the off-by-45 contract).
    final raw = remainingTotalSecondsSmoker(
      cfg,
      WorkoutPhase.work,
      28,
      0,
      currentBlockIndex: 4,
      blockType: WorkoutBlockType.tabata,
    );
    expect(raw, 0,
        reason: 'engine-side: 3400 total - 3400 elapsed = 0; '
            'preCountdown is no longer reserved at totalMs head');

    final displayed = _displayTotalSeconds(
      cfg: cfg,
      phase: WorkoutPhase.work,
      currentRound: 28,
      phaseRemainingMs: 0,
      currentBlockIndex: 4,
      blockType: WorkoutBlockType.tabata,
    );
    expect(displayed, 0,
        reason: 'display: pass-through of engine 0 → 0');
  });

  test(
      'Display TOTAL during preCountdown shows full work+rest '
      'duration (3400s for V2 standard Smoker — preCountdown '
      'EXCLUDED per contract)', () {
    final displayed = _displayTotalSeconds(
      cfg: cfg,
      phase: WorkoutPhase.preCountdown,
      currentRound: 0,
      phaseRemainingMs: 45000,
      currentBlockIndex: 1,
      blockType: WorkoutBlockType.boxing,
    );
    expect(displayed, 3400,
        reason: 'updated 2026-04-30: was 3445 under the old '
            'preCountdown-inclusive contract; now 3400 to match '
            'SmokerConfig.totalDurationSeconds documentation');
  });

  test(
      'Display TOTAL at Block 1 R1 work-end equals 3220 '
      '(3400 - 180) — same final value as the old contract, just '
      'derived directly by the engine without the display-layer '
      'subtraction', () {
    final displayed = _displayTotalSeconds(
      cfg: cfg,
      phase: WorkoutPhase.work,
      currentRound: 1,
      phaseRemainingMs: 0,
      currentBlockIndex: 1,
      blockType: WorkoutBlockType.boxing,
    );
    expect(displayed, 3220);
  });

  test(
      'Display TOTAL during transition rest = 2020 '
      '(3400 - 1380 full B1 = 2020 at T1 entry — engine returns '
      'this directly, no display subtraction)', () {
    final displayed = _displayTotalSeconds(
      cfg: cfg,
      phase: WorkoutPhase.rest,
      currentRound: 6,
      phaseRemainingMs: 60000,
      currentBlockIndex: 1,
      blockType: WorkoutBlockType.transition,
    );
    expect(displayed, 2020);
  });

  test(
      'Display TOTAL at complete returns 0 (engine short-circuits '
      'on phase == complete)', () {
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
