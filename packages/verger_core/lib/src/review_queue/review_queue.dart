import '../domain/learning_phase.dart';
import '../domain/rating.dart';
import '../domain/scheduling_state.dart';
import '../scheduling/scheduler.dart';

/// Regroupement affiché dans la liste des révisions.
enum ReviewBucket { overdue, today, tomorrow, later, newItem }

/// Bornes des journées locales utilisées pour classer les échéances.
final class DayWindow {
  DayWindow._(this.startOfToday, this.startOfTomorrow, this.startOfDayAfter);

  /// Journées locales autour de [now] (gère les changements d'heure).
  factory DayWindow.around(DateTime now) {
    final local = now.toLocal();
    return DayWindow._(
      DateTime(local.year, local.month, local.day),
      DateTime(local.year, local.month, local.day + 1),
      DateTime(local.year, local.month, local.day + 2),
    );
  }

  final DateTime startOfToday;
  final DateTime startOfTomorrow;
  final DateTime startOfDayAfter;
}

ReviewBucket bucketOf(SchedulingState state, DayWindow window) {
  final due = state.due;
  if (state.isNew || due == null) return ReviewBucket.newItem;
  if (due.isBefore(window.startOfToday)) return ReviewBucket.overdue;
  if (due.isBefore(window.startOfTomorrow)) return ReviewBucket.today;
  if (due.isBefore(window.startOfDayAfter)) return ReviewBucket.tomorrow;
  return ReviewBucket.later;
}

/// Connaissance candidate à la révision.
typedef ReviewCandidate<T> = ({
  T id,
  SchedulingState state,
  DateTime createdAt,
});

/// Élément de la file avec ce qui a servi à le classer.
typedef QueueEntry<T> = ({T id, ReviewBucket bucket, double retrievability});

/// File d'une session de révision, par ordre de priorité :
/// 1. étapes d'apprentissage / réapprentissage arrivées à échéance (les plus
///    anciennes d'abord) ;
/// 2. révisions dues d'ici la fin de la journée, la probabilité de rappel la
///    plus basse d'abord (le plus menacé d'oubli) ;
/// 3. nouvelles connaissances, les plus anciennes d'abord (à égalité,
///    l'ordre de [candidates]), dans la limite de [newLimit] si elle est
///    fixée.
///
/// Avec [requires] (prérequis directs de chaque connaissance), une nouvelle
/// connaissance n'entre dans la file qu'une fois tous ses prérequis vus :
/// déjà dans [seen], ou présentés plus tôt dans la même session. Chacune
/// vient donc après ses prérequis ; les autres attendent une prochaine
/// session.
List<QueueEntry<T>> buildReviewQueue<T>(
  Iterable<ReviewCandidate<T>> candidates, {
  required DateTime now,
  required Scheduler scheduler,
  int? newLimit,
  Set<T> Function(T id)? requires,
  Set<T> seen = const {},
}) {
  final window = DayWindow.around(now);
  final steps = <(ReviewCandidate<T>, double)>[];
  final reviews = <(ReviewCandidate<T>, double)>[];
  final fresh = <ReviewCandidate<T>>[];

  for (final candidate in candidates) {
    final state = candidate.state;
    if (state.isNew || state.due == null) {
      fresh.add(candidate);
      continue;
    }
    if (!isDueNow(state, now)) continue;
    final r = scheduler.retrievability(state, now);
    (state.phase == LearningPhase.review ? reviews : steps).add((candidate, r));
  }

  steps.sort((a, b) => a.$1.state.due!.compareTo(b.$1.state.due!));
  reviews.sort((a, b) {
    final byR = a.$2.compareTo(b.$2);
    return byR != 0 ? byR : a.$1.state.due!.compareTo(b.$1.state.due!);
  });
  final rank = {for (final (n, c) in fresh.indexed) c.id: n};
  fresh.sort((a, b) {
    final byDate = a.createdAt.compareTo(b.createdAt);
    return byDate != 0 ? byDate : rank[a.id]!.compareTo(rank[b.id]!);
  });
  final introduced = requires == null
      ? fresh
      : _unlockedInOrder(fresh, requires, seen);

  QueueEntry<T> entry(ReviewCandidate<T> c, double r) =>
      (id: c.id, bucket: bucketOf(c.state, window), retrievability: r);

  return [
    for (final (c, r) in steps) entry(c, r),
    for (final (c, r) in reviews) entry(c, r),
    for (final c in introduced.take(newLimit ?? introduced.length)) entry(c, 0),
  ];
}

