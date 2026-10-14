import '../domain/learning_phase.dart';
import '../domain/scheduling_state.dart';

/// Stade de croissance visuel d'une connaissance. Seule la visualisation s'en
/// sert : les seuils peuvent changer sans toucher aux données.
enum GrowthStage {
  /// Jamais révisée.
  bud,

  /// En apprentissage ou réapprentissage.
  sprout,

  /// En révision, stabilité inférieure à une semaine.
  young,

  /// Stabilité entre une semaine et un mois.
  developed,

  /// Stabilité d'au moins un mois.
  mature;

  static GrowthStage of(SchedulingState state) => switch (state.phase) {
    LearningPhase.newItem => GrowthStage.bud,
    LearningPhase.learning || LearningPhase.relearning => GrowthStage.sprout,
    LearningPhase.review => switch (state.stability ?? 0) {
      < 7 => GrowthStage.young,
      < 30 => GrowthStage.developed,
      _ => GrowthStage.mature,
    },
  };
}
