import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'core/router/app_router.dart';
import 'core/services/audio_service.dart';
import 'core/services/locale_service.dart';
import 'core/theme/app_theme.dart';
import 'features/custom/services/custom_preset_service.dart';
import 'generated/l10n/app_localizations.dart';

/// App-wide AudioService singleton. Lazy-initialised on first access and
/// wired up (asset preload) inside [main] before the UI mounts. TimerScreen
/// and anything else that needs cue playback imports this directly, same
/// pattern as [localeService].
final AudioService audioService = AudioService.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlay);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await localeService.loadFromPrefs();

  // Preload all four audio cue players before the UI goes live — cold-load
  // latency on the first play() would wreck cue accuracy during a workout.
  await audioService.init();

  // Hydrate the Custom-preset slot cache from shared_preferences before the
  // UI mounts so the home screen never sees an unloaded slot list.
  await CustomPresetService.instance.init();

  runApp(EightCountApp(audioService: audioService));
}

class EightCountApp extends StatefulWidget {
  const EightCountApp({super.key, required this.audioService});

  final AudioService audioService;

  @override
  State<EightCountApp> createState() => _EightCountAppState();
}

class _EightCountAppState extends State<EightCountApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Stage 2.2G Issue C: app-wide wakelock. Screen stays lit while
    // the app is foregrounded — every screen, paused or running.
    // Toggled via [didChangeAppLifecycleState] on background/foreground
    // transitions; released in [dispose] on app teardown.
    unawaited(WakelockPlus.enable());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App back in foreground — re-enable wakelock.
        unawaited(WakelockPlus.enable());
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Genuine backgrounding (paused) or teardown (detached) —
        // release wakelock so OS can manage screen normally.
        unawaited(WakelockPlus.disable());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Stage 2.2H Issue D: ignore inactive + hidden.
        // On Samsung devices, tapping a button with haptic feedback
        // triggers a brief inactive event during haptic + ripple
        // animation processing. Treating that as "background" was
        // disabling wakelock and dimming the screen on every in-app
        // PAUSE button tap. Both inactive and hidden are micro-events
        // / OS hint signals, not real backgrounding — ignore them.
        break;
    }
  }

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
