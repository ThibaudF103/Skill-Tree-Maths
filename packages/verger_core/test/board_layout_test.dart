import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

void main() {
  final t = DateTime.utc(2026, 11, 2);
  const config = BoardLayoutConfig();

  KnowledgeNode node(String id, {String? parent, int index = 0}) =>
      KnowledgeNode(
        id: id,
        parentId: parent,
        title: id,
        sortIndex: index,
        createdAt: t,
      );

  KnowledgeItem item(String id, String nodeId, {int index = 0}) =>
      KnowledgeItem(
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
      final band = config.titleBand(
        depthOf(nodes.firstWhere((n) => n.id == id)),
      );
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
  final nodes = [
    node('meca'),
    node('optique', index: 1),
    node('newton', parent: 'meca'),
    node('energie', parent: 'meca', index: 1),
    node('oscill', parent: 'meca', index: 2),
    node('libre', parent: 'oscill'),
    node('force', parent: 'oscill', index: 1),
    node('vide', parent: 'optique'),
  ];
  final items = [
    for (var k = 0; k < 7; k++) item('n$k', 'newton', index: k),
    for (var k = 0; k < 2; k++) item('e$k', 'energie', index: k),
    item('o0', 'oscill'),
    for (var k = 0; k < 12; k++) item('l$k', 'libre', index: k),
    item('f0', 'force'),
    for (var k = 0; k < 3; k++) item('p$k', 'optique', index: k),
  ];

  test('tableau vide', () {
    final layout = layoutBoard(const [], const []);
    expect(layout.regions, isEmpty);
    expect(layout.hasChanges, isFalse);
    expect(layout.bounds, equals(null));
  });

  test('première mise en page : régions imbriquées, cartes dedans, aucun '
      'chevauchement', () {
    final layout = layoutBoard(nodes, items);
    expectConsistent(nodes, items, layout);
    expect(layout.changedRegions, hasLength(nodes.length));
    expect(layout.changedCards, hasLength(items.length));
    // Cartes en grille presque carrée : 7 cartes → 3 colonnes.
    final xs = {for (var k = 0; k < 7; k++) layout.cards['n$k']!.x};
    expect(xs, hasLength(3));
    // Les cartes d'une région précèdent ses sous-régions.
    expect(
      card(layout, 'o0').bottom,
      lessThanOrEqualTo(layout.regions['libre']!.y),
    );
    // Les arbres partent de l'origine, côte à côte.
    expect(layout.regions['meca']!.topLeft, const BoardPoint(0, 0));
    expect(layout.bounds!.topLeft, const BoardPoint(0, 0));
  });

  test('déterministe, quel que soit l\'ordre des listes', () {
    final a = layoutBoard(nodes, items);
    final b = layoutBoard(nodes.reversed.toList(), items.reversed.toList());
    expect(b.regions, a.regions);
    expect(b.cards, a.cards);
  });

  test('une géométrie complète est conservée telle quelle', () {
    final first = layoutBoard(nodes, items);
    final again = layoutBoard(
      placedNodes(nodes, first),
      placedItems(items, first),
    );
    expect(again.hasChanges, isFalse);
    expect(again.regions, first.regions);
    expect(again.cards, first.cards);
  });

  test('une nouvelle carte va dans un espace libre de sa région, rien '
      'd\'autre ne bouge', () {
    final first = layoutBoard(nodes, items);
    // « newton » : 7 cartes sur une grille 3 × 3, deux places libres.
    final more = [...placedItems(items, first), item('n7', 'newton', index: 7)];
    final layout = layoutBoard(placedNodes(nodes, first), more);
    expect(layout.changedCards, {'n7'});
    expect(layout.changedRegions, isEmpty);
    expect(layout.regions, first.regions);
    for (final i in items) {
      expect(layout.cards[i.id], first.cards[i.id]);
    }
    // Dans la grille : à droite de la septième carte.
    expect(layout.cards['n7']!.y, first.cards['n6']!.y);
    expect(layout.cards['n7']!.x, greaterThan(first.cards['n6']!.x));
    expectConsistent(nodes, more, layout);
  });

  test('région pleine : elle grandit, ses voisines descendent sans se '
      'chevaucher', () {
    final first = layoutBoard(nodes, items);
    // « energie » : 2 cartes sur 2 colonnes, pleine.
    final more = [
      ...placedItems(items, first),
      for (var k = 2; k < 6; k++) item('e$k', 'energie', index: k),
    ];
    final layout = layoutBoard(placedNodes(nodes, first), more);
    expectConsistent(nodes, more, layout);
    final before = first.regions['energie']!;
    final after = layout.regions['energie']!;
    expect(after.topLeft, before.topLeft);
    expect(after.height, greaterThan(before.height));
    // Les cartes déjà là n'ont pas bougé.
    expect(layout.cards['e0'], first.cards['e0']);
    expect(layout.cards['e1'], first.cards['e1']);
    // « oscill », en dessous, descend avec son contenu ; l'arbre grandit.
    final dy = layout.regions['oscill']!.y - first.regions['oscill']!.y;
    expect(dy, greaterThan(0));
    expect(layout.regions['libre'], first.regions['libre']!.translate(0, dy));
    expect(layout.cards['l0'], first.cards['l0']!.translate(0, dy));
    expect(layout.regions['newton'], first.regions['newton']);
    expect(
      layout.regions['meca']!.height,
      greaterThan(first.regions['meca']!.height),
    );
    // L'autre arbre est intact.
    expect(layout.regions['optique'], first.regions['optique']);
    expect(layout.cards['p0'], first.cards['p0']);
  });

  test('un nouveau nœud se place dans sa région parente, un nouvel arbre à '
      'droite', () {
    final first = layoutBoard(nodes, items);
    final moreNodes = [
      ...placedNodes(nodes, first),
      node('lentilles', parent: 'optique', index: 1),
      node('thermo', index: 2),
    ];
    final moreItems = [
      ...placedItems(items, first),
      item('len0', 'lentilles'),
      item('th0', 'thermo'),
    ];
    final layout = layoutBoard(moreNodes, moreItems);
    expectConsistent(moreNodes, moreItems, layout);
    expect(layout.changedRegions, containsAll(['lentilles', 'thermo']));
    expect(layout.changedCards, containsAll(['len0', 'th0']));
    expect(layout.regions['meca'], first.regions['meca']);
    final rightmost = [
      first.regions['meca']!.right,
      first.regions['optique']!.right,
    ].reduce((a, b) => a > b ? a : b);
    expect(layout.regions['thermo']!.x, rightmost + config.rootGap);
  });

  test('un nœud déplacé (sans géométrie) est refait avec ses cartes', () {
    final first = layoutBoard(nodes, items);
    final moved = [
      for (final n in placedNodes(nodes, first))
        n.id == 'libre' ? node('libre', parent: 'optique', index: 1) : n,
    ];
    final cleared = [
      for (final i in placedItems(items, first))
        i.nodeId == 'libre' ? item(i.id, 'libre', index: i.sortIndex) : i,
    ];
    final layout = layoutBoard(moved, cleared);
    expectConsistent(moved, cleared, layout);
    expect(layout.changedRegions, contains('libre'));
    expect(
      layout.regions['optique']!.contains(layout.regions['libre']!),
      isTrue,
    );
  });

  test('connaissance d\'un nœud inconnu ignorée, parent inconnu traité '
      'comme un arbre', () {
    final layout = layoutBoard(
      [node('a'), node('b', parent: 'fantome')],
      [item('x', 'a'), item('y', 'absent')],
    );
    expect(layout.cards.keys, ['x']);
    expect(layout.regions.keys, containsAll(['a', 'b']));
    expect(layout.regions['a']!.overlaps(layout.regions['b']!), isFalse);
  });

  test('grand tableau : invariants tenus', () {
    // 4 arbres × 4 branches × 3 sous-branches, nombres de cartes variés.
    final big = <KnowledgeNode>[];
    final cards = <KnowledgeItem>[];
    for (var r = 0; r < 4; r++) {
      big.add(node('r$r', index: r));
      for (var s = 0; s < 4; s++) {
        big.add(node('r$r.s$s', parent: 'r$r', index: s));
        for (var u = 0; u < 3; u++) {
          final id = 'r$r.s$s.u$u';
          big.add(node(id, parent: 'r$r.s$s', index: u));
          for (var k = 0; k < (r * 7 + s * 3 + u * 5) % 11; k++) {
            cards.add(item('$id.c$k', id, index: k));
          }
        }
      }
    }
    final layout = layoutBoard(big, cards);
    expectConsistent(big, cards, layout);
    // Plus large que haut (écran en paysage).
    final bounds = layout.bounds!;
    expect(bounds.width, greaterThan(bounds.height * 0.8));
  });
}
