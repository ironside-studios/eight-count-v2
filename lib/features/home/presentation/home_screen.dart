import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/presentation/settings_screen.dart';
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
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              _Header(onGearTap: () => _openSettings(context)),
              const SizedBox(height: AppSpacing.xxl),
              const _BrandMark(),
              const SizedBox(height: AppSpacing.xxl),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PresetCard(
                      title: 'BOXING',
                      subtitle: '12 rounds  ·  3:00 work  ·  1:00 rest',
                      isLocked: false,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        // Boxing timer screen — wired in a later step
                      },
                    ),
                    const SizedBox(height: AppSpacing.base),
                    PresetCard(
                      title: 'SMOKER',
                      subtitle: 'HIIT composite  ·  boxing + burnout',
                      isLocked: true,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        // Paywall — wired in a later step
                      },
                    ),
                    const SizedBox(height: AppSpacing.base),
                    PresetCard(
                      title: 'CUSTOM',
                      subtitle: 'Build your own  ·  3 saved slots',
                      isLocked: true,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        // Paywall — wired in a later step
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onGearTap});

  final VoidCallback onGearTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _GearButton(onTap: onGearTap),
      ],
    );
  }
}

class _GearButton extends StatefulWidget {
  const _GearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_GearButton> createState() => _GearButtonState();
}

class _GearButtonState extends State<_GearButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Text(
      '8 COUNT',
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
