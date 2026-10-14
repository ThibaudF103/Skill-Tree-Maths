import 'growth_stage.dart';

/// Données minimales d'une connaissance pour calculer la progression.
typedef ItemProgress = ({
  String nodeId,
  GrowthStage stage,
  double mastery,
  bool isDue,
});

/// Progression cumulée d'un nœud et de toute sa descendance.
final class NodeProgress {
  int itemCount = 0;
  int dueCount = 0;
  double _masterySum = 0;
  final Map<GrowthStage, int> stageCounts = {
    for (final stage in GrowthStage.values) stage: 0,
  };

  /// Maîtrise moyenne des connaissances (0 si aucune : « arbre en hiver »).
  double get meanMastery => itemCount == 0 ? 0 : _masterySum / itemCount;

  bool get isEmpty => itemCount == 0;

  void _add(ItemProgress item) {
    itemCount++;
    if (item.isDue) dueCount++;
    _masterySum += item.mastery;
    stageCounts[item.stage] = stageCounts[item.stage]! + 1;
  }
}

/// Agrège la progression de chaque nœud en remontant vers la racine : une
/// connaissance compte pour son nœud et pour tous ses ancêtres.
///
/// [parentOf] associe chaque nœud à son parent (`null` pour une racine). Tous
/// les nœuds de [parentOf] figurent dans le résultat, même vides.
Map<String, NodeProgress> aggregateProgress({
  required Map<String, String?> parentOf,
  required Iterable<ItemProgress> items,
}) {
  final result = {for (final id in parentOf.keys) id: NodeProgress()};
  for (final item in items) {
    final visited = <String>{};
    String? nodeId = item.nodeId;
    while (nodeId != null && visited.add(nodeId)) {
      result[nodeId]?._add(item);
      nodeId = parentOf[nodeId];
    }
  }
  return result;
}
