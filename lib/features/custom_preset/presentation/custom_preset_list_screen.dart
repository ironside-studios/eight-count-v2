import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/time_format.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../domain/custom_preset.dart';
import 'custom_preset_controller.dart';

class CustomPresetListScreen extends StatefulWidget {
  const CustomPresetListScreen({super.key});

  @override
  State<CustomPresetListScreen> createState() => _CustomPresetListScreenState();
}

class _CustomPresetListScreenState extends State<CustomPresetListScreen> {
  @override
  void initState() {
    super.initState();
    // Fire once on mount; the controller de-dupes on repeated calls.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      customPresetController.loadPresets();
    });
  }

  void _onCreateTap(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push('/custom/edit');
  }

  void _onPresetTap(BuildContext context, CustomPreset preset) {
    HapticFeedback.lightImpact();
    // Step 5 defers the timer launch wiring — TimerScreen is locked at
    // Step 3.2.2 and only accepts presetId == 'boxing' today. Running a
    // CustomPreset end-to-end lands in Step 5.1 once the screen unlocks.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Running custom presets lands when TimerScreen unlocks '
          '(preset: ${preset.name})',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onPresetLongPress(
    BuildContext context,
    CustomPreset preset,
  ) async {
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context)!;
    final choice = await showModalBottomSheet<_PresetAction>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(LucideIcons.pencil,
                  color: const Color(0xFFF5C518)),
              title: Text(
                l10n.edit,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop(_PresetAction.edit),
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2,
                  color: const Color(0xFFDC2626)),
              title: Text(
                l10n.delete,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFFDC2626),
                ),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_PresetAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;

    switch (choice) {
      case _PresetAction.edit:
        context.push('/custom/edit', extra: preset);
        break;
      case _PresetAction.delete:
        await _confirmAndDelete(context, preset);
        break;
    }
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    CustomPreset preset,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x1AF5C518), width: 1),
        ),
        title: Text(
          l10n.deleteConfirmTitle,
          style: GoogleFonts.bebasNeue(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFFFFFFF),
            letterSpacing: 2,
          ),
        ),
        content: Text(
          l10n.deleteConfirmBody,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFF8A8A8A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.cancel,
              style: GoogleFonts.bebasNeue(
                fontSize: 18,
                color: const Color(0xFF8A8A8A),
                letterSpacing: 2,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.delete,
              style: GoogleFonts.bebasNeue(
                fontSize: 18,
                color: const Color(0xFFDC2626),
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      await customPresetController.deletePreset(preset.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft,
              color: const Color(0xFFF5C518), size: 24),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            l10n.customWorkouts,
            style: GoogleFonts.bebasNeue(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF5C518),
              letterSpacing: 3,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: customPresetController,
          builder: (context, _) {
            if (customPresetController.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF5C518),
                ),
              );
            }
            final presets = customPresetController.presets;
            if (presets.isEmpty) {
              return _EmptyState(
                onCreateTap: () => _onCreateTap(context),
              );
            }
            final canCreate = customPresetController.canCreateNew;
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: presets.length + (canCreate ? 1 : 0),
              itemBuilder: (listContext, index) {
                if (index < presets.length) {
                  final preset = presets[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PresetRow(
                      preset: preset,
                      onTap: () => _onPresetTap(context, preset),
                      onLongPress: () => _onPresetLongPress(context, preset),
                    ),
                  );
                }
                return _CreateRow(onTap: () => _onCreateTap(context));
              },
            );
          },
        ),
      ),
    );
  }
}

enum _PresetAction { edit, delete }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Step 5.1 Fix 1: icon removed — pure typographic empty state. Column
    // is vertically centered by the outer Center widget; the header reads
    // as the dominant element without the gold-bordered square.
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.noWorkoutsYet,
              textAlign: TextAlign.center,
              style: GoogleFonts.bebasNeue(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFFFFF),
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.createFirstWorkoutCta,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF8A8A8A),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            _PrimaryCtaButton(
              label: l10n.createWorkout,
              onTap: onCreateTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetRow extends StatefulWidget {
  const _PresetRow({
    required this.preset,
    required this.onTap,
    required this.onLongPress,
  });

  final CustomPreset preset;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_PresetRow> createState() => _PresetRowState();
}

class _PresetRowState extends State<_PresetRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.preset;
    final summary =
        '${p.rounds} rounds  ·  ${formatMmSs(p.workSeconds)} work  ·  ${formatMmSs(p.restSeconds)} rest';
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _pressed
              ? const Color(0xFF1C1C1C)
              : const Color(0xFF141414),
          border: Border.all(color: const Color(0xFF1F1F1F), width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    p.name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFFFFF),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF8A8A8A),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight,
                color: const Color(0xFF8A8A8A), size: 20),
          ],
        ),
      ),
    );
  }
}

class _CreateRow extends StatefulWidget {
  const _CreateRow({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CreateRow> createState() => _CreateRowState();
}

class _CreateRowState extends State<_CreateRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: const Color(0xFFF5C518),
            strokeWidth: 1,
            radius: 14,
            dashLength: 8,
            gapLength: 6,
          ),
          child: Container(
            height: 96,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.plus,
                    size: 32, color: const Color(0xFFF5C518)),
                const SizedBox(width: 8),
                Text(
                  l10n.createWorkout,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF5C518),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryCtaButton extends StatefulWidget {
  const _PrimaryCtaButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_PrimaryCtaButton> createState() => _PrimaryCtaButtonState();
}

class _PrimaryCtaButtonState extends State<_PrimaryCtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: const Color(0xFFF5C518),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: GoogleFonts.bebasNeue(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF000000),
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded-rect dashed border. Flutter doesn't ship one, so a small painter
/// draws dashes along each side manually. Corner radius is honored by
/// drawing a dashed arc on each of the four corners.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        final seg = metric.extractPath(distance, end);
        canvas.drawPath(seg, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}
