import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/segmented_toggle.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<Locale> _locales = [Locale('en'), Locale('es')];
  static const List<String> _labels = ['ENGLISH', 'ESPAÑOL'];

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
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'SETTINGS',
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
              const _SectionLabel(label: 'LANGUAGE'),
              const SizedBox(height: AppSpacing.md),
              SegmentedToggle(
                options: _labels,
                selectedIndex: _selectedIndex,
                onChanged: _onLanguageChanged,
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
