import 'learning_phase.dart';

/// État d'ordonnancement d'une connaissance, indépendant de l'algorithme
/// utilisé (FSRS aujourd'hui) et du stockage.
///
/// Toutes les dates sont en UTC.
final class SchedulingState {
  const SchedulingState({
    required this.phase,
    this.step,
    this.stability,
    this.difficulty,
    this.due,
    this.lastReview,
    this.reps = 0,
    this.lapses = 0,
  });

  /// État d'une connaissance qui vient d'être créée.
  static const initial = SchedulingState(phase: LearningPhase.newItem);

  final LearningPhase phase;

  /// Étape courante en apprentissage / réapprentissage, sinon `null`.
  final int? step;

  /// Stabilité en jours : durée au bout de laquelle la probabilité de rappel
  /// tombe à 90 %. `null` tant que la connaissance n'a jamais été révisée.
  final double? stability;

  /// Difficulté intrinsèque, entre 1 et 10.
  final double? difficulty;

  /// Prochaine échéance ; `null` pour une connaissance nouvelle.
  final DateTime? due;

  final DateTime? lastReview;

  /// Nombre total de révisions.
  final int reps;

  /// Nombre d'oublis (note « Again ») en phase de révision.
  final int lapses;

  bool get isNew => phase == LearningPhase.newItem;

  @override
  bool operator ==(Object other) =>
      other is SchedulingState &&
      other.phase == phase &&
      other.step == step &&
      other.stability == stability &&
      other.difficulty == difficulty &&
      other.due == due &&
      other.lastReview == lastReview &&
      other.reps == reps &&
      other.lapses == lapses;

  @override
  int get hashCode => Object.hash(
    phase,
    step,
    stability,
    difficulty,
    due,
    lastReview,
    reps,
    lapses,
  );

  @override
  String toString() =>
      'SchedulingState($phase, step: $step, S: $stability, D: $difficulty, '
      'due: $due, reps: $reps, lapses: $lapses)';
}
