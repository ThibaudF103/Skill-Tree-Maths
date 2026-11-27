import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

VergerStore memoryStore() =>
    VergerStore(VergerDatabase(NativeDatabase.memory()));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// Arbre « Mécanique » > « Oscillateurs » > « Forcés », une carte dans
  /// chacun des deux derniers, et la géométrie calculée enregistrée.
  Future<(VergerStore, BoardLayout)> laidOut() async {
    final store = memoryStore();
    final tree = await store.createNode(title: 'Mécanique');
    final branch = await store.createNode(
      title: 'Oscillateurs',
      parentId: tree.id,
    );
    final leaf = await store.createNode(title: 'Forcés', parentId: branch.id);
    await store.createItem(
      nodeId: branch.id,
      kind: ItemKind.definition,
      title: 'Oscillateur harmonique',
    );
    await store.createItem(
      nodeId: leaf.id,
      kind: ItemKind.theorem,
      title: 'Résonance',
    );
    final layout = layoutBoard(await store.allNodes(), await store.allItems());
    await store.saveBoardGeometry(regions: layout.regions, cards: layout.cards);
    return (store, layout);
  }

  test('géométrie enregistrée et relue, en une transaction', () async {
    final (store, layout) = await laidOut();
    final nodes = await store.allNodes();
    final items = await store.allItems();
    for (final n in nodes) {
      expect(n.board, layout.regions[n.id]);
    }
    for (final i in items) {
      expect(i.boardPosition, layout.cards[i.id]);
    }
    // Relue, elle ne demande plus rien.
    expect(layoutBoard(nodes, items).hasChanges, isFalse);

    // Écriture groupée : une seule émission du flux observé.
    final emissions = <List<KnowledgeNode>>[];
    final sub = store.watchNodes().listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await store.saveBoardGeometry(
      regions: {
        for (final n in nodes) n.id: n.board!.translate(10, 0),
        'inconnu': const BoardRect(0, 0, 1, 1),
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(emissions, hasLength(2));
    expect(
      emissions.last.first.board,
      layout.regions[nodes.first.id]!.translate(10, 0),
    );
    await store.close();
  });

  test('nouvelle connaissance et nouveau nœud : sans géométrie', () async {
    final (store, _) = await laidOut();
    final tree = (await store.allNodes()).first;
    final node = await store.createNode(title: 'Ondes', parentId: tree.id);
    final item = await store.createItem(
      nodeId: node.id,
      kind: ItemKind.definition,
      title: 'Équation de d\'Alembert',
    );
    expect((await store.node(node.id))!.board, equals(null));
    expect((await store.item(item.id))!.boardPosition, equals(null));
    await store.close();
  });

  test('changer de nœud efface la géométrie (branche entière pour un '
      'nœud)', () async {
    final (store, _) = await laidOut();
    final [tree, branch, leaf] = await store.allNodes();
    final [harmonic, resonance] = await store.allItems();

    // Réordonner parmi les mêmes frères ne change rien.
    await store.moveNode(leaf.id, newParentId: branch.id, index: 0);
    expect((await store.node(leaf.id))!.board, isNotNull);

    await store.moveNode(leaf.id, newParentId: tree.id);
    expect((await store.node(leaf.id))!.board, equals(null));
    expect((await store.item(resonance.id))!.boardPosition, equals(null));
    expect((await store.node(branch.id))!.board, isNotNull);
    expect((await store.item(harmonic.id))!.boardPosition, isNotNull);

    // Connaissance changée de nœud, par la fiche ou par glisser.
    await store.updateItem(harmonic.id, title: 'Oscillateur');
    expect((await store.item(harmonic.id))!.boardPosition, isNotNull);
    await store.updateItem(harmonic.id, nodeId: tree.id);
    expect((await store.item(harmonic.id))!.boardPosition, equals(null));
    await store.saveBoardGeometry(cards: {harmonic.id: const BoardPoint(1, 2)});
    await store.moveItem(harmonic.id, nodeId: tree.id, index: 0);
    expect(
      (await store.item(harmonic.id))!.boardPosition,
      const BoardPoint(1, 2),
    );
    await store.moveItem(harmonic.id, nodeId: branch.id);
    expect((await store.item(harmonic.id))!.boardPosition, equals(null));
    await store.close();
  });

  test('sauvegarde : géométrie conservée à la restauration', () async {
    final (store, layout) = await laidOut();
    final json = jsonEncode((await store.exportArchive()).toJson());
    final copy = memoryStore();
    await copy.restoreArchive(
      VergerArchive.fromJson((jsonDecode(json) as Map).cast()),
    );
    for (final n in await copy.allNodes()) {
      expect(n.board, layout.regions[n.id]);
    }
    for (final i in await copy.allItems()) {
      expect(i.boardPosition, layout.cards[i.id]);
    }
    await store.close();
    await copy.close();
  });

  test('paquet et modèle : sans géométrie, mis en page à l\'import', () async {
    final (store, _) = await laidOut();
    final tree = (await store.allNodes()).first;
    final pack = await store.exportTree(tree.id);
    expect(pack.nodes.every((n) => n.board == null), isTrue);
    expect(pack.items.every((i) => i.boardPosition == null), isTrue);
    final json = pack.toJson();
    expect(json['version'], 5);

    final other = memoryStore();
    await other.importPack(
      VergerArchive.fromJson((jsonDecode(jsonEncode(json)) as Map).cast()),
    );
    expect((await other.allNodes()).every((n) => n.board == null), isTrue);
    await other.importTemplate(pack);
    expect(
      (await other.allItems()).every((i) => i.boardPosition == null),
      isTrue,
    );
    await store.close();
    await other.close();
  });

  test('vue du tableau retenue dans les réglages', () async {
    final store = memoryStore();
    expect(await store.boardViewport(), equals(null));
    await store.setBoardViewport((scale: 0.5, dx: -120, dy: 40.5));
    expect(await store.boardViewport(), (scale: 0.5, dx: -120.0, dy: 40.5));
    await store.setBoardViewport(null);
    expect(await store.boardViewport(), equals(null));
    await store.close();
  });

  test('instantanés cohérents : une écriture du tableau arrive en une '
      'fois, régions et cartes ensemble', () async {
    final store = memoryStore();
    final tree = await store.createNode(title: 'Mécanique');
    await store.createItem(
      nodeId: tree.id,
      kind: ItemKind.definition,
      title: 'Oscillateur harmonique',
    );
    final snapshots =
        <({List<KnowledgeNode> nodes, List<KnowledgeItem> items})>[];
    final sub = store.watchBoard().listen(snapshots.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final first = snapshots.single;
    final layout = layoutBoard(first.nodes, first.items);
    await store.saveBoardGeometry(regions: layout.regions, cards: layout.cards);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(snapshots, hasLength(2));
    // Jamais de région placée avec une carte encore sans place (la carte
    // serait replacée ailleurs que dans la grille).
    for (final snap in snapshots) {
      final placedRegions = snap.nodes.every((n) => n.board != null);
      final placedCards = snap.items.every((i) => i.boardPosition != null);
      expect(placedRegions, placedCards);
    }
    final last = snapshots.last;
    expect(layoutBoard(last.nodes, last.items).hasChanges, isFalse);
    await store.close();
  });

  test('annuler une suppression : la carte revient sans place, puis est '
      'replacée sans recouvrir celle qui a pris la sienne', () async {
    final (store, _) = await laidOut();
    final branch = (await store.allNodes())[1];
    final harmonic = (await store.allItems()).first;
    final deletion = await store.deleteItem(harmonic.id);
    final other = await store.createItem(
      nodeId: branch.id,
      kind: ItemKind.definition,
      title: 'Pendule simple',
    );
    var layout = layoutBoard(await store.allNodes(), await store.allItems());
    await store.saveBoardGeometry(regions: layout.regions, cards: layout.cards);
    // La nouvelle carte a pris la place libérée.
    expect((await store.item(other.id))!.boardPosition, harmonic.boardPosition);

    await store.undoDeletion(deletion);
    expect((await store.item(harmonic.id))!.boardPosition, equals(null));
    layout = layoutBoard(await store.allNodes(), await store.allItems());
    expect(layout.cards[harmonic.id], isNot(layout.cards[other.id]));
    expect(layout.changedCards, {harmonic.id});
    await store.close();
  });

  group('modifications du tableau', () {
    test('carte changée de région : historique intact, annulation', () async {
      final (store, layout) = await laidOut();
      final [tree, branch, leaf] = await store.allNodes();
      final [harmonic, _] = await store.allItems();
      final scheduler = const SchedulerSettings().build();
      final record = scheduler.record(
        harmonic.scheduling,
        Rating.good,
        DateTime.utc(2026, 11, 3),
        fuzzKey: harmonic.id,
      );
      await store.applyReview(harmonic.id, record);

      final editor = BoardEditor(
        await store.allNodes(),
        await store.allItems(),
      );
      final target = layout.regions[leaf.id]!;
      final drop = BoardPoint(target.x + 30, target.y + 80);
      final edit = editor.moveCard(harmonic.id, topLeft: drop, at: drop);
      expect(edit.itemMove, (itemId: harmonic.id, nodeId: leaf.id));
      final undo = await store.applyBoardEdit(edit);

      final moved = (await store.item(harmonic.id))!;
      expect(moved.nodeId, leaf.id);
      expect(moved.boardPosition, edit.cards[harmonic.id]);
      expect(moved.scheduling, record.after);
      expect(await store.history(harmonic.id), hasLength(1));
      for (final MapEntry(:key, :value) in edit.regions.entries) {
        expect((await store.node(key))!.board, value);
      }

      await store.undoBoardEdit(undo);
      final back = (await store.item(harmonic.id))!;
      expect(back.nodeId, branch.id);
      expect(back.sortIndex, harmonic.sortIndex);
      expect(back.boardPosition, layout.cards[harmonic.id]);
      for (final n in await store.allNodes()) {
        expect(n.board, layout.regions[n.id]);
      }
      expect(tree.id, isNotNull);
      await store.close();
    });

    test('hors de toute région : « Non classées » créée, puis retirée '
        'quand on la vide ; l\'annulation la rétablit', () async {
      final (store, layout) = await laidOut();
      final branch = (await store.allNodes())[1];
      final harmonic = (await store.allItems()).first;
      var editor = BoardEditor(await store.allNodes(), await store.allItems());
      final out = editor.moveCard(
        harmonic.id,
        topLeft: const BoardPoint(-2000, -2000),
        at: const BoardPoint(-1990, -1990),
      );
      final undoOut = await store.applyBoardEdit(out);
      final unsorted = (await store.node(KnowledgeNode.unsortedId))!;
      expect(unsorted.title, 'Non classées');
      expect(unsorted.isTree, isTrue);
      final filed = (await store.item(harmonic.id))!;
      expect(filed.nodeId, KnowledgeNode.unsortedId);
      expect(filed.boardPosition, equals(null));

      // La mise en page la place, puis on la ramène dans une région.
      final placed = layoutBoard(
        await store.allNodes(),
        await store.allItems(),
      );
      await store.saveBoardGeometry(
        regions: placed.regions,
        cards: placed.cards,
      );
      editor = BoardEditor(await store.allNodes(), await store.allItems());
      final target = layout.regions[branch.id]!;
      final drop = BoardPoint(target.x + 30, target.y + 20);
      final back = editor.moveCard(harmonic.id, topLeft: drop, at: drop);
      final undoBack = await store.applyBoardEdit(back);
      expect((await store.item(harmonic.id))!.nodeId, branch.id);
      expect(await store.node(KnowledgeNode.unsortedId), equals(null));

      await store.undoBoardEdit(undoBack);
      expect((await store.item(harmonic.id))!.nodeId, KnowledgeNode.unsortedId);
      expect(await store.node(KnowledgeNode.unsortedId), isNotNull);
      await store.undoBoardEdit(undoOut);
      expect((await store.item(harmonic.id))!.nodeId, branch.id);
      expect(await store.node(KnowledgeNode.unsortedId), equals(null));
      await store.close();
    });

    test('région changée de parent et redimensionnée : annulation', () async {
      final (store, layout) = await laidOut();
      final [tree, branch, leaf] = await store.allNodes();
      final editor = BoardEditor(
        await store.allNodes(),
        await store.allItems(),
      );
      // « Forcés » remonte dans l'arbre, sous « Oscillateurs ».
      final t = layout.regions[tree.id]!;
      final drop = BoardPoint(t.x + 30, t.bottom + 400);
      final edit = editor.moveRegion(leaf.id, topLeft: drop, at: drop);
      expect(edit.nodeMove, (nodeId: leaf.id, parentId: null));
      final undo = await store.applyBoardEdit(edit);
      expect((await store.node(leaf.id))!.parentId, equals(null));

      // Interdit : dans sa propre descendance.
      await expectLater(
        store.applyBoardEdit(
          BoardEdit(nodeMove: (nodeId: tree.id, parentId: branch.id)),
        ),
        throwsArgumentError,
      );

      await store.undoBoardEdit(undo);
      final back = (await store.node(leaf.id))!;
      expect(back.parentId, branch.id);
      expect(back.board, layout.regions[leaf.id]);

      final resize = BoardEditor(
        await store.allNodes(),
        await store.allItems(),
      ).resizeRegion(leaf.id, layout.regions[leaf.id]!.inflate(40));
      final undoResize = await store.applyBoardEdit(resize);
      expect(
        (await store.node(leaf.id))!.board,
        isNot(layout.regions[leaf.id]),
      );
      await store.undoBoardEdit(undoResize);
      for (final n in await store.allNodes()) {
        expect(n.board, layout.regions[n.id]);
      }
      await store.close();
    });
  });
}
