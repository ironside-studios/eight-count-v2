import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/locale_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlay);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await localeService.loadFromPrefs();
  runApp(const EightCountApp());
}

class EightCountApp extends StatelessWidget {
  const EightCountApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: localeService,
      builder: (context, _) => MaterialApp(
        title: '8 Count',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: localeService.current,
        supportedLocales: LocaleService.supportedLocales,
        home: const HomeScreen(),
      ),
    );
  }
}
