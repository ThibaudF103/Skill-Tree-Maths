import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

SchedulingState review(double stability) => SchedulingState(
  phase: LearningPhase.review,
  stability: stability,
  difficulty: 5,
  due: DateTime.utc(2026),
  lastReview: DateTime.utc(2026),
  reps: 3,
);

void main() {
  group('GrowthStage', () {
    test('suit la phase puis la stabilité', () {
      expect(GrowthStage.of(SchedulingState.initial), GrowthStage.bud);
      expect(
        GrowthStage.of(const SchedulingState(phase: LearningPhase.learning)),
        GrowthStage.sprout,
      );
      expect(
        GrowthStage.of(const SchedulingState(phase: LearningPhase.relearning)),
        GrowthStage.sprout,
      );
      expect(GrowthStage.of(review(2)), GrowthStage.young);
      expect(GrowthStage.of(review(7)), GrowthStage.developed);
      expect(GrowthStage.of(review(29.9)), GrowthStage.developed);
      expect(GrowthStage.of(review(30)), GrowthStage.mature);
    });
  });

  group('MasteryModel', () {
    const model = MasteryModel(targetStabilityDays: 90);

    test('nulle pour une connaissance nouvelle', () {
      expect(model.of(SchedulingState.initial, 1), 0);
    });

    test('croît avec la stabilité et plafonne à la cible', () {
      final m = [
        for (final s in [1.0, 10.0, 90.0, 400.0]) model.of(review(s), 1),
      ];
      expect(m[0], lessThan(m[1]));
      expect(m[1], lessThan(m[2]));
      expect(m[2], 1);
      expect(m[3], 1);
    });

    test('baisse quand la probabilité de rappel baisse', () {
      expect(model.of(review(90), 0.5), closeTo(0.5, 1e-12));
    });
  });

  group('aggregateProgress', () {
    // algebre ─┬─ ev ─┬─ base
    //          │      └─ dim
    //          └─ reduction
    // analyse (vide)
    const parentOf = {
      'algebre': null,
      'ev': 'algebre',
      'base': 'ev',
      'dim': 'ev',
      'reduction': 'algebre',
      'analyse': null,
    };

    ItemProgress item(String node, GrowthStage stage, double m, bool due) =>
        (nodeId: node, stage: stage, mastery: m, isDue: due);

    test('cumule chaque connaissance dans tous ses ancêtres', () {
      final progress = aggregateProgress(
        parentOf: parentOf,
        items: [
          item('base', GrowthStage.mature, 1, false),
          item('dim', GrowthStage.bud, 0, false),
          item('ev', GrowthStage.young, 0.5, true),
          item('reduction', GrowthStage.sprout, 0.2, true),
        ],
      );
      expect(progress['base']!.itemCount, 1);
      expect(progress['ev']!.itemCount, 3);
      expect(progress['ev']!.dueCount, 1);
      expect(progress['ev']!.meanMastery, closeTo(0.5, 1e-12));
      expect(progress['algebre']!.itemCount, 4);
      expect(progress['algebre']!.dueCount, 2);
      expect(progress['algebre']!.stageCounts[GrowthStage.mature], 1);
      expect(progress['algebre']!.stageCounts[GrowthStage.bud], 1);
    });

    test('un arbre sans connaissance est en hiver', () {
      final progress = aggregateProgress(parentOf: parentOf, items: const []);
      expect(progress['analyse']!.isEmpty, isTrue);
      expect(progress['analyse']!.meanMastery, 0);
    });

    test('résiste à un cycle accidentel', () {
      final progress = aggregateProgress(
        parentOf: const {'a': 'b', 'b': 'a'},
        items: [item('a', GrowthStage.bud, 0, false)],
      );
      expect(progress['a']!.itemCount, 1);
      expect(progress['b']!.itemCount, 1);
    });
  });
}
