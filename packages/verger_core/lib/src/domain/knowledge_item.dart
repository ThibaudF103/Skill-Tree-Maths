import 'item_kind.dart';
import 'scheduling_state.dart';

/// Connaissance que l'utilisateur a décidé d'apprendre, rattachée à un nœud.
final class KnowledgeItem {
  const KnowledgeItem({
    required this.id,
    required this.nodeId,
    required this.kind,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.body,
    this.level,
    this.autoExercise,
    this.sortIndex = 0,
    this.suspended = false,
    this.scheduling = SchedulingState.initial,
  });

  final String id;
  final String nodeId;
  final ItemKind kind;
  final String title;

  /// Contenu textuel facultatif (énoncé, remarques).
  final String? body;

  /// Difficulté d'un exercice, facultative (nulle pour les autres types).
  final ExerciseLevel? level;

  /// Modèle d'exercice paramétré corrigé automatiquement (source JSON, voir
  /// `ExerciseTemplate`), facultatif : la révision tire alors un énoncé
  /// et note d'après les réponses.
  final String? autoExercise;

  /// Position parmi les connaissances du même nœud.
  final int sortIndex;

  /// Exclue des révisions sans être supprimée.
  final bool suspended;
  final SchedulingState scheduling;
  final DateTime createdAt;
  final DateTime updatedAt;
}
