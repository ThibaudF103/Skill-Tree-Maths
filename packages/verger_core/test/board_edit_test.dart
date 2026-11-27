import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

import 'board_fixtures.dart';

void main() {
  final baseNodes = [
    node('meca'),
    node('optique', index: 1),
    node('newton', parent: 'meca'),
    node('energie', parent: 'meca', index: 1),
    node('oscill', parent: 'meca', index: 2),
    node('libre', parent: 'oscill'),
    node('force', parent: 'oscill', index: 1),
    node('vide', parent: 'optique'),
  ];
  final baseItems = [
    for (var k = 0; k < 7; k++) item('n$k', 'newton', index: k),
    for (var k = 0; k < 2; k++) item('e$k', 'energie', index: k),
    for (var k = 0; k < 12; k++) item('l$k', 'libre', index: k),
    item('f0', 'force'),
    for (var k = 0; k < 3; k++) item('p$k', 'optique', index: k),
  ];
  final first = layoutBoard(baseNodes, baseItems);
  final nodes = placedNodes(baseNodes, first);
  final items = placedItems(baseItems, first);
  final editor = BoardEditor(nodes, items);

  /// L'instantané après la modification (comme relu de la base).
  (List<KnowledgeNode>, List<KnowledgeItem>) apply(BoardEdit edit) {
    final ns = [
      for (final n in nodes)
        KnowledgeNode(
          id: n.id,
          parentId: edit.nodeMove?.nodeId == n.id
              ? edit.nodeMove!.parentId
              : n.parentId,
          title: n.title,
          sortIndex: n.sortIndex,
          createdAt: n.createdAt,
          board: edit.regions[n.id] ?? n.board,
        ),
      if (edit.itemMove?.nodeId == KnowledgeNode.unsortedId)
        node(KnowledgeNode.unsortedId, index: 9),
    ];
    final is_ = [
      for (final i in items)
        KnowledgeItem(
          id: i.id,
          nodeId: edit.itemMove?.itemId == i.id
              ? edit.itemMove!.nodeId
              : i.nodeId,
          kind: i.kind,
          title: i.title,
          sortIndex: i.sortIndex,
          createdAt: i.createdAt,
          updatedAt: i.updatedAt,
          boardPosition: edit.clearedCards.contains(i.id)
              ? null
              : edit.cards[i.id] ?? i.boardPosition,
        ),
    ];
    return (ns, is_);
  }

  /// Applique puis vérifie les invariants (après la mise en page
  /// automatique de ce qui serait resté sans place).
  BoardLayout check(BoardEdit edit) {
    final (ns, is_) = apply(edit);
    final layout = layoutBoard(ns, is_);
    expectConsistent(ns, is_, layout);
    return layout;
  }

  BoardPoint center(BoardRect r) =>
      BoardPoint(r.x + r.width / 2, r.y + r.height / 2);

  group('région sous le doigt', () {
    test('la plus profonde', () {
      final libre = first.regions['libre']!;
      expect(editor.regionAt(center(libre)), 'libre');
      final osc = first.regions['oscill']!;
      expect(editor.regionAt(BoardPoint(osc.x + 4, osc.y + 4)), 'oscill');
      expect(editor.regionAt(const BoardPoint(-50, -50)), equals(null));
    });

    test('ni la région déplacée ni sa descendance', () {
      final libre = first.regions['libre']!;
      expect(editor.regionAt(center(libre), excluding: 'oscill'), 'meca');
      expect(editor.regionAt(center(libre), excluding: 'libre'), 'oscill');
    });

    test('« Non classées » n\'accueille pas de région', () {
      final unsorted = [
        ...nodes,
        KnowledgeNode(
          id: KnowledgeNode.unsortedId,
          title: KnowledgeNode.unsortedTitle,
          sortIndex: 5,
          createdAt: t,
          board: const BoardRect(5000, 0, 400, 300),
        ),
      ];
      final e = BoardEditor(unsorted, items);
      const inside = BoardPoint(5100, 100);
      expect(e.regionAt(inside), KnowledgeNode.unsortedId);
      expect(e.regionAt(inside, forRegion: true), equals(null));
    });
  });

  group('déplacer une carte', () {
    test('vers une autre région : elle change de nœud, sans chevauchement', () {
      final target = first.regions['vide']!;
      final drop = BoardPoint(target.x + 40, target.y + 60);
      final edit = editor.moveCard(
        'n0',
        topLeft: BoardPoint(drop.x - 3, drop.y - 5),
        at: drop,
      );
      expect(edit.itemMove, (itemId: 'n0', nodeId: 'vide'));
      final p = edit.cards['n0']!;
      // Aimantée sur la grille.
      expect(p.x % 8, 0);
      expect(p.y % 8, 0);
      final layout = check(edit);
      expect(
        first.regions['vide']!.contains(card(layout, 'n0')) ||
            layout.regions['vide']!.contains(card(layout, 'n0')),
        isTrue,
      );
      // Les autres cartes n'ont pas bougé.
      expect(edit.cards.keys, ['n0']);
    });

    test('sur une carte : poussée vers la place libre la plus proche', () {
      final occupied = first.cards['n4']!;
      final edit = editor.moveCard(
        'n0',
        topLeft: occupied.translate(10, 0),
        at: occupied.translate(30, 30),
      );
      expect(edit.itemMove, equals(null));
      final p = edit.cards['n0']!;
      expect(p, isNot(occupied));
      // La plus proche : au plus une carte plus loin.
      expect(
        (p.x - occupied.x).abs() + (p.y - occupied.y).abs(),
        lessThan(config.cardWidth + 2 * config.gap + 10),
      );
      check(edit);
    });

    test('hors de toute région : vers « Non classées », replacée', () {
      final edit = editor.moveCard(
        'n0',
        topLeft: const BoardPoint(-900, -900),
        at: const BoardPoint(-880, -880),
      );
      expect(edit.itemMove, (itemId: 'n0', nodeId: KnowledgeNode.unsortedId));
      expect(edit.clearedCards, {'n0'});
      final layout = check(edit);
      expect(
        layout.regions[KnowledgeNode.unsortedId]!.contains(card(layout, 'n0')),
        isTrue,
      );
    });

    test('au bord : la région grandit et pousse ses voisines', () {
      final energie = first.regions['energie']!;
      final drop = BoardPoint(energie.x + 30, energie.bottom - 10);
      final edit = editor.moveCard(
        'f0',
        topLeft: BoardPoint(drop.x, drop.y),
        at: drop,
      );
      expect(edit.itemMove, (itemId: 'f0', nodeId: 'energie'));
      expect(edit.regions['energie']!.height, greaterThan(energie.height));
      final layout = check(edit);
      expect(layout.regions['energie']!.topLeft, energie.topLeft);
    });
  });

  group('déplacer une région', () {
    test('elle emporte sous-régions et cartes', () {
      final osc = first.regions['oscill']!;
      final meca = first.regions['meca']!;
      // Dans « meca », un peu plus bas.
      final edit = editor.moveRegion(
        'oscill',
        topLeft: BoardPoint(osc.x, osc.y + 200),
        at: BoardPoint(osc.x + 10, osc.y + 210),
      );
      expect(edit.nodeMove, equals(null));
      final dy = edit.regions['oscill']!.y - osc.y;
      expect(dy, 200);
      expect(edit.regions['libre'], first.regions['libre']!.translate(0, 200));
      expect(edit.cards['l3'], first.cards['l3']!.translate(0, 200));
      expect(edit.regions['meca']!.height, greaterThan(meca.height));
      check(edit);
    });

    test('déposée dans une autre région : changement de parent', () {
      final vide = first.regions['vide']!;
      final drop = BoardPoint(vide.x + 30, vide.y + 70);
      final edit = editor.moveRegion('force', topLeft: drop, at: drop);
      expect(edit.nodeMove, (nodeId: 'force', parentId: 'vide'));
      final layout = check(edit);
      expect(
        layout.regions['vide']!.contains(layout.regions['force']!),
        isTrue,
      );
      expect(layout.regions['force']!.contains(card(layout, 'f0')), isTrue);
    });

    test('jamais dans elle-même ou sa descendance', () {
      final libre = first.regions['libre']!;
      final drop = center(libre);
      final edit = editor.moveRegion(
        'oscill',
        topLeft: BoardPoint(drop.x, drop.y),
        at: drop,
      );
      // La cible devient « meca », son parent actuel : pas de changement.
      expect(edit.nodeMove, equals(null));
      check(edit);
    });

    test('hors de toute région : elle devient un arbre', () {
      final edit = editor.moveRegion(
        'newton',
        topLeft: const BoardPoint(0, 3000),
        at: const BoardPoint(10, 3010),
      );
      expect(edit.nodeMove, (nodeId: 'newton', parentId: null));
      check(edit);
    });

    test('les voisines recouvertes sont poussées, la région reste où on '
        'l\'a posée', () {
      final energie = first.regions['energie']!;
      final newton = first.regions['newton']!;
      final edit = editor.moveRegion(
        'energie',
        topLeft: BoardPoint(newton.x + 100, newton.y + 100),
        at: BoardPoint(newton.x + 110, newton.y - 30),
      );
      expect(edit.regions['energie']!.topLeft, isNot(energie.topLeft));
      expect(
        edit.regions['energie']!.topLeft,
        BoardPoint(newton.x + 104, newton.y + 104),
      );
      expect(edit.regions['newton']!.y, greaterThan(newton.y));
      check(edit);
    });
  });

  group('redimensionner une région', () {
    test('jamais plus petite que son contenu', () {
      final newton = first.regions['newton']!;
      final edit = editor.resizeRegion(
        'newton',
        BoardRect(newton.x, newton.y, 50, 50),
      );
      expect(edit.isEmpty, isTrue);
      final clamped = editor.clampResize(
        'newton',
        BoardRect(newton.x + 300, newton.y + 300, 10, 10),
      );
      expect(clamped, newton);
    });

    test('vide : garde la place d\'une carte', () {
      final vide = first.regions['vide']!;
      final clamped = editor.clampResize(
        'vide',
        BoardRect(vide.x, vide.y, 10, 10),
      );
      expect(clamped.width, config.cardWidth + 2 * config.padding);
      expect(
        clamped.height,
        config.titleBand(1) + config.cardHeight + config.padding,
      );
      expect(clamped.topLeft, vide.topLeft);
      // Bord gauche tiré : c'est lui qui cède.
      final fromLeft = editor.clampResize(
        'vide',
        BoardRect(vide.right - 10, vide.y, 10, vide.height),
      );
      expect(fromLeft.right, vide.right);
    });

    test('reste dans la zone utile de son parent', () {
      final vide = first.regions['vide']!;
      final clamped = editor.clampResize(
        'vide',
        BoardRect(vide.x - 500, vide.y - 500, vide.width + 500, 900),
      );
      final optique = first.regions['optique']!;
      expect(clamped.x, optique.x + config.padding);
      expect(clamped.y, optique.y + config.titleBand(0));
    });

    test('agrandie : pousse ses voisines, son parent grandit', () {
      final energie = first.regions['energie']!;
      final osc = first.regions['oscill']!;
      final meca = first.regions['meca']!;
      final edit = editor.resizeRegion(
        'energie',
        BoardRect(energie.x, energie.y, energie.width, energie.height + 600),
      );
      expect(edit.regions['energie']!.height, energie.height + 600);
      expect(edit.regions['oscill']!.y, greaterThan(osc.y));
      expect(edit.regions['meca']!.height, greaterThan(meca.height));
      // Les cartes de la région agrandie ne bougent pas.
      expect(edit.cards.containsKey('e0'), isFalse);
      check(edit);
    });
  });
}
