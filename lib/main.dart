import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';

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
      home: const HomeScreen(),
    );
  }
}
