import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

void main() {
  // Mercredi 4 mars 2026, 15 h (heure locale).
  final now = DateTime(2026, 3, 4, 15);
  final scheduler = FsrsScheduler();

  SchedulingState reviewDue(DateTime due, {double stability = 10}) =>
      SchedulingState(
        phase: LearningPhase.review,
        stability: stability,
        difficulty: 5,
        due: due.toUtc(),
        lastReview: due.subtract(Duration(days: stability.round())).toUtc(),
        reps: 4,
      );

  SchedulingState step(DateTime due) => SchedulingState(
    phase: LearningPhase.learning,
    step: 1,
    stability: 2,
    difficulty: 5,
    due: due.toUtc(),
    lastReview: due.subtract(const Duration(minutes: 10)).toUtc(),
    reps: 1,
  );

  ReviewCandidate<String> c(String id, SchedulingState s, {int age = 0}) => (
    id: id,
    state: s,
    createdAt: DateTime(2026, 1, 1).add(Duration(days: age)),
  );

  group('bucketOf', () {
    final window = DayWindow.around(now);
    test('classe par journée locale', () {
      expect(bucketOf(SchedulingState.initial, window), ReviewBucket.newItem);
      expect(
        bucketOf(reviewDue(DateTime(2026, 3, 2, 9)), window),
        ReviewBucket.overdue,
      );
      expect(
        bucketOf(reviewDue(DateTime(2026, 3, 4, 0, 1)), window),
        ReviewBucket.today,
      );
      expect(
        bucketOf(reviewDue(DateTime(2026, 3, 4, 23, 59)), window),
        ReviewBucket.today,
      );
      expect(
        bucketOf(reviewDue(DateTime(2026, 3, 5, 8)), window),
        ReviewBucket.tomorrow,
      );
      expect(
        bucketOf(reviewDue(DateTime(2026, 3, 9)), window),
        ReviewBucket.later,
      );
    });
  });

  group('buildReviewQueue', () {
    test(
      'ordre : étapes dues, révisions (rappel le plus faible), nouvelles',
      () {
        final queue = buildReviewQueue(
          [
            c('nouvelle-recente', SchedulingState.initial, age: 5),
            c('demain', reviewDue(DateTime(2026, 3, 5, 9))),
            c(
              'retard-leger',
              reviewDue(DateTime(2026, 3, 3, 9), stability: 30),
            ),
            c('retard-fort', reviewDue(DateTime(2026, 2, 20, 9), stability: 3)),
            c('ce-soir', reviewDue(DateTime(2026, 3, 4, 20), stability: 30)),
            c('etape-due', step(DateTime(2026, 3, 4, 14, 50))),
            c('etape-plus-tard', step(DateTime(2026, 3, 4, 15, 5))),
            c('nouvelle-ancienne', SchedulingState.initial, age: 1),
          ],
          now: now,
          scheduler: scheduler,
        );
        expect(queue.map((e) => e.id), [
          'etape-due',
          'retard-fort',
          'retard-leger',
          'ce-soir',
          'nouvelle-ancienne',
          'nouvelle-recente',
        ]);
        expect(queue[1].bucket, ReviewBucket.overdue);
        expect(queue[1].retrievability, lessThan(queue[2].retrievability));
        expect(queue[3].bucket, ReviewBucket.today);
        expect(queue.last.bucket, ReviewBucket.newItem);
      },
    );

    test('limite le nombre de nouvelles connaissances', () {
      final queue = buildReviewQueue(
        [for (var i = 0; i < 5; i++) c('n$i', SchedulingState.initial, age: i)],
        now: now,
        scheduler: scheduler,
        newLimit: 2,
      );
      expect(queue.map((e) => e.id), ['n0', 'n1']);
    });
  });

  group('groupReviewList', () {
    test('répartit et trie chaque groupe', () {
      final groups = groupReviewList(
        [
          c('nouvelle-recente', SchedulingState.initial, age: 5),
          c('apres-demain', reviewDue(DateTime(2026, 3, 7, 9))),
          c('demain', reviewDue(DateTime(2026, 3, 5, 9))),
          c('retard-leger', reviewDue(DateTime(2026, 3, 3, 9), stability: 30)),
          c('retard-fort', reviewDue(DateTime(2026, 2, 20, 9), stability: 3)),
          c('ce-soir', reviewDue(DateTime(2026, 3, 4, 20))),
          c('ce-matin', reviewDue(DateTime(2026, 3, 4, 8))),
          c('nouvelle-ancienne', SchedulingState.initial, age: 1),
        ],
        now: now,
        scheduler: scheduler,
      );
      List<String> ids(ReviewBucket b) => groups[b]!.map((e) => e.id).toList();
      expect(ids(ReviewBucket.overdue), ['retard-fort', 'retard-leger']);
      expect(ids(ReviewBucket.today), ['ce-matin', 'ce-soir']);
      expect(ids(ReviewBucket.tomorrow), ['demain']);
      expect(ids(ReviewBucket.later), ['apres-demain']);
      expect(ids(ReviewBucket.newItem), [
        'nouvelle-ancienne',
        'nouvelle-recente',
      ]);
    });
  });

  group('prérequis', () {
    final edges = <String, Set<String>>{
      'thm': {'def'},
      'cor': {'thm'},
      'ext': {'ailleurs'},
    };
    Set<String> requires(String id) => edges[id] ?? const {};
    final fresh = [
      c('cor', SchedulingState.initial),
      c('thm', SchedulingState.initial),
      c('def', SchedulingState.initial),
      c('ext', SchedulingState.initial),
      c('libre', SchedulingState.initial),
    ];

    test('à égalité de date, l\'ordre donné est conservé', () {
      final queue = buildReviewQueue(fresh, now: now, scheduler: scheduler);
      expect(queue.map((e) => e.id), ['cor', 'thm', 'def', 'ext', 'libre']);
    });

    test('chaque nouvelle vient après ses prérequis', () {
      final queue = buildReviewQueue(
        fresh,
        now: now,
        scheduler: scheduler,
        requires: requires,
      );
      // « ext » attend un prérequis jamais vu, absent de la session.
      expect(queue.map((e) => e.id), ['def', 'thm', 'cor', 'libre']);
    });

    test('un prérequis déjà vu débloque', () {
      final queue = buildReviewQueue(
        fresh,
        now: now,
        scheduler: scheduler,
        requires: requires,
        seen: {'ailleurs'},
        newLimit: 3,
      );
      expect(queue.map((e) => e.id), ['def', 'thm', 'cor']);
    });

    test('révisions implicites : seulement après une réussite, si dû', () {
      final prereqs = [
        (id: 'dû', state: reviewDue(DateTime(2026, 3, 4, 9))),
        (id: 'plus tard', state: reviewDue(DateTime(2026, 3, 9))),
        (id: 'nouveau', state: SchedulingState.initial),
        (id: 'étape', state: step(DateTime(2026, 3, 4, 14))),
      ];
      expect(impliedReviews(Rating.good, prereqs, now), ['dû', 'étape']);
      expect(impliedReviews(Rating.easy, prereqs, now), ['dû', 'étape']);
      expect(impliedReviews(Rating.hard, prereqs, now), isEmpty);
      expect(impliedReviews(Rating.again, prereqs, now), isEmpty);
    });
  });
}
