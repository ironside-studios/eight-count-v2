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
  String get skipButton => 'SKIP';

  @override
  String get endWorkoutTitle => 'END WORKOUT?';

  @override
  String get endWorkoutBody => 'Progress will not be saved.';

  @override
  String get cancelAction => 'CANCEL';

  @override
  String get endAction => 'END';

  @override
  String get roundCardLabel => 'Rd';

  @override
  String get totalTimeCardLabel => 'TIME REMAINING';

  @override
  String get workoutCompleteTitle => 'WORKOUT COMPLETE';

  @override
  String get workoutCompleteTotalLabel => 'TOTAL TIME';

  @override
  String get doneAction => 'DONE';

  @override
  String get customWorkouts => 'Custom Workouts';

  @override
  String get newWorkout => 'New Workout';

  @override
  String get editWorkout => 'Edit Workout';

  @override
  String get workoutName => 'Workout name';

  @override
  String get rounds => 'ROUNDS';

  @override
  String get work => 'WORK';

  @override
  String get rest => 'REST';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get createWorkout => 'Create Workout';

  @override
  String get noWorkoutsYet => 'No Workouts Yet';

  @override
  String get createFirstWorkoutCta =>
      'Create your first custom workout to get started';

  @override
  String get preCountdownLocked => 'Pre-workout countdown: 45 seconds (locked)';

  @override
  String get deleteConfirmTitle => 'Delete this workout?';

  @override
  String get deleteConfirmBody => 'This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get unsavedChangesTitle => 'Discard changes?';

  @override
  String get unsavedChangesBody => 'Your changes will be lost.';

  @override
  String get discard => 'Discard';

  @override
  String get workoutNotFound => 'Workout not found';

  @override
  String smokerBlockLabel(Object index, Object total) {
    return 'BLOCK $index OF $total';
  }

  @override
  String get smokerBlockTypeBoxing => 'BOXING';

  @override
  String get smokerBlockTypeTabata => 'TABATA';

  @override
  String smokerTransitionLabel(Object nextIndex) {
    return 'TRANSITION → BLOCK $nextIndex';
  }

  @override
  String get customPreviewTitle => 'Custom Workouts';

  @override
  String customSlotEmpty(int slotNumber) {
    return 'Slot $slotNumber — Tap to build';
  }

  @override
  String customSlotSubtitle(int rounds, String work, String rest) {
    String _temp0 = intl.Intl.pluralLogic(
      rounds,
      locale: localeName,
      other: '$rounds rounds',
      one: '1 round',
    );
    return '$_temp0 · $work work · $rest rest';
  }

  @override
  String customSlotTotalLabel(String duration) {
    return 'Total: $duration';
  }

  @override
  String get customBuilderEditTitle => 'EDIT WORKOUT';

  @override
  String get customBuilderNewTitle => 'NEW WORKOUT';

  @override
  String get customBuilderNameLabel => 'WORKOUT NAME';

  @override
  String get customBuilderRoundsLabel => 'ROUNDS';

  @override
  String get customBuilderWorkLabel => 'WORK';

  @override
  String get customBuilderRestLabel => 'REST';

  @override
  String get customBuilderTotalLabel => 'TOTAL WORKOUT';

  @override
  String get customBuilderTotalSubtitle => 'Excludes 45s get-ready';

  @override
  String get customBuilderSaveButton => 'SAVE WORKOUT';

  @override
  String get customBuilderDeleteButton => 'Delete this slot';

  @override
  String customBuilderDeleteDialogTitle(String name) {
    return 'Delete \'$name\'?';
  }

  @override
  String get customBuilderDeleteDialogBody => 'This cannot be undone.';

  @override
  String get customBuilderValidationNameRequired => 'Name is required';

  @override
  String get customBuilderValidationNameInvalid =>
      'Use letters, numbers, and spaces only';

  @override
  String get customBuilderValidationNameTooLong =>
      'Name must be 30 characters or fewer';

  @override
  String get customBuilderValidationRoundsRange =>
      'Rounds must be between 1 and 30';

  @override
  String get customBuilderValidationWorkRange =>
      'Work must be between 10 and 600 seconds';

  @override
  String get customBuilderValidationRestRange =>
      'Rest must be between 5 and 300 seconds';

  @override
  String get proUpsellTitle => 'Unlock Pro';

  @override
  String get proUpsellBody => 'Unlock Smoker, Custom workouts, and remove ads.';

  @override
  String proUpsellCta(String price) {
    return 'Unlock Pro — $price';
  }

  @override
  String get proUpsellDismiss => 'Maybe later';

  @override
  String get videoSettingsListEntry => 'Video Capture';

  @override
  String get videoSettingsTitle => 'Video Capture';

  @override
  String get videoSettingsEnableTitle => 'Enable Video Capture';

  @override
  String get videoSettingsEnableSubtitle => 'Record clips during your workouts';

  @override
  String get videoSettingsClipLengthTitle => 'Clip Length';

  @override
  String get videoSettingsClipLength20s => '20s';

  @override
  String get videoSettingsClipLength30s => '30s';

  @override
  String get videoSettingsCameraTitle => 'Camera';

  @override
  String get videoSettingsCameraFront => 'Front';

  @override
  String get videoSettingsCameraBack => 'Back';

  @override
  String get videoSettingsCameraSubtitle =>
      'Front for shadowboxing, Back for heavy bag';

  @override
  String get videoSettingsClipsPerRoundTitle => 'Clips Per Round';

  @override
  String get videoSettingsCaptureTimingTitle => 'Capture Timing';

  @override
  String get videoSettingsResolutionTitle => 'Resolution';

  @override
  String get videoSettingsResolutionStandard => 'Standard (720p)';

  @override
  String get videoSettingsResolutionHigh => 'High (1080p)';

  @override
  String get videoSettingsResolutionSubtitle =>
      'Higher quality uses more storage';

  @override
  String get videoSettingsAiAutoPickTitle => 'AI Auto-Pick';

  @override
  String get videoSettingsAiAutoPickSubtitle =>
      'Smart selection of your best clips after each workout';
}
