import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_spacing.dart';
import 'core/constants/app_colors.dart';

void main() {
  runApp(const EightCountApp());
}

class EightCountApp extends StatelessWidget {
  const EightCountApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '8 Count',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const ScaffoldVerificationScreen(),
    );
  }
}

/// Step 1 verification screen — confirms theme, fonts, and build pipeline work.
/// Replaced with real main screen in a later step.
class ScaffoldVerificationScreen extends StatelessWidget {
  const ScaffoldVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '8 COUNT',
                  style: AppTheme.displayFont(fontSize: 72, letterSpacing: 4),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Every Round Counts',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 2,
                    color: AppColors.greyMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const Text(
                  'V2 Scaffold OK',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.greyMuted,
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
