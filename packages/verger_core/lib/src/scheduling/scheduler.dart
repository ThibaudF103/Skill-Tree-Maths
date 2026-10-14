import '../domain/rating.dart';
import '../domain/review_record.dart';
import '../domain/scheduling_state.dart';

/// Ordonnanceur de répétition espacée. L'application ne dépend que de cette
/// interface : l'implémentation (FSRS) est remplaçable.
abstract interface class Scheduler {
  /// Identifiant stable de l'algorithme et de sa configuration, enregistré
  /// dans chaque [ReviewRecord].
  String get id;

  /// Nouvel état après une révision notée [rating] à l'instant [at].
  ///
  /// [fuzzKey] identifie la connaissance : il rend le léger aléa des
  /// intervalles déterministe (l'aperçu et la révision réelle concordent)
  /// tout en dispersant les connaissances révisées ensemble.
  SchedulingState review(
    SchedulingState state,
    Rating rating,
    DateTime at, {
    String fuzzKey = '',
  });

  /// Probabilité estimée de se souvenir de la connaissance à l'instant [at]
  /// (0 pour une connaissance jamais révisée).
  double retrievability(SchedulingState state, DateTime at);
}

extension SchedulerOperations on Scheduler {
  /// Les quatre issues possibles d'une révision, pour afficher l'intervalle
  /// prévu sur chaque bouton.
  Map<Rating, SchedulingState> preview(
    SchedulingState state,
    DateTime at, {
    String fuzzKey = '',
  }) => {
    for (final rating in Rating.values)
      rating: review(state, rating, at, fuzzKey: fuzzKey),
  };

  /// Effectue une révision et produit la trace correspondante.
  ReviewRecord record(
    SchedulingState state,
    Rating rating,
    DateTime at, {
    String fuzzKey = '',
    Duration? duration,
  }) {
    final reviewedAt = at.toUtc();
    return ReviewRecord(
      rating: rating,
      reviewedAt: reviewedAt,
      before: state,
      after: review(state, rating, reviewedAt, fuzzKey: fuzzKey),
      schedulerId: id,
      duration: duration,
    );
  }

  /// Recalcule l'état à partir de l'historique (changement d'algorithme ou de
  /// paramètres).
  SchedulingState replay(
    Iterable<({Rating rating, DateTime at})> history, {
    String fuzzKey = '',
  }) {
    var state = SchedulingState.initial;
    for (final entry in history) {
      state = review(state, entry.rating, entry.at, fuzzKey: fuzzKey);
    }
    return state;
  }
}
