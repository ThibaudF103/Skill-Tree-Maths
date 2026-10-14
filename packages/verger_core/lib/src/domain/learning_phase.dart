/// Phase d'apprentissage d'une connaissance.
enum LearningPhase {
  /// Créée, jamais révisée.
  newItem,

  /// Premières révisions rapprochées (étapes d'apprentissage).
  learning,

  /// Révisions espacées.
  review,

  /// Oubliée en phase de révision, en cours de réapprentissage.
  relearning,
}
