import '../domain/learning_phase.dart';
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
/// 3. nouvelles connaissances, les plus anciennes d'abord, dans la limite de
///    [newLimit] si elle est fixée.
List<QueueEntry<T>> buildReviewQueue<T>(
  Iterable<ReviewCandidate<T>> candidates, {
  required DateTime now,
  required Scheduler scheduler,
  int? newLimit,
}) {
  final window = DayWindow.around(now);
  final steps = <(ReviewCandidate<T>, double)>[];
  final reviews = <(ReviewCandidate<T>, double)>[];
  final fresh = <ReviewCandidate<T>>[];

  for (final candidate in candidates) {
    final state = candidate.state;
    final due = state.due;
    if (state.isNew || due == null) {
      fresh.add(candidate);
      continue;
    }
    final r = scheduler.retrievability(state, now);
    if (state.phase == LearningPhase.review) {
      if (due.isBefore(window.startOfTomorrow)) reviews.add((candidate, r));
    } else if (!due.isAfter(now)) {
      steps.add((candidate, r));
    }
  }

  steps.sort((a, b) => a.$1.state.due!.compareTo(b.$1.state.due!));
  reviews.sort((a, b) {
    final byR = a.$2.compareTo(b.$2);
    return byR != 0 ? byR : a.$1.state.due!.compareTo(b.$1.state.due!);
  });
  fresh.sort((a, b) => a.createdAt.compareTo(b.createdAt));

  QueueEntry<T> entry(ReviewCandidate<T> c, double r) =>
      (id: c.id, bucket: bucketOf(c.state, window), retrievability: r);

  return [
    for (final (c, r) in steps) entry(c, r),
    for (final (c, r) in reviews) entry(c, r),
    for (final c in fresh.take(newLimit ?? fresh.length)) entry(c, 0),
  ];
}
