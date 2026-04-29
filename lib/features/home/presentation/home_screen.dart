import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../settings/presentation/settings_screen.dart';
import '../widgets/matrix_rain_background.dart';
import 'widgets/preset_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openSettings(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // Bottom layer: matrix-rain ambient background. Falling
          // "8COUNT" characters with a static bleed-through layer that
          // characters brighten when crossing. Fully behind the cards;
          // pauses on navigation away and on app backgrounding.
          const Positioned.fill(child: MatrixRainBackground()),
          // Foreground: existing home layout (header, brand, 3 cards),
          // unchanged.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const SizedBox(height: AppSpacing.md),
              _Header(
                onGearTap: () => _openSettings(context),
                tooltip: l10n.settingsTooltip,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _BrandMark(title: l10n.appTitle),
              const SizedBox(height: AppSpacing.xxl),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PresetCard(
                      title: l10n.boxingTitle,
                      subtitle: l10n.boxingMeta,
                      isLocked: false,
                      onTap: () => context.push('/timer/boxing'),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    PresetCard(
                      title: l10n.smokerTitle,
                      subtitle: l10n.smokerMeta,
                      // TODO(plumbing): gate Smoker behind Pro tier via
                      // RevenueCat. Currently free for development. See V2
                      // monetization spec. The lock pill stays on the card
                      // until paywall lands so the visual hierarchy still
                      // signals Pro intent.
                      isLocked: true,
                      onTap: () => context.push('/timer/smoker'),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    PresetCard(
                      title: l10n.customTitle,
                      subtitle: l10n.customMeta,
                      isLocked: true,
                      onTap: () {
                        // TODO(pro-gate): mirror Smoker's Pro gate once it
                        // exists. Until then, route unconditionally — Step
                        // 5 spec's documented fallback. PresetCard's own
                        // GestureDetector already fires mediumImpact.
                        context.push('/custom');
                      },
                    ),
                  ],
                ),
              ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onGearTap, required this.tooltip});

  final VoidCallback onGearTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _GearButton(onTap: onGearTap, tooltip: tooltip),
      ],
    );
  }
}

class _GearButton extends StatefulWidget {
  const _GearButton({required this.onTap, required this.tooltip});

  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_GearButton> createState() => _GearButtonState();
}

class _GearButtonState extends State<_GearButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.settings,
              size: 36,
              color: AppColors.gold,
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: AppTheme.displayFont(
        fontSize: 96,
        color: AppColors.gold,
        fontWeight: FontWeight.w700,
        letterSpacing: 3,
      ),
    );
  }
}
