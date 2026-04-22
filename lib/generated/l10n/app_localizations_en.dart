// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => '8 COUNT';

  @override
  String get boxingTitle => 'BOXING';

  @override
  String get boxingMeta => '12 rounds · 3:00 work · 1:00 rest';

  @override
  String get smokerTitle => 'SMOKER';

  @override
  String get smokerMeta => 'HIIT composite · boxing + burnout';

  @override
  String get customTitle => 'CUSTOM';

  @override
  String get customMeta => 'Build your own · 3 saved slots';

  @override
  String get proBadge => 'PRO';

  @override
  String get settingsTitle => 'SETTINGS';

  @override
  String get languageLabel => 'LANGUAGE';

  @override
  String get englishOption => 'ENGLISH';

  @override
  String get espanolOption => 'ESPAÑOL';

  @override
  String get backTooltip => 'Back';

  @override
  String get settingsTooltip => 'Open settings';

  @override
  String get phaseGetReady => 'GET READY';

  @override
  String get phaseWork => 'WORK';

  @override
  String get phaseRest => 'REST';

  @override
  String get phaseComplete => 'WORKOUT COMPLETE';

  @override
  String roundLabel(Object current, Object total) {
    return 'ROUND $current / $total';
  }

  @override
  String get tapToStartHint => 'TAP TO START';

  @override
  String get pauseButton => 'PAUSE';

  @override
  String get resumeButton => 'RESUME';

  @override
  String get stopButton => 'STOP';

  @override
  String get endWorkoutTitle => 'END WORKOUT?';

  @override
  String get endWorkoutBody => 'Progress will not be saved.';

  @override
  String get cancelAction => 'CANCEL';

  @override
  String get endAction => 'END';
}
