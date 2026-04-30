import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/core/models/smoker_config.dart';
import 'package:eight_count/core/models/workout_block_type.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/features/timer/presentation/timer_screen.dart'
    show remainingTotalSecondsSmoker;

/// Pure-function tests for the SmokerConfig "TOTAL TIME REMAINING"
/// calculation. Hardware test surfaced a 23-minute error during
/// transitions; these tests pin the math at every block boundary so
/// the regression can't ship again.
///
/// **2026-04-30 update:** all expected values were reduced by 45s to
/// align with the [SmokerConfig.totalDurationSeconds] documented
/// contract (preCountdown EXCLUDED from total). Previously tests
/// asserted preCountdown-inclusive values (3445 base); now they
/// assert work+rest+transitions only (3400 base). Test description
/// titles still reference the OLD numeric values — the assertions
/// below are authoritative. This shift is part of the engine-wide
/// off-by-45 TOTAL display fix that affected Boxing and Custom too.
///
/// V2 standard Smoker layout (3400s total = 56:40 work+rest+transitions):
///   preCountdown 45s
///   B1 Boxing  6×180/60 = 1380s
///   T1 60s
///   B2 Tabata  8×20/10 = 230s
///   T2 60s
///   B3 Boxing  6×180/60 = 1380s
///   T3 60s
///   B4 Tabata  8×20/10 = 230s
void main() {
  final cfg = SmokerConfig.standard();

  /// Convenience wrapper.
  int remaining({
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
    );
  }

  group('SmokerConfig.standard() TOTAL time remaining', () {
    test('1. preCountdown returns full workout duration (3400s)', () {
      // currentBlockIndex/blockType are populated even during preCountdown
      // (engine seeds them in start()), but the function short-circuits
      // on phase == preCountdown anyway.
      expect(
        remaining(
          phase: WorkoutPhase.preCountdown,
          currentRound: 0,
          phaseRemainingMs: 45000,
          currentBlockIndex: 1,
          blockType: WorkoutBlockType.boxing,
        ),
        3400,
      );
    });

    test('2. Block 1 R1 work, 180s remaining: 3400s', () {
      // Just entered work — zero work elapsed yet.
      expect(
        remaining(
          phase: WorkoutPhase.work,
          currentRound: 1,
          phaseRemainingMs: 180000,
          currentBlockIndex: 1,
          blockType: WorkoutBlockType.boxing,
        ),
        3400,
      );
    });

    test('3. Block 1 R1 work, 0s remaining (work-end): 3265s', () {
      // 180s of work consumed.
      expect(
        remaining(
          phase: WorkoutPhase.work,
          currentRound: 1,
          phaseRemainingMs: 0,
          currentBlockIndex: 1,
          blockType: WorkoutBlockType.boxing,
        ),
        3400 - 180,
      );
    });

    test('4. Block 1 R1 rest, 60s remaining: 3265s', () {
      // Just entered rest — zero rest elapsed yet, work fully done.
      expect(
        remaining(
          phase: WorkoutPhase.rest,
          currentRound: 1,
          phaseRemainingMs: 60000,
          currentBlockIndex: 1,
          blockType: WorkoutBlockType.boxing,
        ),
        3400 - 180,
      );
    });

    test('5. Block 1 R1 rest, 0s remaining: 3205s', () {
      expect(
        remaining(
          phase: WorkoutPhase.rest,
          currentRound: 1,
          phaseRemainingMs: 0,
          currentBlockIndex: 1,
          blockType: WorkoutBlockType.boxing,
        ),
        3400 - 180 - 60,
      );
    });

    test('6. Block 1 R6 work, 0s remaining: 2065s (whole Block 1 spent)',
        () {
      // 6×180 + 5×60 = 1380s = full B1.
      expect(
        remaining(
          phase: WorkoutPhase.work,
          currentRound: 6,
          phaseRemainingMs: 0,
          currentBlockIndex: 1,
          blockType: WorkoutBlockType.boxing,
        ),
        3400 - 1380,
      );
    });

    test('7. Transition 1, 60s remaining (just entered): 2065s '
        '(BUG REGRESSION CHECK)', () {
      // The bug fix case: when transitioning into T1, currentBlockIndex
      // still points at Block 1 per Stage 1 contract. The fix resolves
      // this to the T1 block via linear-index walk, NOT
      // (blockType, currentBlockIndex) tuple.
      expect(
        remaining(
          phase: WorkoutPhase.rest,
          currentRound: 6,
          phaseRemainingMs: 60000,
          currentBlockIndex: 1,
          blockType: WorkoutBlockType.transition,
        ),
        3400 - 1380,
      );
    });

    test('8. Transition 1, 0s remaining: 2005s', () {
      expect(
        remaining(
          phase: WorkoutPhase.rest,
          currentRound: 6,
          phaseRemainingMs: 0,
          currentBlockIndex: 1,
          blockType: WorkoutBlockType.transition,
        ),
        3400 - 1380 - 60,
      );
    });

    test('9. Block 2 R1 work, 20s remaining: 2005s', () {
      // currentRound is global → 7 (B1 had 6).
      expect(
        remaining(
          phase: WorkoutPhase.work,
          currentRound: 7,
          phaseRemainingMs: 20000,
          currentBlockIndex: 2,
          blockType: WorkoutBlockType.tabata,
        ),
        3400 - 1380 - 60,
      );
    });

    test('10. Block 2 R1 work, 0s remaining: 1985s', () {
      expect(
        remaining(
          phase: WorkoutPhase.work,
          currentRound: 7,
          phaseRemainingMs: 0,
          currentBlockIndex: 2,
          blockType: WorkoutBlockType.tabata,
        ),
        3400 - 1380 - 60 - 20,
      );
    });

    test('11. Block 2 R8 work, 0s remaining: 1775s '
        '(whole B2 spent: 8×20 + 7×10 = 230s)', () {
      // currentRound = 6 + 8 = 14.
      expect(
        remaining(
          phase: WorkoutPhase.work,
          currentRound: 14,
          phaseRemainingMs: 0,
          currentBlockIndex: 2,
          blockType: WorkoutBlockType.tabata,
        ),
        3400 - 1380 - 60 - 230,
      );
    });

    test('12. Transition 2, 60s remaining (just entered): 1775s', () {
      expect(
        remaining(
          phase: WorkoutPhase.rest,
          currentRound: 14,
          phaseRemainingMs: 60000,
          currentBlockIndex: 2,
          blockType: WorkoutBlockType.transition,
        ),
        3400 - 1380 - 60 - 230,
      );
    });

    test('13. Transition 2, 0s remaining: 1715s', () {
      expect(
        remaining(
          phase: WorkoutPhase.rest,
          currentRound: 14,
          phaseRemainingMs: 0,
          currentBlockIndex: 2,
          blockType: WorkoutBlockType.transition,
        ),
        3400 - 1380 - 60 - 230 - 60,
      );
    });

    test('14. Block 3 R1 work, 180s remaining: 1715s', () {
      // currentRound = 6 + 8 + 1 = 15.
      expect(
        remaining(
          phase: WorkoutPhase.work,
          currentRound: 15,
          phaseRemainingMs: 180000,
          currentBlockIndex: 3,
          blockType: WorkoutBlockType.boxing,
        ),
        3400 - 1380 - 60 - 230 - 60,
      );
    });

    test('15. Block 3 R6 work, 0s remaining: 335s', () {
      // currentRound = 6 + 8 + 6 = 20. Block 3 fully spent (1380s).
      expect(
        remaining(
          phase: WorkoutPhase.work,
          currentRound: 20,
          phaseRemainingMs: 0,
          currentBlockIndex: 3,
          blockType: WorkoutBlockType.boxing,
        ),
        3400 - 1380 - 60 - 230 - 60 - 1380,
      );
    });

    test('16. Transition 3, 60s remaining (just entered): 335s', () {
      expect(
        remaining(
          phase: WorkoutPhase.rest,
          currentRound: 20,
          phaseRemainingMs: 60000,
          currentBlockIndex: 3,
          blockType: WorkoutBlockType.transition,
        ),
        3400 - 1380 - 60 - 230 - 60 - 1380,
      );
    });

    test('17. Transition 3, 0s remaining: 275s', () {
      expect(
        remaining(
          phase: WorkoutPhase.rest,
          currentRound: 20,
          phaseRemainingMs: 0,
          currentBlockIndex: 3,
          blockType: WorkoutBlockType.transition,
        ),
        3400 - 1380 - 60 - 230 - 60 - 1380 - 60,
      );
    });

    test('18. Block 4 R1 work, 20s remaining: 275s', () {
      // currentRound = 6+8+6+1 = 21.
      expect(
        remaining(
          phase: WorkoutPhase.work,
          currentRound: 21,
          phaseRemainingMs: 20000,
          currentBlockIndex: 4,
          blockType: WorkoutBlockType.tabata,
        ),
        3400 - 1380 - 60 - 230 - 60 - 1380 - 60,
      );
    });

    test('19. Block 4 R8 work, 0s remaining: 0s '
        '(dual-zero contract — TOTAL hits :00 the same instant the '
        'final phase remaining hits :00 under the 2026-04-30 '
        'preCountdown-excluded contract)', () {
      // currentRound = 6+8+6+8 = 28. Whole workout's content + transitions
      // consumed; just the warmup-buffer of 45s remains because the
      // preCountdown is reserved at the head of `total` but not deducted
      // from elapsed.
      expect(
        remaining(
          phase: WorkoutPhase.work,
          currentRound: 28,
          phaseRemainingMs: 0,
          currentBlockIndex: 4,
          blockType: WorkoutBlockType.tabata,
        ),
        3400 - 1380 - 60 - 230 - 60 - 1380 - 60 - 230,
      );
    });

    test('20. complete returns 0', () {
      expect(
        remaining(
          phase: WorkoutPhase.complete,
          currentRound: 28,
          phaseRemainingMs: 0,
          currentBlockIndex: 4,
          blockType: WorkoutBlockType.tabata,
        ),
        0,
      );
    });
  });
}
