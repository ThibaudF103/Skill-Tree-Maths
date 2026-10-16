import 'rating.dart';
import 'scheduling_state.dart';

/// Trace immuable d'une révision. L'historique des révisions est la source de
/// vérité : il permet de recalculer l'état avec un autre ordonnanceur.
final class ReviewRecord {
  const ReviewRecord({
    required this.rating,
    required this.reviewedAt,
    required this.before,
    required this.after,
    required this.schedulerId,
    this.duration,
    this.impliedBy,
  });

  final Rating rating;
  final DateTime reviewedAt;
  final SchedulingState before;
  final SchedulingState after;

  /// Identifiant de l'ordonnanceur et de sa configuration (ex. `fsrs-6/r0.90`).
  final String schedulerId;

  /// Temps passé sur la révision, si mesuré.
  final Duration? duration;

  /// Révision implicite : la connaissance réussie qui s'appuie sur celle-ci
  /// (`null` pour une révision ordinaire).
  final String? impliedBy;
}
