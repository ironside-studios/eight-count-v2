import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eight_count/core/constants/app_colors.dart';
import 'package:eight_count/core/models/workout_block_type.dart';
import 'package:eight_count/generated/l10n/app_localizations.dart';

/// "BLOCK 2 OF 4 — TABATA" / "TRANSITION → BLOCK 3" header for Smoker
/// workouts. Renders nothing for non-Smoker presets (when [currentBlockIndex]
/// or [blockType] is null).
///
/// Inputs are simple primitives so the widget is testable without an engine
/// or live config — pump it directly with values from `engine.state`.
class BlockLabel extends StatelessWidget {
  const BlockLabel({
    super.key,
    required this.currentBlockIndex,
    required this.blockType,
    required this.totalContentBlocks,
  });

  /// 1-indexed CONTENT-block number (1..N), or null for non-Smoker presets.
  /// During a transition this is the most-recently-completed content block.
  final int? currentBlockIndex;

  /// Block type for the current period; null for non-Smoker presets.
  final WorkoutBlockType? blockType;

  /// Total number of CONTENT blocks in the workout (4 for V2 standard
  /// Smoker). Used to render "OF N" / next-index math.
  final int totalContentBlocks;

  @override
  Widget build(BuildContext context) {
    if (currentBlockIndex == null || blockType == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;

    if (blockType == WorkoutBlockType.transition) {
      final int nextIndex = currentBlockIndex! + 1;
      return Text(
        l10n.smokerTransitionLabel(nextIndex.toString()),
        textAlign: TextAlign.center,
        style: GoogleFonts.bebasNeue(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.gold,
          letterSpacing: 3,
        ),
      );
    }

    final String typeLabel = blockType == WorkoutBlockType.boxing
        ? l10n.smokerBlockTypeBoxing
        : l10n.smokerBlockTypeTabata;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.smokerBlockLabel(
            currentBlockIndex.toString(),
            totalContentBlocks.toString(),
          ),
          textAlign: TextAlign.center,
          style: GoogleFonts.bebasNeue(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.gold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          typeLabel,
          textAlign: TextAlign.center,
          style: GoogleFonts.bebasNeue(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.gold,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}