/// À réviser maintenant : étape d'apprentissage arrivée à échéance, ou
/// révision prévue d'ici la fin de la journée. Faux pour une nouvelle.
bool isDueNow(SchedulingState state, DateTime now) {
  final due = state.due;
  if (state.isNew || due == null) return false;
  return state.phase == LearningPhase.review
      ? due.isBefore(DayWindow.around(now).startOfTomorrow)
      : !due.isAfter(now);
}

/// [fresh] (déjà triées) dont tous les prérequis sont vus ou introduits
/// avant elles ; à chaque pas, la première de [fresh] qui est prête.
List<ReviewCandidate<T>> _unlockedInOrder<T>(
  List<ReviewCandidate<T>> fresh,
  Set<T> Function(T id) requires,
  Set<T> seen,
) {
  final known = {...seen};
  final pending = [...fresh];
  final out = <ReviewCandidate<T>>[];
  var progress = true;
  while (progress) {
    progress = false;
    for (var i = 0; i < pending.length; i++) {
      final c = pending[i];
      if (requires(c.id).every(known.contains)) {
        out.add(c);
        known.add(c.id);
        pending.removeAt(i);
        progress = true;
        break;
      }
    }
  }
  return out;
}

/// Révisions implicites après une révision notée [rating] : réussir un
/// énoncé, une démonstration ou un exercice (« Correct » ou « Facile »)
/// revient à revoir ce sur quoi il s'appuie. Parmi les prérequis directs
/// ([prerequisites], avec leur état), ceux déjà vus et à réviser
/// maintenant ; une note « À revoir » ou « Difficile » n'en implique aucun.
List<T> impliedReviews<T>(
  Rating rating,
  Iterable<({T id, SchedulingState state})> prerequisites,
  DateTime now,
) {
  if (rating != Rating.good && rating != Rating.easy) return const [];
  return [
    for (final p in prerequisites)
      if (isDueNow(p.state, now)) p.id,
  ];
}

/// Regroupe les connaissances pour la liste des révisions :
/// - en retard : la probabilité de rappel la plus faible d'abord ;
/// - aujourd'hui, demain, plus tard : par échéance ;
/// - nouvelles : les plus anciennes d'abord.
Map<ReviewBucket, List<QueueEntry<T>>> groupReviewList<T>(
  Iterable<ReviewCandidate<T>> candidates, {
  required DateTime now,
  required Scheduler scheduler,
}) {
  final window = DayWindow.around(now);
  final groups = {
    for (final b in ReviewBucket.values) b: <ReviewCandidate<T>>[],
  };
  final r = <T, double>{};
  for (final c in candidates) {
    groups[bucketOf(c.state, window)]!.add(c);
    r[c.id] = scheduler.retrievability(c.state, now);
  }
  int byDue(ReviewCandidate<T> a, ReviewCandidate<T> b) =>
      a.state.due!.compareTo(b.state.due!);
  groups[ReviewBucket.overdue]!.sort((a, b) {
    final byR = r[a.id]!.compareTo(r[b.id]!);
    return byR != 0 ? byR : byDue(a, b);
  });
  for (final b in [
    ReviewBucket.today,
    ReviewBucket.tomorrow,
    ReviewBucket.later,
  ]) {
    groups[b]!.sort(byDue);
  }
  groups[ReviewBucket.newItem]!.sort(
    (a, b) => a.createdAt.compareTo(b.createdAt),
  );
  return {
    for (final MapEntry(key: bucket, value: list) in groups.entries)
      bucket: [
        for (final c in list)
          (id: c.id, bucket: bucket, retrievability: r[c.id]!),
      ],
  };
}
