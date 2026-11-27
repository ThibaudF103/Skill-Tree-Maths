import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

VergerStore memoryStore() =>
    VergerStore(VergerDatabase(NativeDatabase.memory()));

/// Nœud ou connaissance par son titre (l'ordre de création ne départage
/// pas des éléments créés dans la même milliseconde).
Future<KnowledgeNode> nodeNamed(VergerStore store, String title) async =>
    (await store.allNodes()).firstWhere((n) => n.title == title);

Future<KnowledgeItem> itemNamed(VergerStore store, String title) async =>
    (await store.allItems()).firstWhere((i) => i.title == title);

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
    final tree = await nodeNamed(store, 'Mécanique');
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
    final tree = await nodeNamed(store, 'Mécanique');
    final branch = await nodeNamed(store, 'Oscillateurs');
    final leaf = await nodeNamed(store, 'Forcés');
    final harmonic = await itemNamed(store, 'Oscillateur harmonique');
    final resonance = await itemNamed(store, 'Résonance');

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
    final tree = await nodeNamed(store, 'Mécanique');
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
    final snapshots = <BoardSnapshot>[];
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
    final branch = await nodeNamed(store, 'Oscillateurs');
    final harmonic = await itemNamed(store, 'Oscillateur harmonique');
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
      final tree = await nodeNamed(store, 'Mécanique');
      final branch = await nodeNamed(store, 'Oscillateurs');
      final leaf = await nodeNamed(store, 'Forcés');
      final harmonic = await itemNamed(store, 'Oscillateur harmonique');
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
      final branch = await nodeNamed(store, 'Oscillateurs');
      final harmonic = await itemNamed(store, 'Oscillateur harmonique');
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

      // Une annulation plus ancienne n'est plus valable.
      await expectLater(store.undoBoardEdit(undoOut), throwsStateError);
      await store.undoBoardEdit(undoBack);
      expect((await store.item(harmonic.id))!.nodeId, KnowledgeNode.unsortedId);
      expect(await store.node(KnowledgeNode.unsortedId), isNotNull);
      await store.close();
    });

    test('région changée de parent et redimensionnée : annulation', () async {
      final (store, layout) = await laidOut();
      final tree = await nodeNamed(store, 'Mécanique');
      final branch = await nodeNamed(store, 'Oscillateurs');
      final leaf = await nodeNamed(store, 'Forcés');
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

  group('annulation sûre', () {
    test('une annulation ancienne ne crée pas de cycle (refusée, arbre '
        'intact)', () async {
      final (store, _) = await laidOut();
      final branch = await nodeNamed(store, 'Oscillateurs');
      final leaf = await nodeNamed(store, 'Forcés');
      final optique = await store.createNode(title: 'Optique');
      // A (« Forcés ») quitte P (« Oscillateurs ») pour B, puis P va dans A.
      final first = await store.applyBoardEdit(
        BoardEdit(nodeMove: (nodeId: leaf.id, parentId: optique.id)),
      );
      await store.applyBoardEdit(
        BoardEdit(nodeMove: (nodeId: branch.id, parentId: leaf.id)),
      );
      await expectLater(store.undoBoardEdit(first), throwsStateError);
      expect((await store.node(leaf.id))!.parentId, optique.id);
      expect((await store.node(branch.id))!.parentId, leaf.id);
      await store.close();
    });

    test('refusée si ce qu\'elle a touché a changé depuis', () async {
      final (store, layout) = await laidOut();
      final leaf = await nodeNamed(store, 'Forcés');
      final editor = BoardEditor(
        await store.allNodes(),
        await store.allItems(),
      );
      final undo = await store.applyBoardEdit(
        editor.resizeRegion(leaf.id, layout.regions[leaf.id]!.inflate(40)),
      );
      final moved = (await store.node(leaf.id))!.board!.translate(30, 0);
      await store.saveBoardGeometry(regions: {leaf.id: moved});
      await expectLater(store.undoBoardEdit(undo), throwsStateError);
      expect((await store.node(leaf.id))!.board, moved);
      await store.close();
    });

    test('les frères quittés sont renumérotés, et rétablis par '
        'l\'annulation', () async {
      final (store, _) = await laidOut();
      final tree = await nodeNamed(store, 'Mécanique');
      final branch = await nodeNamed(store, 'Oscillateurs');
      await store.createNode(title: 'Ondes', parentId: tree.id);
      await store.createNode(title: 'Fluides', parentId: tree.id);
      Future<List<(String, int)>> order() async => [
        for (final n in await store.allNodes())
          if (n.parentId == tree.id) (n.title, n.sortIndex),
      ];
      expect(await order(), [
        ('Oscillateurs', 0),
        ('Ondes', 1),
        ('Fluides', 2),
      ]);
      final undo = await store.applyBoardEdit(
        BoardEdit(nodeMove: (nodeId: branch.id, parentId: null)),
      );
      expect(await order(), [('Ondes', 0), ('Fluides', 1)]);
      await store.undoBoardEdit(undo);
      expect(await order(), [
        ('Oscillateurs', 0),
        ('Ondes', 1),
        ('Fluides', 2),
      ]);
      await store.close();
    });

    test('carte rangée dans « Non classées » puis annulée tout de suite : '
        'le nœud créé disparaît', () async {
      final (store, _) = await laidOut();
      final harmonic = await itemNamed(store, 'Oscillateur harmonique');
      final undo = await store.applyBoardEdit(
        BoardEdit(
          clearedCards: {harmonic.id},
          itemMove: (itemId: harmonic.id, nodeId: KnowledgeNode.unsortedId),
        ),
      );
      // La mise en page automatique place la carte et la région entre-temps.
      final placed = layoutBoard(
        await store.allNodes(),
        await store.allItems(),
      );
      await store.saveBoardGeometry(
        regions: {
          for (final id in placed.changedRegions) id: placed.regions[id]!,
        },
        cards: {for (final id in placed.changedCards) id: placed.cards[id]!},
      );
      await store.undoBoardEdit(undo);
      expect((await store.item(harmonic.id))!.nodeId, harmonic.nodeId);
      expect(
        (await store.item(harmonic.id))!.boardPosition,
        harmonic.boardPosition,
      );
      expect(await store.node(KnowledgeNode.unsortedId), equals(null));
      await store.close();
    });
  });

  group('paquets et « Non classées »', () {
    test('ne se partage pas, et un paquet qui l\'emporte est refusé', () async {
      final (store, _) = await laidOut();
      final harmonic = await itemNamed(store, 'Oscillateur harmonique');
      await store.applyBoardEdit(
        BoardEdit(
          clearedCards: {harmonic.id},
          itemMove: (itemId: harmonic.id, nodeId: KnowledgeNode.unsortedId),
        ),
      );
      await expectLater(
        store.exportTree(KnowledgeNode.unsortedId),
        throwsArgumentError,
      );
      final forged = VergerArchive(
        nodes: [
          KnowledgeNode(
            id: KnowledgeNode.unsortedId,
            title: 'Non classées',
            sortIndex: 0,
            createdAt: DateTime.utc(2026),
          ),
        ],
        items: const [],
      );
      await expectLater(
        store.previewPack(forged),
        throwsA(isA<ArchiveFormatException>()),
      );
      await expectLater(
        store.importPack(forged),
        throwsA(isA<ArchiveFormatException>()),
      );
      // Les cartes non classées de l'utilisateur sont intactes.
      expect((await store.item(harmonic.id))!.nodeId, KnowledgeNode.unsortedId);
      await store.close();
    });
  });

  group('règles de « Non classées » et écritures concurrentes', () {
    Future<(VergerStore, KnowledgeItem)> withUnsorted() async {
      final (store, _) = await laidOut();
      final harmonic = await itemNamed(store, 'Oscillateur harmonique');
      await store.applyBoardEdit(
        BoardEdit(
          clearedCards: {harmonic.id},
          itemMove: (itemId: harmonic.id, nodeId: KnowledgeNode.unsortedId),
        ),
      );
      return (store, harmonic);
    }

    test('aucun nœud dessous, et il reste un arbre', () async {
      final (store, _) = await withUnsorted();
      const unsorted = KnowledgeNode.unsortedId;
      final branch = await nodeNamed(store, 'Oscillateurs');
      await expectLater(
        store.createNode(title: 'Sous', parentId: unsorted),
        throwsArgumentError,
      );
      await expectLater(
        store.moveNode(branch.id, newParentId: unsorted),
        throwsArgumentError,
      );
      await expectLater(
        store.moveNode(unsorted, newParentId: branch.id),
        throwsArgumentError,
      );
      await expectLater(
        store.applyBoardEdit(
          BoardEdit(nodeMove: (nodeId: branch.id, parentId: unsorted)),
        ),
        throwsArgumentError,
      );
      await expectLater(
        store.applyBoardEdit(
          BoardEdit(nodeMove: (nodeId: unsorted, parentId: branch.id)),
        ),
        throwsArgumentError,
      );
      // Réordonner parmi les arbres reste permis.
      await store.moveNode(unsorted, index: 0);
      expect((await store.node(unsorted))!.isTree, isTrue);
      expect(await store.allNodes(), hasLength(4));
      await store.close();
    });

    test(
      'retiré quand sa dernière carte sort, par n\'importe quel chemin',
      () async {
        for (final way in ['move', 'update', 'delete']) {
          final (store, harmonic) = await withUnsorted();
          final branch = await nodeNamed(store, 'Oscillateurs');
          switch (way) {
            case 'move':
              await store.moveItem(harmonic.id, nodeId: branch.id);
            case 'update':
              await store.updateItem(harmonic.id, nodeId: branch.id);
            case 'delete':
              final deletion = await store.deleteItem(harmonic.id);
              expect(await store.node(KnowledgeNode.unsortedId), equals(null));
              // L'annulation remet la carte, et « Non classées » avec elle.
              await store.undoDeletion(deletion);
              expect(
                (await store.item(harmonic.id))!.nodeId,
                KnowledgeNode.unsortedId,
              );
              expect(await store.node(KnowledgeNode.unsortedId), isNotNull);
              await store.close();
              continue;
          }
          expect(
            await store.node(KnowledgeNode.unsortedId),
            equals(null),
            reason: way,
          );
          await store.close();
        }
      },
    );

    test('un geste sur une ligne supprimée entre-temps est refusé', () async {
      final (store, layout) = await laidOut();
      final leaf = await nodeNamed(store, 'Forcés');
      final editor = BoardEditor(
        await store.allNodes(),
        await store.allItems(),
      );
      final edit = editor.resizeRegion(
        leaf.id,
        layout.regions[leaf.id]!.inflate(40),
      );
      await store.deleteNode(leaf.id, recursive: true);
      await expectLater(store.applyBoardEdit(edit), throwsStateError);
      await store.close();
    });

    test(
      'une mise en page calculée avant un geste n\'écrase pas le geste',
      () async {
        final (store, layout) = await laidOut();
        final leaf = await nodeNamed(store, 'Forcés');
        final before = await store.watchBoard().first;
        final editor = BoardEditor(before.nodes, before.items);
        final edit = editor.resizeRegion(
          leaf.id,
          layout.regions[leaf.id]!.inflate(40),
        );
        final undo = await store.applyBoardEdit(edit);
        expect(undo.generation, greaterThan(before.generation));
        // Sauvegarde automatique tardive, calculée sur l'instantané d'avant.
        final saved = await store.saveBoardGeometry(
          regions: layout.regions,
          ifGeneration: before.generation,
        );
        expect(saved, isFalse);
        expect((await store.node(leaf.id))!.board, edit.regions[leaf.id]);
        final now = await store.watchBoard().first;
        expect(now.generation, undo.generation);
        await store.close();
      },
    );
  });
}
