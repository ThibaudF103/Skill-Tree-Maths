import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

const _n = fingerprintSide * fingerprintSide;

Uint8List page(int seed) {
  final random = Random(seed);
  final pixels = Uint8List(_n)..fillRange(0, _n, 250);
  for (var s = 0; s < 60; s++) {
    pixels[random.nextInt(_n)] = 70;
  }
  return pixels;
}

VergerStore newStore() => VergerStore(VergerDatabase(NativeDatabase.memory()));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late VergerStore source;
  late VergerArchive pack;
  late List<Uint8List> pages;

  setUp(() async {
    source = newStore();
    final tree = await source.createNode(title: 'Analyse');
    final branch = await source.createNode(title: 'Suites', parentId: tree.id);
    await source.createNode(title: 'Séries', parentId: tree.id);
    final item = await source.createItem(
      nodeId: branch.id,
      kind: ItemKind.theorem,
      title: 'Cesàro',
    );
    pages = [page(1), page(2), page(3)];
    final poly = await source.importDocument(
      title: 'Poly',
      bytes: Uint8List.fromList([1, 2, 3]),
      contentHash: 'poly-v1',
      fingerprints: pages,
      url: 'https://exemple.fr/poly.pdf',
      nodeIds: [tree.id], // rattaché à l'arbre : hérité par la branche
    );
    await source.addAnchor(
      itemId: item.id,
      documentId: poly.id,
      role: AnchorRole.source,
      page: 3,
      region: const NormalizedRect(0.1, 0.1, 0.9, 0.3),
    );
    await source.createNote(body: 'Preuve', itemId: item.id);
    await source.createNote(body: 'Page 2', documentId: poly.id, page: 2);
    // Révision : ne doit pas voyager.
    await source.applyReview(
      item.id,
      const SchedulerSettings().build().record(
        item.scheduling,
        Rating.good,
        DateTime.utc(2026, 3, 2),
      ),
    );
    pack = await source.exportTree(branch.id);
  });
  tearDown(() => source.close());

  test(
    'export d\'une branche : descendance, contenus hérités, sans progression',
    () {
      expect(pack.title, 'Suites');
      expect(pack.nodes.single.title, 'Suites');
      expect(pack.nodes.single.parentId, isNull);
      expect(pack.items.single.scheduling, SchedulingState.initial);
      expect(pack.reviews, isEmpty);
      expect(pack.documents.single.url, 'https://exemple.fr/poly.pdf');
      expect(pack.resourceLinks.single.nodeId, pack.nodes.single.id);
      expect(pack.anchors.single.page, 3);
      expect(pack.notes.map((n) => n.body), containsAll(['Preuve', 'Page 2']));
    },
  );

  test('import avec le PDF inclus, puis contenu réutilisé', () async {
    final target = newStore();
    addTearDown(target.close);
    final trees = await target.importPack(
      pack,
      files: {
        pack.documents.single.id: (
          bytes: Uint8List.fromList([1, 2, 3]),
          contentHash: 'poly-v1',
          fingerprints: pages,
        ),
      },
    );
    expect(trees.single.title, 'Suites');
    final doc = (await target.allDocuments()).single;
    expect(await target.documentBytes(doc.id), [1, 2, 3]);
    expect(await target.resourceLinks(), [
      (documentId: doc.id, nodeId: trees.single.id),
    ]);
    final item = (await target.allItems()).single;
    expect((await target.anchorsOf(item.id)).single.page, 3);
    expect((await target.notes(itemId: item.id)).single.body, 'Preuve');
    expect((await target.notes(documentId: doc.id)), hasLength(1));

    // Second import : le PDF déjà présent est réutilisé.
    await target.importPack(pack);
    expect(await target.allDocuments(), hasLength(1));
    expect(await target.allItems(), hasLength(2));
  });

  test('import sans le PDF, fichier joint ensuite', () async {
    final target = newStore();
    addTearDown(target.close);
    await target.importPack(pack);
    final doc = (await target.allDocuments()).single;
    expect(await target.documentBytes(doc.id), isNull);
    expect(await target.attachDocumentFile(doc.id, Uint8List(2)), isTrue);
    expect(await target.attachDocumentFile(doc.id, Uint8List(5)), isFalse);
    expect(await target.documentBytes(doc.id), Uint8List(2));
  });

  test('PDF téléchargé d\'une autre version : ancres recalées', () async {
    final target = newStore();
    addTearDown(target.close);
    // Nouvelle version : une page insérée en tête.
    await target.importPack(
      pack,
      files: {
        pack.documents.single.id: (
          bytes: Uint8List.fromList([9]),
          contentHash: 'poly-v2',
          fingerprints: [page(99), ...pages],
        ),
      },
    );
    final doc = (await target.allDocuments()).single;
    expect((doc.contentHash, doc.pageCount), ('poly-v2', 4));
    final item = (await target.allItems()).single;
    expect((await target.anchorsOf(item.id)).single.page, 4);
  });

  test(
    'PDF absent : arbre, ancres et miniatures importés quand même',
    () async {
      final target = newStore();
      addTearDown(target.close);
      await target.importPack(pack);
      final doc = (await target.allDocuments()).single;
      expect(await target.documentBytes(doc.id), isNull);
      expect(doc.url, 'https://exemple.fr/poly.pdf');
    },
  );
}
