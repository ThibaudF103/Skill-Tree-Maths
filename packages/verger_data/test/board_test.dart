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
}
