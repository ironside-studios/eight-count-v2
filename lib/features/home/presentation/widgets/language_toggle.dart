import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// EN / ES pill toggle — visual only for now.
/// Real localization wiring happens in a later step.
class LanguageToggle extends StatefulWidget {
  const LanguageToggle({
    super.key,
    required this.onChanged,
  });

  final ValueChanged<String> onChanged;

  @override
  State<LanguageToggle> createState() => _LanguageToggleState();
}

class _LanguageToggleState extends State<LanguageToggle> {
  String _selected = 'EN';

  void _select(String lang) {
    if (_selected == lang) return;
    setState(() => _selected = lang);
    widget.onChanged(lang);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangOption(
            label: 'EN',
            isSelected: _selected == 'EN',
            onTap: () => _select('EN'),
          ),
          _LangOption(
            label: 'ES',
            isSelected: _selected == 'ES',
            onTap: () => _select('ES'),
          ),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.goldTuned : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTheme.displayFont(
            fontSize: 14,
            color: isSelected ? AppColors.black : AppColors.greyMuted,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
