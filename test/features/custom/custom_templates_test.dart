import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/features/custom/models/custom_config.dart';
import 'package:eight_count/features/custom/models/custom_templates.dart';

void main() {
  group('CustomTemplates.tabata', () {
    test('has correct locked values (8 rounds × 20s × 10s)', () {
      const t = CustomTemplates.tabata;
      expect(t.id, 'tabata');
      expect(t.rounds, 8);
      expect(t.workSeconds, 20);
      expect(t.restSeconds, 10);
    });

    test('appears in CustomTemplates.all in display order', () {
      expect(CustomTemplates.all.first, same(CustomTemplates.tabata));
      expect(CustomTemplates.all.length, 1,
          reason: 'V2 ships with Tabata only; future templates '
              'append to .all and update this assertion');
    });
  });

  group('CustomTemplate.applyTo', () {
    test('overwrites all 3 numeric fields on the draft', () {
      final draft = CustomConfig.empty(0).copyWith(
        rounds: 5,
        workSeconds: 90,
        restSeconds: 30,
      );
      final result = CustomTemplates.tabata.applyTo(draft);
      expect(result.rounds, 8);
      expect(result.workSeconds, 20);
      expect(result.restSeconds, 10);
    });

    test('does NOT overwrite the name field (template = starter, '
        'not lock)', () {
      final draft = CustomConfig.empty(0).copyWith(
        name: 'My Custom Workout',
        rounds: 5,
        workSeconds: 90,
        restSeconds: 30,
      );
      final result = CustomTemplates.tabata.applyTo(draft);
      expect(result.name, 'My Custom Workout',
          reason: 'name is preserved; user names the slot themselves');
    });

    test('preserves slotIndex from the draft', () {
      final draft = CustomConfig.empty(2);
      final result = CustomTemplates.tabata.applyTo(draft);
      expect(result.slotIndex, 2);
    });

    test('totalWorkoutSeconds after Tabata load = '
        '(20 × 8) + (10 × 7) = 230s', () {
      // The CustomConfig math is rounds × work + (rounds-1) × rest.
      // For Tabata (8 × 20s + 7 × 10s) the total is 230s = 3:50.
      final draft = CustomConfig.empty(0);
      final result = CustomTemplates.tabata.applyTo(draft);
      expect(result.totalWorkoutSeconds, 230);
    });

    test('after template load, fields remain mutable via copyWith '
        '(simulates user bumping rounds to 16)', () {
      final draft = CustomConfig.empty(0);
      final loaded = CustomTemplates.tabata.applyTo(draft);
      // User bumps rounds via the rounds stepper.
      final tweaked = loaded.copyWith(rounds: 16);
      expect(tweaked.rounds, 16);
      // Tabata-template values for work/rest stick.
      expect(tweaked.workSeconds, 20);
      expect(tweaked.restSeconds, 10);
      // Original loaded draft is unchanged (immutability).
      expect(loaded.rounds, 8);
    });
  });
}
