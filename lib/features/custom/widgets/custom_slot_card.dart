import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/custom_config.dart';

/// Single-slot card on the Custom preview screen. Two visual states:
///   - SAVED: shows name + summary + total + edit pencil
///   - EMPTY: shows "Slot N — Tap to build" with a plus glyph
class CustomSlotCard extends StatelessWidget {
  const CustomSlotCard({
    super.key,
    required this.config,
    required this.onRunWorkout,
    required this.onEdit,
  });

  final CustomConfig config;
  final VoidCallback onRunWorkout;
  final VoidCallback onEdit;

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = config.isSaved;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        if (isSaved) {
          onRunWorkout();
        } else {
          onEdit();
        }
      },
      onLongPress: isSaved
          ? () {
              HapticFeedback.mediumImpact();
              onEdit();
            }
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFD4A017).withValues(
              alpha: isSaved ? 0.30 : 0.15,
            ),
            width: 1,
          ),
        ),
        child: isSaved ? _buildSaved() : _buildEmpty(),
      ),
    );
  }

  Widget _buildSaved() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.name,
                style: GoogleFonts.bebasNeue(
                  fontSize: 18,
                  color: const Color(0xFFD4A017),
                  letterSpacing: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${config.rounds} rounds · ${_formatDuration(config.workSeconds)} '
                'work · ${_formatDuration(config.restSeconds)} rest',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF8A8A8A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: ${_formatDuration(config.totalWorkoutSeconds)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFFD4A017),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: const Icon(
            LucideIcons.pencil,
            size: 18,
            color: Color(0xFFD4A017),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            onEdit();
          },
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          LucideIcons.plus,
          size: 24,
          color: Color(0xFFD4A017),
        ),
        const SizedBox(height: 8),
        Text(
          'Slot ${config.slotIndex + 1} — Tap to build',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF8A8A8A),
          ),
        ),
      ],
    );
  }
}
