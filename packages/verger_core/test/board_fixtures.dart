// Aides communes aux tests du tableau.

import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

final t = DateTime.utc(2026, 11, 2);
const config = BoardLayoutConfig();

KnowledgeNode node(String id, {String? parent, int index = 0}) => KnowledgeNode(
  id: id,
  parentId: parent,
  title: id,
  sortIndex: index,
  createdAt: t,
);

KnowledgeItem item(String id, String nodeId, {int index = 0}) => KnowledgeItem(
  id: id,
  nodeId: nodeId,
  kind: ItemKind.definition,
  title: id,
  sortIndex: index,
  createdAt: t,
  updatedAt: t,
);

/// Nœuds avec la géométrie calculée (comme relus de la base).
List<KnowledgeNode> placedNodes(
  List<KnowledgeNode> nodes,
  BoardLayout layout,
) => [
  for (final n in nodes)
    KnowledgeNode(
      id: n.id,
      parentId: n.parentId,
      title: n.title,
      sortIndex: n.sortIndex,
      createdAt: n.createdAt,
      board: layout.regions[n.id],
    ),
];

List<KnowledgeItem> placedItems(
  List<KnowledgeItem> items,
  BoardLayout layout,
) => [
  for (final i in items)
    KnowledgeItem(
      id: i.id,
      nodeId: i.nodeId,
      kind: i.kind,
      title: i.title,
      sortIndex: i.sortIndex,
      createdAt: i.createdAt,
      updatedAt: i.updatedAt,
      boardPosition: layout.cards[i.id],
    ),
];

BoardRect card(BoardLayout layout, String id) =>
    BoardRect.at(layout.cards[id]!, config.cardWidth, config.cardHeight);

/// Invariants : tout est placé, chaque région et carte est dans la zone
/// utile de son parent, et rien ne se chevauche entre frères.
void expectConsistent(
  List<KnowledgeNode> nodes,
  List<KnowledgeItem> items,
  BoardLayout layout,
) {
  final depth = <String, int>{};
  int depthOf(KnowledgeNode n) => depth[n.id] ??= n.parentId == null
      ? 0
      : depthOf(nodes.firstWhere((p) => p.id == n.parentId)) + 1;
  BoardRect content(String id) {
    final r = layout.regions[id]!;
    final band = config.titleBand(depthOf(nodes.firstWhere((n) => n.id == id)));
    return BoardRect(
      r.x + config.padding,
      r.y + band,
      r.width - 2 * config.padding,
      r.height - band - config.padding,
    );
  }

  for (final n in nodes) {
    expect(layout.regions, contains(n.id));
  }
  for (final i in items) {
    expect(layout.cards, contains(i.id));
  }
  final parents = {null, ...nodes.map((n) => n.id)};
  for (final p in parents) {
    final boxes = <String, BoardRect>{
      for (final n in nodes.where((n) => n.parentId == p))
        n.id: layout.regions[n.id]!,
      if (p != null)
        for (final i in items.where((i) => i.nodeId == p))
          i.id: card(layout, i.id),
    };
    if (p != null) {
      final area = content(p).inflate(1e-6);
      for (final MapEntry(:key, :value) in boxes.entries) {
        expect(area.contains(value), isTrue, reason: '$key dans $p');
      }
    }
    final entries = boxes.entries.toList();
    for (var a = 0; a < entries.length; a++) {
      for (var b = a + 1; b < entries.length; b++) {
        expect(
          entries[a].value.overlaps(entries[b].value),
          isFalse,
          reason: '${entries[a].key} / ${entries[b].key}',
        );
      }
    }
  }
}

// Deux arbres de trois niveaux, de tailles variées.
