import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Brand name, never translated
  ///
  /// In en, this message translates to:
  /// **'8 COUNT'**
  String get appTitle;

  /// Boxing preset card title
  ///
  /// In en, this message translates to:
  /// **'BOXING'**
  String get boxingTitle;

  /// Boxing preset metadata line
  ///
  /// In en, this message translates to:
  /// **'12 rounds · 3:00 work · 1:00 rest'**
  String get boxingMeta;

  /// Smoker preset card title
  ///
  /// In en, this message translates to:
  /// **'SMOKER'**
  String get smokerTitle;

  /// Smoker preset metadata line
  ///
  /// In en, this message translates to:
  /// **'HIIT composite · boxing + burnout'**
  String get smokerMeta;

  /// Custom preset card title
  ///
  /// In en, this message translates to:
  /// **'CUSTOM'**
  String get customTitle;

  /// Custom preset metadata line
  ///
  /// In en, this message translates to:
  /// **'Build your own · 3 saved slots'**
  String get customMeta;

  /// Pro tier badge label
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get proBadge;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsTitle;

  /// Settings section header for language toggle
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get languageLabel;

  /// English language option (always shown in English so users can find their language)
  ///
  /// In en, this message translates to:
  /// **'ENGLISH'**
  String get englishOption;

  /// Spanish language option (always shown in Spanish so users can find their language)
  ///
  /// In en, this message translates to:
  /// **'ESPAÑOL'**
  String get espanolOption;

  /// Accessibility tooltip on back arrow
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backTooltip;

  /// Accessibility tooltip on gear icon
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get settingsTooltip;

  /// Pre-workout countdown phase label
  ///
  /// In en, this message translates to:
  /// **'GET READY'**
  String get phaseGetReady;

  /// Work phase label
  ///
  /// In en, this message translates to:
  /// **'WORK'**
  String get phaseWork;

  /// Rest phase label
  ///
  /// In en, this message translates to:
  /// **'REST'**
  String get phaseRest;

  /// Final phase label shown when workout ends
  ///
  /// In en, this message translates to:
  /// **'WORKOUT COMPLETE'**
  String get phaseComplete;

  /// Current round indicator
  ///
  /// In en, this message translates to:
  /// **'ROUND {current} / {total}'**
  String roundLabel(Object current, Object total);

  /// Pre-countdown screen hint, shown before user taps to begin
  ///
  /// In en, this message translates to:
  /// **'TAP TO START'**
  String get tapToStartHint;

  /// Timer pause button label
  ///
  /// In en, this message translates to:
  /// **'PAUSE'**
  String get pauseButton;

  /// Timer resume button label (replaces PAUSE when paused)
  ///
  /// In en, this message translates to:
  /// **'RESUME'**
  String get resumeButton;

  /// Timer stop button label, opens end-workout dialog
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get stopButton;

  /// End-workout confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'END WORKOUT?'**
  String get endWorkoutTitle;

  /// End-workout confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'Progress will not be saved.'**
  String get endWorkoutBody;

  /// Generic cancel action button
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancelAction;

  /// End-workout confirmation, destructive action
  ///
  /// In en, this message translates to:
  /// **'END'**
  String get endAction;

  /// Short abbreviation for 'Round' shown on the round counter card during a workout (e.g., 'Rd 1/12')
  ///
  /// In en, this message translates to:
  /// **'Rd'**
  String get roundCardLabel;

  /// Label on the total workout time card shown during a workout
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get totalTimeCardLabel;

  /// Title shown on the workout complete screen
  ///
  /// In en, this message translates to:
  /// **'WORKOUT COMPLETE'**
  String get workoutCompleteTitle;

  /// Label above the total time figure on the complete screen
  ///
  /// In en, this message translates to:
  /// **'TOTAL TIME'**
  String get workoutCompleteTotalLabel;

  /// Button to dismiss the workout complete screen and return home
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get doneAction;

  /// Title of the saved-custom-presets list screen
  ///
  /// In en, this message translates to:
  /// **'Custom Workouts'**
  String get customWorkouts;

  /// Editor title when creating a new preset
  ///
  /// In en, this message translates to:
  /// **'New Workout'**
  String get newWorkout;

  /// Editor title when editing an existing preset
  ///
  /// In en, this message translates to:
  /// **'Edit Workout'**
  String get editWorkout;

  /// Editor name field hint text
  ///
  /// In en, this message translates to:
  /// **'Workout name'**
  String get workoutName;

  /// Stepper label above the rounds picker
  ///
  /// In en, this message translates to:
  /// **'ROUNDS'**
  String get rounds;

  /// Stepper label above the work-duration picker
  ///
  /// In en, this message translates to:
  /// **'WORK'**
  String get work;

  /// Stepper label above the rest-duration picker
  ///
  /// In en, this message translates to:
  /// **'REST'**
  String get rest;

  /// AppBar Save action in the preset editor
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Destructive action in the preset long-press bottom sheet and confirm dialog
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit action in the preset long-press bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Primary CTA shown in both the empty-state and the list's create row
  ///
  /// In en, this message translates to:
  /// **'Create Workout'**
  String get createWorkout;

  /// Empty-state headline when no custom presets are saved
  ///
  /// In en, this message translates to:
  /// **'No Workouts Yet'**
  String get noWorkoutsYet;

  /// Empty-state supporting copy
  ///
  /// In en, this message translates to:
  /// **'Create your first custom workout to get started'**
  String get createFirstWorkoutCta;

  /// Editor footnote reminding users the 45s warmup is fixed
  ///
  /// In en, this message translates to:
  /// **'Pre-workout countdown: 45 seconds (locked)'**
  String get preCountdownLocked;

  /// Destructive confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete this workout?'**
  String get deleteConfirmTitle;

  /// Destructive confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteConfirmBody;

  /// Generic cancel action in dialogs
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Editor back-nav confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get unsavedChangesTitle;

  /// Editor back-nav confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'Your changes will be lost.'**
  String get unsavedChangesBody;

  /// Destructive action in the unsaved-changes dialog
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// SnackBar shown when /timer/custom/:id resolves to a preset that no longer exists (deleted between tap and navigation, bad deep link, etc.)
  ///
  /// In en, this message translates to:
  /// **'Workout not found'**
  String get workoutNotFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
