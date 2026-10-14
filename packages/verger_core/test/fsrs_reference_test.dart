import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

/// Rejoue les scénarios calculés par py-fsrs (implémentation officielle,
/// voir tool/generate_fsrs_reference.py) et vérifie que notre adaptateur
/// donne les mêmes résultats.
void main() {
  final reference =
      jsonDecode(File('test/fixtures/fsrs_reference.json').readAsStringSync())
          as Map<String, dynamic>;
  final scheduler = FsrsScheduler(
    parameters: (reference['parameters'] as List).cast<double>(),
    desiredRetention: reference['desiredRetention'] as double,
    enableFuzzing: false,
  );
  final scenarios = reference['scenarios'] as Map<String, dynamic>;

  for (final MapEntry(key: name, value: steps) in scenarios.entries) {
    test('concorde avec py-fsrs : $name', () {
      var state = SchedulingState.initial;
      for (final (i, step) in (steps as List).cast<Map>().indexed) {
        final rating = Rating.values.byName(step['rating'] as String);
        final at = DateTime.parse(step['reviewedAt'] as String);
        state = scheduler.review(state, rating, at);

        final where = '$name, révision ${i + 1}';
        expect(state.phase.name, step['state'], reason: where);
        expect(state.step, step['step'], reason: where);
        expect(
          state.stability,
          closeTo(step['stability'] as double, 1e-9),
          reason: where,
        );
        expect(
          state.difficulty,
          closeTo(step['difficulty'] as double, 1e-9),
          reason: where,
        );
        expect(state.due, DateTime.parse(step['due'] as String), reason: where);
      }
    });
  }
}
