import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/segmented_toggle.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../video/presentation/video_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<Locale> _locales = [Locale('en'), Locale('es')];

  int get _selectedIndex {
    final code = localeService.current.languageCode;
    final idx = _locales.indexWhere((l) => l.languageCode == code);
    return idx >= 0 ? idx : 0;
  }

  Future<void> _onLanguageChanged(int index) async {
    HapticFeedback.selectionClick();
    await localeService.setLocale(_locales[index]);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: AppColors.gold,
            size: 24,
          ),
          tooltip: l10n.backTooltip,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          l10n.settingsTitle,
          style: AppTheme.displayFont(
            fontSize: 24,
            color: AppColors.gold,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.base,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionLabel(label: l10n.languageLabel),
              const SizedBox(height: AppSpacing.md),
              SegmentedToggle(
                options: [l10n.englishOption, l10n.espanolOption],
                selectedIndex: _selectedIndex,
                onChanged: _onLanguageChanged,
              ),
              const SizedBox(height: AppSpacing.xl),
              _SettingsListEntry(
                label: l10n.videoSettingsListEntry,
                icon: LucideIcons.video,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const VideoSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 3,
        fontWeight: FontWeight.w600,
        color: AppColors.greyMuted,
      ),
    );
  }
}

class _SettingsListEntry extends StatelessWidget {
  const _SettingsListEntry({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderGold, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTheme.displayFont(
                  fontSize: 18,
                  color: AppColors.white,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: AppColors.greyMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
