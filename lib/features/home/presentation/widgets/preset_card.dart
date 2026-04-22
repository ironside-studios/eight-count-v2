import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../generated/l10n/app_localizations.dart';

/// Preset card — the core brand unit of the main screen.
/// Gold left-edge bar = boxing belt stripe / earned status.
/// Locked cards show PRO pill + lock icon but remain tappable (for future paywall).
class PresetCard extends StatefulWidget {
  const PresetCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isLocked,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  State<PresetCard> createState() => _PresetCardState();
}

class _PresetCardState extends State<PresetCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.surfaceCardPressed : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.borderGold,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gold accent bar — the belt stripe
                  Container(
                    width: 4,
                    color: AppColors.goldTuned,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: widget.isLocked
                                            ? AppTheme.goldLetterpress(
                                                fontSize: 32,
                                                letterSpacing: 2,
                                              )
                                            : AppTheme.displayFont(
                                                fontSize: 32,
                                                color: AppColors.white,
                                                letterSpacing: 2,
                                              ),
                                      ),
                                    ),
                                    if (widget.isLocked) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      Icon(
                                        LucideIcons.lock,
                                        size: 18,
                                        color: AppColors.goldTuned,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  widget.subtitle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.greyMuted,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.isLocked) const _ProPill(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProPill extends StatelessWidget {
  const _ProPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.goldTuned,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        AppLocalizations.of(context)!.proBadge,
        style: AppTheme.displayFont(
          fontSize: 12,
          color: AppColors.black,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
