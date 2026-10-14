import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

void main() {
  final t0 = DateTime.utc(2026, 3, 2, 9);
  final scheduler = FsrsScheduler();

  group('FsrsScheduler', () {
    test('une connaissance nouvelle passe en apprentissage', () {
      final s = scheduler.review(SchedulingState.initial, Rating.good, t0);
      expect(s.phase, LearningPhase.learning);
      expect(s.step, 1);
      expect(s.reps, 1);
      expect(s.lastReview, t0);
      expect(s.due, t0.add(const Duration(minutes: 10)));
      expect(s.stability, isNotNull);
      expect(s.difficulty, inInclusiveRange(1, 10));
    });

    test(
      '« je connais déjà » (Easy) envoie directement en révision espacée',
      () {
        final s = scheduler.review(SchedulingState.initial, Rating.easy, t0);
        expect(s.phase, LearningPhase.review);
        expect(s.due!.difference(t0).inDays, greaterThanOrEqualTo(6));
      },
    );

    test(
      'un oubli en révision compte un lapse et passe en réapprentissage',
      () {
        var s = scheduler.review(SchedulingState.initial, Rating.easy, t0);
        final before = s.stability!;
        s = scheduler.review(s, Rating.again, s.due!);
        expect(s.phase, LearningPhase.relearning);
        expect(s.lapses, 1);
        expect(s.stability, lessThan(before));
      },
    );

    test('les dates locales sont converties en UTC', () {
      final local = DateTime(2026, 3, 2, 10);
      final s = scheduler.review(SchedulingState.initial, Rating.good, local);
      expect(s.lastReview!.isUtc, isTrue);
      expect(s.lastReview, local.toUtc());
    });

    test('la rétention baisse avec le temps', () {
      final s = scheduler.review(SchedulingState.initial, Rating.easy, t0);
      final r1 = scheduler.retrievability(s, t0.add(const Duration(days: 1)));
      final r30 = scheduler.retrievability(s, t0.add(const Duration(days: 30)));
      expect(scheduler.retrievability(SchedulingState.initial, t0), 0);
      expect(r1, greaterThan(r30));
      expect(r1, lessThanOrEqualTo(1));
    });

    test("l'aperçu des boutons correspond exactement à la révision", () {
      var s = SchedulingState.initial;
      for (final rating in [Rating.easy, Rating.good, Rating.good]) {
        s = scheduler.review(s, rating, s.due ?? t0, fuzzKey: 'item-42');
      }
      final at = s.due!;
      final preview = scheduler.preview(s, at, fuzzKey: 'item-42');
      expect(preview.keys, Rating.values);
      for (final rating in Rating.values) {
        expect(
          preview[rating],
          scheduler.review(s, rating, at, fuzzKey: 'item-42'),
        );
      }
      final days = [
        for (final r in [Rating.hard, Rating.good, Rating.easy])
          preview[r]!.due!.difference(at).inDays,
      ];
      expect(days, orderedEquals([...days]..sort()));
    });

    test("l'aléa disperse les connaissances révisées ensemble", () {
      final dues = <DateTime>{};
      for (var i = 0; i < 20; i++) {
        var s = scheduler.review(
          SchedulingState.initial,
          Rating.easy,
          t0,
          fuzzKey: 'item-$i',
        );
        s = scheduler.review(s, Rating.good, s.due!, fuzzKey: 'item-$i');
        dues.add(s.due!);
      }
      expect(dues.length, greaterThan(1));
    });

    test('rejouer l\'historique redonne le même état', () {
      final history = <({Rating rating, DateTime at})>[];
      var s = SchedulingState.initial;
      for (final rating in [
        Rating.good,
        Rating.good,
        Rating.hard,
        Rating.good,
      ]) {
        final at = s.due ?? t0;
        history.add((rating: rating, at: at));
        s = scheduler.review(s, rating, at, fuzzKey: 'k');
      }
      expect(scheduler.replay(history, fuzzKey: 'k'), s);
    });

    test('record conserve les états avant/après et l\'ordonnanceur', () {
      final record = scheduler.record(
        SchedulingState.initial,
        Rating.good,
        t0,
        duration: const Duration(seconds: 40),
      );
      expect(record.before, SchedulingState.initial);
      expect(record.after.reps, 1);
      expect(record.schedulerId, 'fsrs-6/r0.90');
      expect(record.duration, const Duration(seconds: 40));
    });

    test("l'intervalle maximal est respecté", () {
      final capped = FsrsScheduler(maximumInterval: 10, enableFuzzing: false);
      var s = SchedulingState.initial;
      for (var i = 0; i < 6; i++) {
        s = capped.review(s, Rating.easy, s.due ?? t0);
      }
      expect(s.due!.difference(s.lastReview!).inDays, 10);
    });
  });
}
