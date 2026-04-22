import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eight_count/core/utils/time_format.dart';
import 'package:eight_count/generated/l10n/app_localizations.dart';

/// Terminal screen shown after a workout completes naturally. Displays the
/// brand title, the total time the user just finished, and a DONE button
/// that pops back to home via `context.go('/')` (stack replacement).
class WorkoutCompleteScreen extends StatelessWidget {
  const WorkoutCompleteScreen({
    super.key,
    required this.totalSeconds,
    required this.presetId,
  });

  final int totalSeconds;
  final String presetId;

  void _handleDone(BuildContext context) {
    HapticFeedback.lightImpact();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF000000),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.workoutCompleteTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: const Color(0xFFF5C518),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.workoutCompleteTotalLabel,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 3,
                    color: const Color(0xFF8A8A8A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatMmSs(totalSeconds),
                  style: GoogleFonts.bebasNeue(
                    fontSize: 96,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: const Color(0xFFFFFFFF),
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 48),
                _DoneButton(
                  label: l10n.doneAction,
                  onTap: () => _handleDone(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 140,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          border: Border.all(color: const Color(0xFFF5C518), width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.bebasNeue(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFF5C518),
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}
