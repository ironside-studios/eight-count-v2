import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router/app_router.dart';
import 'core/services/audio_service.dart';
import 'core/services/locale_service.dart';
import 'core/theme/app_theme.dart';
import 'generated/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlay);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await localeService.loadFromPrefs();

  // Preload all four audio cue players before the UI goes live — cold-load
  // latency on the first play() would wreck cue accuracy during a workout.
  final audioService = AudioService();
  await audioService.init();

  runApp(EightCountApp(audioService: audioService));
}

class EightCountApp extends StatelessWidget {
  const EightCountApp({super.key, required this.audioService});

  final AudioService audioService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: localeService,
      builder: (context, _) => MaterialApp.router(
        title: '8 Count',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: localeService.current,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: appRouter,
      ),
    );
  }
}
