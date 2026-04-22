// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => '8 COUNT';

  @override
  String get boxingTitle => 'BOXEO';

  @override
  String get boxingMeta => '12 rondas · 3:00 trabajo · 1:00 descanso';

  @override
  String get smokerTitle => 'QUEMADOR';

  @override
  String get smokerMeta => 'HIIT compuesto · boxeo + agotamiento';

  @override
  String get customTitle => 'PERSONALIZADO';

  @override
  String get customMeta => 'Crea el tuyo · 3 espacios guardados';

  @override
  String get proBadge => 'PRO';

  @override
  String get settingsTitle => 'AJUSTES';

  @override
  String get languageLabel => 'IDIOMA';

  @override
  String get englishOption => 'ENGLISH';

  @override
  String get espanolOption => 'ESPAÑOL';

  @override
  String get backTooltip => 'Atrás';

  @override
  String get settingsTooltip => 'Abrir ajustes';

  @override
  String get phaseGetReady => 'PREPÁRATE';

  @override
  String get phaseWork => 'TRABAJO';

  @override
  String get phaseRest => 'DESCANSO';

  @override
  String get phaseComplete => 'ENTRENAMIENTO COMPLETO';

  @override
  String roundLabel(Object current, Object total) {
    return 'RONDA $current / $total';
  }

  @override
  String get tapToStartHint => 'TOCA PARA EMPEZAR';

  @override
  String get pauseButton => 'PAUSA';

  @override
  String get resumeButton => 'REANUDAR';

  @override
  String get stopButton => 'PARAR';

  @override
  String get endWorkoutTitle => '¿TERMINAR?';

  @override
  String get endWorkoutBody => 'El progreso no se guardará.';

  @override
  String get cancelAction => 'CANCELAR';

  @override
  String get endAction => 'TERMINAR';

  @override
  String get roundCardLabel => 'Rnd';

  @override
  String get totalTimeCardLabel => 'TOTAL';

  @override
  String get workoutCompleteTitle => 'ENTRENAMIENTO COMPLETO';

  @override
  String get workoutCompleteTotalLabel => 'TIEMPO TOTAL';

  @override
  String get doneAction => 'LISTO';
}
