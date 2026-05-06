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
  String get skipButton => 'SALTAR';

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
  String get totalTimeCardLabel => 'TIEMPO RESTANTE';

  @override
  String get workoutCompleteTitle => 'ENTRENAMIENTO COMPLETO';

  @override
  String get workoutCompleteTotalLabel => 'TIEMPO TOTAL';

  @override
  String get doneAction => 'LISTO';

  @override
  String get customWorkouts => 'Entrenamientos Personalizados';

  @override
  String get newWorkout => 'Nuevo Entrenamiento';

  @override
  String get editWorkout => 'Editar Entrenamiento';

  @override
  String get workoutName => 'Nombre del entrenamiento';

  @override
  String get rounds => 'RONDAS';

  @override
  String get work => 'TRABAJO';

  @override
  String get rest => 'DESCANSO';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get createWorkout => 'Crear Entrenamiento';

  @override
  String get noWorkoutsYet => 'Sin Entrenamientos Aún';

  @override
  String get createFirstWorkoutCta =>
      'Crea tu primer entrenamiento personalizado para comenzar';

  @override
  String get preCountdownLocked => 'Cuenta regresiva: 45 segundos (fijo)';

  @override
  String get deleteConfirmTitle => '¿Eliminar este entrenamiento?';

  @override
  String get deleteConfirmBody => 'Esta acción no se puede deshacer.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get unsavedChangesTitle => '¿Descartar cambios?';

  @override
  String get unsavedChangesBody => 'Se perderán tus cambios.';

  @override
  String get discard => 'Descartar';

  @override
  String get workoutNotFound => 'Entrenamiento no encontrado';

  @override
  String smokerBlockLabel(Object index, Object total) {
    return 'BLOQUE $index DE $total';
  }

  @override
  String get smokerBlockTypeBoxing => 'BOXEO';

  @override
  String get smokerBlockTypeTabata => 'TABATA';

  @override
  String smokerTransitionLabel(Object nextIndex) {
    return 'TRANSICIÓN → BLOQUE $nextIndex';
  }

  @override
  String get customPreviewTitle => 'Entrenamientos personalizados';

  @override
  String customSlotEmpty(int slotNumber) {
    return 'Espacio $slotNumber — Toca para crear';
  }

  @override
  String customSlotSubtitle(int rounds, String work, String rest) {
    String _temp0 = intl.Intl.pluralLogic(
      rounds,
      locale: localeName,
      other: '$rounds rondas',
      one: '1 ronda',
    );
    return '$_temp0 · $work trabajo · $rest descanso';
  }

  @override
  String customSlotTotalLabel(String duration) {
    return 'Total: $duration';
  }

  @override
  String get customBuilderEditTitle => 'EDITAR ENTRENAMIENTO';

  @override
  String get customBuilderNewTitle => 'NUEVO ENTRENAMIENTO';

  @override
  String get customBuilderNameLabel => 'NOMBRE DEL ENTRENAMIENTO';

  @override
  String get customBuilderRoundsLabel => 'RONDAS';

  @override
  String get customBuilderWorkLabel => 'TRABAJO';

  @override
  String get customBuilderRestLabel => 'DESCANSO';

  @override
  String get customBuilderTotalLabel => 'TIEMPO TOTAL';

  @override
  String get customBuilderTotalSubtitle => 'No incluye los 45s de preparación';

  @override
  String get customBuilderSaveButton => 'GUARDAR';

  @override
  String get customBuilderDeleteButton => 'Eliminar este espacio';

  @override
  String customBuilderDeleteDialogTitle(String name) {
    return '¿Eliminar \'$name\'?';
  }

  @override
  String get customBuilderDeleteDialogBody =>
      'Esta acción no se puede deshacer.';

  @override
  String get customBuilderValidationNameRequired => 'Se requiere un nombre';

  @override
  String get customBuilderValidationNameInvalid =>
      'Usa solo letras, números y espacios';

  @override
  String get customBuilderValidationNameTooLong =>
      'El nombre debe tener 30 caracteres o menos';

  @override
  String get customBuilderValidationRoundsRange =>
      'Las rondas deben estar entre 1 y 30';

  @override
  String get customBuilderValidationWorkRange =>
      'El trabajo debe estar entre 10 y 600 segundos';

  @override
  String get customBuilderValidationRestRange =>
      'El descanso debe estar entre 5 y 300 segundos';

  @override
  String get proUpsellTitle => 'Desbloquea Pro';

  @override
  String get proUpsellBody =>
      'Desbloquea Smoker, entrenamientos personalizados y elimina anuncios.';

  @override
  String proUpsellCta(String price) {
    return 'Desbloquear Pro — $price';
  }

  @override
  String get proUpsellDismiss => 'Quizás luego';

  @override
  String get journalSchemaVersionMismatch =>
      'Los datos del diario necesitan actualizarse. Contacta soporte si esto persiste.';
}
