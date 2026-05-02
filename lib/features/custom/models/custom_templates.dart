import 'custom_config.dart';

/// One pre-defined template for the Custom Preset Builder. Templates
/// pre-fill the builder's numeric form fields (rounds, work, rest);
/// the user names the slot themselves and remains free to tweak any
/// field after loading. Templates are STARTERS, not types — once a
/// slot is saved, no "template type" is stored on the config.
class CustomTemplate {
  const CustomTemplate({
    required this.id,
    required this.rounds,
    required this.workSeconds,
    required this.restSeconds,
  });

  /// Stable lookup key (e.g., 'tabata'). Used to select localized
  /// display strings via the AppLocalizations key family
  /// `customTemplate<Pascalcase id>`.
  final String id;

  final int rounds;
  final int workSeconds;
  final int restSeconds;

  /// Apply this template to an existing builder draft. The slotIndex
  /// and lastModified pass through; the name field is intentionally
  /// preserved so the user keeps whatever they were typing (or empty
  /// if untouched). Numeric fields all overwrite.
  CustomConfig applyTo(CustomConfig draft) {
    return draft.copyWith(
      rounds: rounds,
      workSeconds: workSeconds,
      restSeconds: restSeconds,
    );
  }
}

/// Registry of all available templates. Add new entries here +
/// matching localization keys + a docstring; the picker bottom sheet
/// renders [all] in order.
class CustomTemplates {
  CustomTemplates._();

  /// Tabata (locked V2 5/2/26): 8 rounds × 20s work × 10s rest.
  /// 4-minute total; widely recognized HIIT format.
  static const CustomTemplate tabata = CustomTemplate(
    id: 'tabata',
    rounds: 8,
    workSeconds: 20,
    restSeconds: 10,
  );

  /// All registered templates in display order.
  static const List<CustomTemplate> all = <CustomTemplate>[tabata];
}
