/// Nature d'une connaissance.
enum ItemKind {
  definition,

  /// Énoncé sans précision (théorème, proposition… facultatif).
  statement,
  theorem,
  proposition,
  lemma,
  property,
  corollary,
  exercise;

  /// Regroupement visuel : définition → feuille, énoncé → fleur, exercice → fruit.
  ItemFamily get family => switch (this) {
    ItemKind.definition => ItemFamily.definition,
    ItemKind.exercise => ItemFamily.exercise,
    _ => ItemFamily.statement,
  };
}

/// Les trois grandes familles de connaissances.
enum ItemFamily { definition, statement, exercise }

/// Difficulté facultative d'un exercice.
enum ExerciseLevel { easy, medium, hard }
